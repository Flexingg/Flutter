import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:timelines_plus/timelines_plus.dart';
import '../services/health_data_service.dart';

class StepsDetailScreen extends ConsumerStatefulWidget {
  final DateTime date;
  
  const StepsDetailScreen({
    Key? key,
    required this.date,
  }) : super(key: key);

  @override
  ConsumerState<StepsDetailScreen> createState() => _StepsDetailScreenState();
}

class _StepsDetailScreenState extends ConsumerState<StepsDetailScreen> {
  final _numberFormat = NumberFormat('#,###');
  final _timeFormat = DateFormat('h:mm a');
  final _healthService = HealthDataService();
  List<Map<String, dynamic>> _hourlySteps = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchHourlySteps();
  }

  Future<void> _fetchHourlySteps() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Use the provided date instead of current date
      final midnight = DateTime(widget.date.year, widget.date.month, widget.date.day);
      
      // Clear previous data
      _hourlySteps.clear();
      
      // Fetch steps data for each hour
      for (int hour = 0; hour < 24; hour++) {
        final startTime = midnight.add(Duration(hours: hour));
        final endTime = startTime.add(const Duration(hours: 1));
        
        final steps = await _healthService.health.getTotalStepsInInterval(startTime, endTime);
        
        _hourlySteps.add({
          'hour': hour,
          'startTime': startTime,
          'endTime': endTime,
          'steps': steps ?? 0,
        });
      }

      print('Fetched ${_hourlySteps.length} hours of data for ${widget.date}');
      print('First hour data: ${_hourlySteps.first}');
      print('Last hour data: ${_hourlySteps.last}');

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching steps: $e');
      setState(() {
        _isLoading = false;
        _error = 'Failed to load steps data: ${e.toString()}';
      });
    }
  }

  Widget _buildLineChart() {
    if (_hourlySteps.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: true,
            horizontalInterval: 1000,
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
                interval: 3,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() % 3 != 0) return const Text('');
                  return Text(
                    '${value.toInt()}:00',
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
                interval: 1000,
                getTitlesWidget: (value, meta) {
                  return Text(
                    _numberFormat.format(value.toInt()),
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  );
                },
                reservedSize: 42,
              ),
            ),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(color: Colors.grey.withOpacity(0.2)),
          ),
          minX: 0,
          maxX: 23,
          minY: 0,
          maxY: _hourlySteps.map((e) => e['steps'] as int).reduce((a, b) => a > b ? a : b).toDouble() * 1.1,
          lineBarsData: [
            LineChartBarData(
              spots: _hourlySteps.asMap().entries.map((entry) {
                return FlSpot(entry.key.toDouble(), entry.value['steps'].toDouble());
              }).toList(),
              isCurved: true,
              color: Colors.blue,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.blue.withOpacity(0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Steps Detail'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchHourlySteps,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                : _hourlySteps.isEmpty
                    ? const Center(child: Text('No steps data available'))
                    : SingleChildScrollView(
                        child: Column(
                          children: [
                            _buildLineChart(),
                            const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Text(
                                'Hourly Breakdown',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _hourlySteps.length,
                              itemBuilder: (context, index) {
                                final data = _hourlySteps[index];
                                // Skip rendering if steps are 0
                                if (data['steps'] == 0) {
                                  return const SizedBox.shrink();
                                }
                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Time column
                                      SizedBox(
                                        width: 100,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${data['hour']}:00',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.blue,
                                              ),
                                            ),
                                            Text(
                                              '${_timeFormat.format(data['startTime'])} - ${_timeFormat.format(data['endTime'])}',
                                              style: const TextStyle(
                                                color: Colors.grey,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Vertical line
                                      Container(
                                        width: 2,
                                        height: 80,
                                        color: Colors.blue,
                                      ),
                                      const SizedBox(width: 16),
                                      // Steps card
                                      Expanded(
                                        child: Card(
                                          elevation: 2,
                                          child: Padding(
                                            padding: const EdgeInsets.all(16.0),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  '${_numberFormat.format(data['steps'])} steps',
                                                  style: const TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.blue,
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                LinearProgressIndicator(
                                                  value: data['steps'] / 10000, // Assuming 10k steps as max
                                                  backgroundColor: Colors.blue.withOpacity(0.1),
                                                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
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