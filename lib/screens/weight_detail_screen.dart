import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:health/health.dart';
import '../services/health_data_service.dart';
import 'dart:developer' as developer;
import 'settings_screen.dart';

class WeightDetailScreen extends ConsumerStatefulWidget {
  final DateTime date;
  
  const WeightDetailScreen({
    Key? key,
    required this.date,
  }) : super(key: key);

  @override
  ConsumerState<WeightDetailScreen> createState() => _WeightDetailScreenState();
}

class _WeightDetailScreenState extends ConsumerState<WeightDetailScreen> {
  static const String TAG = "WeightDetailScreen";
  final _decimalFormat = NumberFormat('#,###.#');
  final _dateFormat = DateFormat('MM/dd/yyyy');
  final _chartDateFormat = DateFormat('MM/dd');
  final _healthService = HealthDataService();
  List<HealthDataPoint> _weightData = [];
  bool _isLoading = true;
  String? _error;

  // Convert weight based on preferred unit
  double _convertWeight(double value, String fromUnit, String toUnit) {
    if (fromUnit == toUnit) return value;
    if (fromUnit == 'kg' && toUnit == 'lbs') return value * 2.20462;
    if (fromUnit == 'lbs' && toUnit == 'kg') return value / 2.20462;
    return value;
  }

  // Get display weight and unit
  (double, String) _getDisplayWeight(HealthDataPoint data) {
    final preferredUnit = ref.watch(weightUnitProvider);
    final isInPounds = data.unit.toString().toLowerCase().contains('lb') ||
                      data.unit.toString().toLowerCase().contains('pound');
    final originalUnit = isInPounds ? 'lbs' : 'kg';
    
    num value = 0.0;
    if (data.value is NumericHealthValue) {
      value = (data.value as NumericHealthValue).numericValue ?? 0.0;
    }
    
    final convertedValue = _convertWeight(value.toDouble(), originalUnit, preferredUnit);
    return (convertedValue, preferredUnit);
  }

  @override
  void initState() {
    super.initState();
    _fetchWeightData();
  }

  Future<void> _fetchWeightData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // First test the Health Connect connection
      developer.log('Testing Health Connect connection...', name: TAG);
      final (connectionOk, connectionError) = await _healthService.testHealthConnectConnection();
      if (!connectionOk) {
        developer.log('Health Connect connection failed: $connectionError', name: TAG);
        setState(() {
          _isLoading = false;
          _error = connectionError ?? 'Failed to connect to Health Connect';
        });
        return;
      }

      // Use a 30-day range from the selected date
      final endDate = widget.date;
      final startDate = endDate.subtract(const Duration(days: 30));
      
      developer.log('Fetching weight data from ${startDate.toString()} to ${endDate.toString()}', name: TAG);
      
      // Fetch weight data
      final (weightData, error) = await _healthService.fetchWeightData(startDate, endDate);
      
      if (error != null) {
        developer.log('Error fetching weight data: $error', name: TAG);
        setState(() {
          _isLoading = false;
          _error = error;
        });
        return;
      }

      if (weightData == null || weightData.isEmpty) {
        developer.log('No weight data found', name: TAG);
        setState(() {
          _isLoading = false;
          _error = 'No weight data found in Health Connect for the selected date range. Please ensure you have weight data recorded in Health Connect.';
        });
        return;
      }

      // Log the type and content of weightData
      developer.log('Weight data type: ${weightData.runtimeType}', name: TAG);
      developer.log('Weight data content: $weightData', name: TAG);

      // Sort by date
      _weightData = weightData;
      _weightData.sort((a, b) => a.dateFrom.compareTo(b.dateFrom));

      developer.log('Total weight records found: ${_weightData.length}', name: TAG);
      if (_weightData.isNotEmpty) {
        developer.log('First weight data: ${_weightData.first.toJson()}', name: TAG);
        developer.log('Last weight data: ${_weightData.last.toJson()}', name: TAG);
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      developer.log('Error in _fetchWeightData: $e', name: TAG, error: e, stackTrace: stackTrace);
      setState(() {
        _isLoading = false;
        _error = 'Failed to load weight data: ${e.toString()}';
      });
    }
  }

  Widget _buildLineChart() {
    if (_weightData.isEmpty) return const SizedBox.shrink();

    final weights = _weightData.map((e) {
      final (value, _) = _getDisplayWeight(e);
      return value;
    }).toList();

    if (weights.isEmpty) return const SizedBox.shrink();

    final minWeight = weights.reduce((a, b) => a < b ? a : b);
    final maxWeight = weights.reduce((a, b) => a > b ? a : b);
    final weightRange = maxWeight - minWeight;
    
    // Add some padding to the range
    final chartMinY = (minWeight - weightRange * 0.1).floorToDouble();
    final chartMaxY = (maxWeight + weightRange * 0.1).ceilToDouble();

    final preferredUnit = ref.watch(weightUnitProvider);

    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: true,
            horizontalInterval: 1,
            verticalInterval: 1,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: Colors.grey.withOpacity(0.2),
                strokeWidth: 1,
              );
            },
            getDrawingVerticalLine: (value) {
              return FlLine(
                color: Colors.grey.withOpacity(0.2),
                strokeWidth: 1,
              );
            },
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: 5,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() >= _weightData.length) return const Text('');
                  final date = _weightData[value.toInt()].dateFrom;
                  return Text(
                    _chartDateFormat.format(date),
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  return Text(
                    '${_decimalFormat.format(value)} $preferredUnit',
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  );
                },
                reservedSize: 60,
              ),
            ),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(color: Colors.grey.withOpacity(0.2)),
          ),
          minX: 0,
          maxX: (_weightData.length - 1).toDouble(),
          minY: chartMinY,
          maxY: chartMaxY,
          lineBarsData: [
            LineChartBarData(
              spots: _weightData.asMap().entries.map((entry) {
                final (value, _) = _getDisplayWeight(entry.value);
                return FlSpot(entry.key.toDouble(), value);
              }).toList(),
              isCurved: true,
              color: Colors.brown,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.brown.withOpacity(0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeightStats() {
    if (_weightData.isEmpty) return const SizedBox.shrink();

    final weights = _weightData.map((e) {
      final (value, _) = _getDisplayWeight(e);
      return value;
    }).toList();

    if (weights.isEmpty) return const SizedBox.shrink();

    final currentWeight = weights.last;
    final startWeight = weights.first;
    final weightChange = currentWeight - startWeight;
    final averageWeight = weights.reduce((a, b) => a + b) / weights.length;

    final preferredUnit = ref.watch(weightUnitProvider);

    // Format the weight change with proper sign
    final formattedWeightChange = weightChange >= 0 
        ? '+${_decimalFormat.format(weightChange)}'
        : _decimalFormat.format(weightChange);

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Weight Statistics',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatItem(
                  'Current',
                  '${_decimalFormat.format(currentWeight)} $preferredUnit',
                  Colors.brown,
                ),
                _buildStatItem(
                  'Change',
                  '$formattedWeightChange $preferredUnit',
                  weightChange >= 0 ? Colors.red : Colors.green,
                ),
                _buildStatItem(
                  'Average',
                  '${_decimalFormat.format(averageWeight)} $preferredUnit',
                  Colors.blue,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Weight Detail'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchWeightData,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _error!,
                            style: const TextStyle(color: Colors.red),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Please check your Health Connect app to ensure:\n'
                            '1. Weight data is being recorded\n'
                            '2. Flexingg has read permissions\n'
                            '3. The data is within the last 30 days\n\n'
                            'If the issue persists, try:\n'
                            '1. Force stop and restart the app\n'
                            '2. Revoke and re-grant permissions in Health Connect\n'
                            '3. Record a new weight entry in Health Connect',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _fetchWeightData,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
                : _weightData.isEmpty
                    ? const Center(child: Text('No weight data available'))
                    : SingleChildScrollView(
                        child: Column(
                          children: [
                            _buildLineChart(),
                            _buildWeightStats(),
                            const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Text(
                                'Weight History',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _weightData.length,
                              itemBuilder: (context, index) {
                                final data = _weightData[index];
                                final (value, unit) = _getDisplayWeight(data);
                                
                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                                  child: Card(
                                    child: ListTile(
                                      title: Text(
                                        _dateFormat.format(data.dateFrom),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      trailing: Text(
                                        '${_decimalFormat.format(value)} $unit',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.brown,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
      ),
    );
  }
} 