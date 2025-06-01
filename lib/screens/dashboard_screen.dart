import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:health/health.dart';
import '../providers/health_provider.dart';
import 'settings_screen.dart';
import 'steps_detail_screen.dart';
import 'theme_settings_screen.dart';
import 'nutrition_detail_screen.dart';
import 'exercise_detail_screen.dart';
import 'weight_detail_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final _numberFormat = NumberFormat('#,###');
  final _decimalFormat = NumberFormat('#,###.#');

  @override
  void initState() {
    super.initState();
    // Delay the permission check slightly to ensure the widget is mounted
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkHealthPermissions();
    });
    _setupPeriodicRefresh();
  }

  void _setupPeriodicRefresh() {
    // Check if data needs refresh every minute
    Future.delayed(const Duration(minutes: 1), () {
      if (mounted) {
        final needsRefresh = ref.read(healthDataNeedsRefreshProvider);
        if (needsRefresh) {
          ref.read(healthDataRefreshProvider.notifier).state++;
        }
        _setupPeriodicRefresh();
      }
    });
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Settings',
          textColor: Colors.white,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SettingsScreen()),
            );
          },
        ),
      ),
    );
  }

  Future<void> _checkHealthPermissions() async {
    final hasPermissions = ref.read(healthPermissionsProvider);
    if (!hasPermissions) {
      // Go straight to requesting Health Connect permissions
      await ref.read(healthPermissionsNotifierProvider.notifier).requestPermissions();
    }
  }

  Future<void> _refreshData() async {
    // First check if we have permissions
    final hasPermissions = ref.read(healthPermissionsProvider);
    if (!hasPermissions) {
      await ref.read(healthPermissionsNotifierProvider.notifier).requestPermissions();
    }
    
    // Then refresh the data
    ref.read(healthDataRefreshProvider.notifier).state++;
  }

  Widget _buildHealthCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    String? subtitle,
    VoidCallback? onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(
                  Icons.chevron_right,
                  color: Colors.grey[400],
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Convert weight based on preferred unit
  double _convertWeight(double value, String fromUnit, String toUnit) {
    if (fromUnit == toUnit) return value;
    if (fromUnit == 'kg' && toUnit == 'lbs') return value * 2.20462;
    if (fromUnit == 'lbs' && toUnit == 'kg') return value / 2.20462;
    return value;
  }

  // Get display weight and unit
  (double, String) _getDisplayWeight(dynamic weightData) {
    final preferredUnit = ref.watch(weightUnitProvider);
    
    if (weightData == null) return (0.0, preferredUnit);
    
    if (weightData is List && weightData.isNotEmpty) {
      final data = weightData.first;
      if (data.value is NumericHealthValue) {
        final value = (data.value as NumericHealthValue).numericValue ?? 0.0;
        final isInPounds = data.unit.toString().toLowerCase().contains('lb') ||
                          data.unit.toString().toLowerCase().contains('pound');
        final originalUnit = isInPounds ? 'lbs' : 'kg';
        final convertedValue = _convertWeight(value.toDouble(), originalUnit, preferredUnit);
        return (convertedValue, preferredUnit);
      }
    } else if (weightData is HealthDataPoint && weightData.value is NumericHealthValue) {
      final value = (weightData.value as NumericHealthValue).numericValue ?? 0.0;
      final isInPounds = weightData.unit.toString().toLowerCase().contains('lb') ||
                        weightData.unit.toString().toLowerCase().contains('pound');
      final originalUnit = isInPounds ? 'lbs' : 'kg';
      final convertedValue = _convertWeight(value.toDouble(), originalUnit, preferredUnit);
      return (convertedValue, preferredUnit);
    }
    
    return (0.0, preferredUnit);
  }

  @override
  Widget build(BuildContext context) {
    final healthData = ref.watch(healthDataProvider);
    final selectedDate = ref.watch(selectedDateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
            tooltip: 'Refresh Data',
          ),
          IconButton(
            icon: const Icon(Icons.palette),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ThemeSettingsScreen()),
              );
            },
            tooltip: 'Theme Settings',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
            tooltip: 'Settings',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height - 200,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                // Date selector
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left),
                          onPressed: () {
                            ref.read(selectedDateProvider.notifier).state = 
                              selectedDate.subtract(const Duration(days: 1));
                          },
                        ),
                        TextButton(
                          onPressed: () async {
                            final DateTime? picked = await showDatePicker(
                              context: context,
                              initialDate: selectedDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null) {
                              ref.read(selectedDateProvider.notifier).state = picked;
                            }
                          },
                          child: Text(
                            '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right),
                          onPressed: selectedDate.isBefore(DateTime.now())
                              ? () {
                                  ref.read(selectedDateProvider.notifier).state = 
                                    selectedDate.add(const Duration(days: 1));
                                }
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                healthData.when(
                  data: (data) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Activity Section
                      _buildHealthCard(
                        icon: Icons.directions_walk,
                        title: "Today's Steps",
                        value: _numberFormat.format(data['steps'] ?? 0),
                        color: Colors.blue,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => StepsDetailScreen(
                                date: ref.watch(selectedDateProvider),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildHealthCard(
                        icon: Icons.local_fire_department,
                        title: "Today's Calories Out",
                        value: '${_numberFormat.format(data['activeCaloriesBurned'] ?? 0)} kcal',
                        subtitle: 'Basal: ${_numberFormat.format(data['basalCaloriesBurned'] ?? 0)} kcal',
                        color: Colors.orange,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ExerciseDetailScreen(date: selectedDate),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildHealthCard(
                        icon: Icons.restaurant,
                        title: "Today's Calories In",
                        value: '${_numberFormat.format(data['caloriesConsumed'] ?? 0)} kcal',
                        color: Colors.green,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const NutritionDetailScreen(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildHealthCard(
                        icon: Icons.timer,
                        title: "Exercise Time",
                        value: '${_numberFormat.format(data['exerciseTime'] ?? 0)} min',
                        color: Colors.purple,
                      ),
                      const SizedBox(height: 16),
                      _buildHealthCard(
                        icon: Icons.stairs,
                        title: "Flights Climbed",
                        value: _numberFormat.format(data['flightsClimbed'] ?? 0),
                        color: Colors.indigo,
                      ),
                      const SizedBox(height: 32),

                      // Vital Signs Section
                      const Text(
                        'Vital Signs',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildHealthCard(
                        icon: Icons.favorite,
                        title: "Heart Rate",
                        value: data['heartRate'] != null ? '${_numberFormat.format(data['heartRate'])} bpm' : 'N/A',
                        subtitle: data['restingHeartRate'] != null ? 'Resting: ${_numberFormat.format(data['restingHeartRate'])} bpm' : null,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      _buildHealthCard(
                        icon: Icons.bloodtype,
                        title: "Blood Pressure",
                        value: data['bloodPressureSystolic'] != null && data['bloodPressureDiastolic'] != null
                            ? '${_numberFormat.format(data['bloodPressureSystolic'])}/${_numberFormat.format(data['bloodPressureDiastolic'])}'
                            : 'N/A',
                        color: Colors.pink,
                      ),
                      const SizedBox(height: 16),
                      _buildHealthCard(
                        icon: Icons.air,
                        title: "Blood Oxygen",
                        value: data['bloodOxygen'] != null ? '${_numberFormat.format(data['bloodOxygen'])}%' : 'N/A',
                        color: Colors.cyan,
                      ),
                      const SizedBox(height: 16),
                      _buildHealthCard(
                        icon: Icons.waves,
                        title: "Heart Rate Variability",
                        value: data['heartRateVariability'] != null ? '${_decimalFormat.format(data['heartRateVariability'])} ms' : 'N/A',
                        subtitle: _getHrvStatus(data['heartRateVariability']),
                        color: Colors.deepPurple,
                      ),
                      const SizedBox(height: 32),

                      // Body Composition Section
                      const Text(
                        'Body Composition',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildHealthCard(
                        icon: Icons.monitor_weight,
                        title: "Weight",
                        value: data['weight'] != null 
                            ? (() {
                                final (value, unit) = _getDisplayWeight(data['weight']);
                                return '${_decimalFormat.format(value)} $unit';
                              })()
                            : 'N/A',
                        color: Colors.brown,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => WeightDetailScreen(
                                date: ref.watch(selectedDateProvider),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildHealthCard(
                        icon: Icons.person,
                        title: "BMI",
                        value: data['bmi'] != null ? _decimalFormat.format(data['bmi']) : 'N/A',
                        color: Colors.teal,
                      ),
                      const SizedBox(height: 16),
                      _buildHealthCard(
                        icon: Icons.pie_chart,
                        title: "Body Fat",
                        value: data['bodyFatPercentage'] != null ? '${_decimalFormat.format(data['bodyFatPercentage'])}%' : 'N/A',
                        color: Colors.deepOrange,
                      ),
                      const SizedBox(height: 32),

                      // Sleep Section
                      const Text(
                        'Sleep',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildHealthCard(
                        icon: Icons.bedtime,
                        title: "Sleep Duration",
                        value: data['sleepAsleep'] != null ? '${_decimalFormat.format(data['sleepAsleep'] / 60)} hrs' : 'N/A',
                        subtitle: data['sleepDeep'] != null && data['sleepRem'] != null
                            ? 'Deep: ${_decimalFormat.format(data['sleepDeep'] / 60)}h, REM: ${_decimalFormat.format(data['sleepRem'] / 60)}h'
                            : null,
                        color: Colors.indigo,
                      ),
                      const SizedBox(height: 32),

                      // Hydration Section
                      const Text(
                        'Hydration',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildHealthCard(
                        icon: Icons.water_drop,
                        title: "Water Intake",
                        value: data['waterIntake'] != null ? '${_decimalFormat.format(data['waterIntake'])} ml' : 'N/A',
                        color: Colors.blue,
                      ),
                    ],
                  ),
                  loading: () => const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text(
                          'Loading health data...',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  error: (_, __) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildHealthCard(
                        icon: Icons.directions_walk,
                        title: "Today's Steps",
                        value: '0',
                        color: Colors.blue,
                      ),
                      const SizedBox(height: 16),
                      _buildHealthCard(
                        icon: Icons.local_fire_department,
                        title: "Today's Calories Out",
                        value: '0 kcal',
                        subtitle: 'Basal: 0 kcal',
                        color: Colors.orange,
                      ),
                      const SizedBox(height: 16),
                      _buildHealthCard(
                        icon: Icons.restaurant,
                        title: "Today's Calories In",
                        value: '0 kcal',
                        color: Colors.green,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _getHrvStatus(double? hrv) {
    if (hrv == null) return null;
    
    // HRV ranges based on general guidelines
    if (hrv < 20) return 'Very Low';
    if (hrv < 50) return 'Low';
    if (hrv < 100) return 'Normal';
    if (hrv < 150) return 'High';
    return 'Very High';
  }
} 