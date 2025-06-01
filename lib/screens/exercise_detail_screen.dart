import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:health/health.dart';
import '../services/health_data_service.dart';

class ExerciseDetailScreen extends ConsumerStatefulWidget {
  final DateTime date;
  const ExerciseDetailScreen({Key? key, required this.date}) : super(key: key);

  @override
  ConsumerState<ExerciseDetailScreen> createState() => _ExerciseDetailScreenState();
}

class _ExerciseDetailScreenState extends ConsumerState<ExerciseDetailScreen> {
  final _numberFormat = NumberFormat('#,###');
  final _decimalFormat = NumberFormat('#,###.#');
  final _timeFormat = DateFormat('h:mm a');
  final _healthService = HealthDataService();
  List<Map<String, dynamic>> _workoutData = [];
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _additionalMetrics;

  @override
  void initState() {
    super.initState();
    _fetchWorkoutData();
  }

  Future<void> _fetchWorkoutData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Use the provided date instead of current date
      final startTime = DateTime(widget.date.year, widget.date.month, widget.date.day);
      final endTime = startTime.add(const Duration(days: 1));
      
      print('Fetching workout data from $startTime to $endTime');
      
      // Fetch workout data with wider time range
      final workoutData = await _healthService.health.getHealthDataFromTypes(
        types: [HealthDataType.WORKOUT],
        startTime: startTime.subtract(const Duration(hours: 1)),
        endTime: endTime.add(const Duration(hours: 1)),
      );
      print('Found ${workoutData.length} workout records');

      // Fetch energy data using our improved method
      final (activeEnergy, basalEnergy, energyError) = await _healthService.fetchEnergyData(startTime, endTime);
      if (energyError != null) {
        print('Error fetching energy data: $energyError');
      }

      // Process workout data
      final processedData = <Map<String, dynamic>>[];
      double totalActiveCalories = 0;
      double totalBasalCalories = 0;

      // Add active energy data point if available
      if (activeEnergy != null && activeEnergy > 0) {
        processedData.add({
          'time': startTime,
          'type': 'Active',
          'value': activeEnergy,
          'unit': 'kcal',
          'source': 'Health Connect',
        });
        totalActiveCalories = activeEnergy;
      }

      // Add basal energy data point if available
      if (basalEnergy != null && basalEnergy > 0) {
        processedData.add({
          'time': startTime,
          'type': 'Basal',
          'value': basalEnergy,
          'unit': 'kcal',
          'source': 'Health Connect',
        });
        totalBasalCalories = basalEnergy;
      }

      // Process workouts
      for (var data in workoutData) {
        final value = data.value is num ? (data.value as num).toDouble() : 0.0;
        totalActiveCalories += value;
        
        processedData.add({
          'time': data.dateFrom,
          'type': 'Workout',
          'value': value,
          'unit': 'kcal',
          'source': data.sourceName,
        });
      }

      // Sort by time
      processedData.sort((a, b) => (a['time'] as DateTime).compareTo(b['time'] as DateTime));

      // Fetch additional metrics for the specific date
      final (additionalMetrics, error) = await _healthService.fetchHealthData(widget.date);
      if (error != null) {
        print('Error fetching additional metrics: $error');
      }

      setState(() {
        _workoutData = processedData;
        _additionalMetrics = additionalMetrics;
        _isLoading = false;
      });
    } catch (e) {
      print('Error in _fetchWorkoutData: $e');
      setState(() {
        _isLoading = false;
        _error = 'Failed to load workout data: ${e.toString()}';
      });
    }
  }

  Widget _buildCalorieSummary() {
    if (_workoutData.isEmpty) return const SizedBox.shrink();

    double totalActiveCalories = 0;
    double totalBasalCalories = 0;

    for (var data in _workoutData) {
      final value = data['value'] as double;
      if (data['type'] == 'Workout') {
        totalActiveCalories += value;
      } else if (data['type'] == 'Basal') {
        totalBasalCalories += value;
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Today\'s Calories Burned',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildCalorieItem('Active', totalActiveCalories, 'kcal', Colors.orange),
                _buildCalorieItem('Basal', totalBasalCalories, 'kcal', Colors.blue),
                _buildCalorieItem('Total', totalActiveCalories + totalBasalCalories, 'kcal', Colors.green),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdditionalMetrics() {
    if (_additionalMetrics == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Additional Metrics',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMetricItem(
                  'Steps',
                  _additionalMetrics!['steps']?.toString() ?? '0',
                  'steps',
                  Colors.purple,
                ),
                _buildMetricItem(
                  'Flights',
                  _additionalMetrics!['flightsClimbed']?.toString() ?? '0',
                  'floors',
                  Colors.teal,
                ),
                if (_additionalMetrics!['bloodOxygen'] != null)
                  _buildMetricItem(
                    'O₂',
                    '${_additionalMetrics!['bloodOxygen']}%',
                    'SpO₂',
                    Colors.red,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricItem(String label, String value, String unit, Color color) {
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
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          unit,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildCalorieItem(String label, double value, String unit, Color color) {
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

  Widget _buildWorkoutList() {
    if (_workoutData.isEmpty) {
      return const Center(
        child: Text(
          'No workout data available for today',
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
      itemCount: _workoutData.length,
      itemBuilder: (context, index) {
        final item = _workoutData[index];
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

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    return '$hours:$minutes';
  }

  Color _getColorForType(String type) {
    switch (type) {
      case 'Workout':
        return Colors.orange;
      case 'Basal':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Exercise Details'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchWorkoutData,
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
                        'Loading workout data...',
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
                        _buildCalorieSummary(),
                        const SizedBox(height: 16),
                        _buildAdditionalMetrics(),
                        const SizedBox(height: 16),
                        const Text(
                          'Today\'s Activities',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildWorkoutList(),
                      ],
                    ),
        ),
      ),
    );
  }
} 