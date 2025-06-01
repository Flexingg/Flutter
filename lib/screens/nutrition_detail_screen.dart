import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:health/health.dart';
import '../services/health_data_service.dart';

class NutritionDetailScreen extends ConsumerStatefulWidget {
  const NutritionDetailScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<NutritionDetailScreen> createState() => _NutritionDetailScreenState();
}

class _NutritionDetailScreenState extends ConsumerState<NutritionDetailScreen> {
  final _numberFormat = NumberFormat('#,###');
  final _decimalFormat = NumberFormat('#,###.#');
  final _timeFormat = DateFormat('h:mm a');
  final _healthService = HealthDataService();
  List<Map<String, dynamic>> _nutritionData = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchNutritionData();
  }

  Future<void> _fetchNutritionData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);
      
      // Fetch nutrition data with retry logic
      List<HealthDataPoint> nutritionData = [];
      try {
        nutritionData = await _healthService.health.getHealthDataFromTypes(
          types: [HealthDataType.NUTRITION],
          startTime: midnight,
          endTime: now,
        );
        print('Initial nutrition data points: ${nutritionData.length}');
        
        // If no nutrition data, try with a different time range
        if (nutritionData.isEmpty) {
          print('No nutrition data, trying with adjusted time range...');
          final adjustedStartTime = midnight.subtract(const Duration(hours: 1));
          nutritionData = await _healthService.health.getHealthDataFromTypes(
            types: [HealthDataType.NUTRITION],
            startTime: adjustedStartTime,
            endTime: now,
          );
          print('Nutrition data points after retry: ${nutritionData.length}');
        }
      } catch (e) {
        print('Error fetching nutrition data: $e');
      }

      // Process and categorize nutrition data
      final processedData = <Map<String, dynamic>>[];
      double totalCalories = 0;
      double totalProtein = 0;
      double totalCarbs = 0;
      double totalFat = 0;

      for (var data in nutritionData) {
        final sourceName = data.sourceName.toLowerCase();
        final value = data.value is num ? (data.value as num).toDouble() : 0.0;
        
        print('Processing nutrition data - Source: $sourceName, Value: $value');
        
        // Categorize the nutrition data
        if (sourceName.contains('calories') || sourceName.contains('energy')) {
          totalCalories += value;
          processedData.add({
            'time': data.dateFrom,
            'type': 'Calories',
            'value': value,
            'unit': 'kcal',
            'source': data.sourceName,
          });
          print('Added calories entry: $value kcal');
        } else if (sourceName.contains('protein')) {
          totalProtein += value;
          processedData.add({
            'time': data.dateFrom,
            'type': 'Protein',
            'value': value,
            'unit': 'g',
            'source': data.sourceName,
          });
          print('Added protein entry: $value g');
        } else if (sourceName.contains('carb') || sourceName.contains('carbohydrate')) {
          totalCarbs += value;
          processedData.add({
            'time': data.dateFrom,
            'type': 'Carbs',
            'value': value,
            'unit': 'g',
            'source': data.sourceName,
          });
          print('Added carbs entry: $value g');
        } else if (sourceName.contains('fat')) {
          totalFat += value;
          processedData.add({
            'time': data.dateFrom,
            'type': 'Fat',
            'value': value,
            'unit': 'g',
            'source': data.sourceName,
          });
          print('Added fat entry: $value g');
        }
      }

      print('Total nutrition data - Calories: $totalCalories, Protein: $totalProtein, Carbs: $totalCarbs, Fat: $totalFat');

      // Sort by time
      processedData.sort((a, b) => (a['time'] as DateTime).compareTo(b['time'] as DateTime));

      setState(() {
        _nutritionData = processedData;
        _isLoading = false;
      });
    } catch (e) {
      print('Error in _fetchNutritionData: $e');
      setState(() {
        _isLoading = false;
        _error = 'Failed to load nutrition data: ${e.toString()}';
      });
    }
  }

  Widget _buildMacroSummary() {
    if (_nutritionData.isEmpty) return const SizedBox.shrink();

    double totalCalories = 0;
    double totalProtein = 0;
    double totalCarbs = 0;
    double totalFat = 0;

    for (var data in _nutritionData) {
      final value = data['value'] as double;
      switch (data['type']) {
        case 'Calories':
          totalCalories += value;
          break;
        case 'Protein':
          totalProtein += value;
          break;
        case 'Carbs':
          totalCarbs += value;
          break;
        case 'Fat':
          totalFat += value;
          break;
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Today\'s Nutrition Summary',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMacroItem('Calories', totalCalories, 'kcal', Colors.orange),
                _buildMacroItem('Protein', totalProtein, 'g', Colors.blue),
                _buildMacroItem('Carbs', totalCarbs, 'g', Colors.green),
                _buildMacroItem('Fat', totalFat, 'g', Colors.red),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMacroItem(String label, double value, String unit, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${_numberFormat.format(value)}$unit',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildNutritionList() {
    if (_nutritionData.isEmpty) {
      return const Center(
        child: Text(
          'No nutrition data available for today',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey,
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _nutritionData.length,
      itemBuilder: (context, index) {
        final item = _nutritionData[index];
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _getColorForType(item['type'] as String),
              child: Text(
                item['type'][0],
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              '${item['type']}: ${_numberFormat.format(item['value'])}${item['unit']}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              '${_timeFormat.format(item['time'])} • ${item['source']}',
              style: const TextStyle(
                fontSize: 12,
              ),
            ),
          ),
        );
      },
    );
  }

  Color _getColorForType(String type) {
    switch (type) {
      case 'Calories':
        return Colors.orange;
      case 'Protein':
        return Colors.blue;
      case 'Carbs':
        return Colors.green;
      case 'Fat':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nutrition Details'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchNutritionData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: _isLoading
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text(
                        'Loading nutrition data...',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                )
              : _error != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 48,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _error!,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.red,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildMacroSummary(),
                        const SizedBox(height: 16),
                        const Text(
                          'Today\'s Entries',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildNutritionList(),
                      ],
                    ),
        ),
      ),
    );
  }
} 