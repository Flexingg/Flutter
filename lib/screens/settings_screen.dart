import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health/health.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:flexingg/services/health_data_service.dart';
import 'package:flexingg/services/auth_service.dart';
import 'package:flexingg/providers/auth_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final Map<HealthDataType, bool> _permissionStatus = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkPermissionStatus();
  }

  Future<void> _checkPermissionStatus() async {
    setState(() {
      _isLoading = true;
    });

    final healthService = HealthDataService();
    final types = [
      HealthDataType.STEPS,
      HealthDataType.HEART_RATE,
      HealthDataType.BODY_TEMPERATURE,
      HealthDataType.BLOOD_OXYGEN,
      HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
      HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
      HealthDataType.BODY_MASS_INDEX,
      HealthDataType.BODY_FAT_PERCENTAGE,
      HealthDataType.HEIGHT,
      HealthDataType.WEIGHT,
      HealthDataType.BASAL_ENERGY_BURNED,
      HealthDataType.ACTIVE_ENERGY_BURNED,
      HealthDataType.FLIGHTS_CLIMBED,
      HealthDataType.DISTANCE_DELTA,
      HealthDataType.EXERCISE_TIME,
      HealthDataType.WORKOUT,
      HealthDataType.HEART_RATE_VARIABILITY_SDNN,
      HealthDataType.RESTING_HEART_RATE,
      HealthDataType.SLEEP_IN_BED,
      HealthDataType.SLEEP_ASLEEP,
      HealthDataType.SLEEP_AWAKE,
      HealthDataType.SLEEP_DEEP,
      HealthDataType.SLEEP_LIGHT,
      HealthDataType.SLEEP_REM,
      HealthDataType.WATER,
      HealthDataType.MINDFULNESS,
      HealthDataType.NUTRITION,
      HealthDataType.BLOOD_GLUCOSE,
    ];

    for (final type in types) {
      final hasPermission = await healthService.hasPermissionForType(type);
      setState(() {
        _permissionStatus[type] = hasPermission;
      });
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _openHealthConnectSettings() async {
    try {
      print('Attempting to open Health Connect settings...');
      
      // Try to open Health Connect settings directly
      final intent = AndroidIntent(
        action: 'androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE',
        package: 'com.google.android.apps.healthdata',
        arguments: <String, dynamic>{
          'packageName': 'gg.flexin.app',
        },
      );
      
      print('Launching Health Connect intent...');
      await intent.launch();
      print('Health Connect intent launched successfully');
      
      // Wait a moment for the settings to open
      await Future.delayed(const Duration(seconds: 1));
      
      // Refresh permission status after returning
      _checkPermissionStatus();
      
    } catch (e) {
      print('Error opening Health Connect settings: $e');
      
      try {
        // Try to open Health Connect app
        print('Attempting to open Health Connect app...');
        final intent = AndroidIntent(
          action: 'android.intent.action.MAIN',
          package: 'com.google.android.apps.healthdata',
        );
        await intent.launch();
        print('Health Connect app launched successfully');
      } catch (e) {
        print('Error opening Health Connect app: $e');
        
        try {
          // Try to open Play Store
          print('Attempting to open Play Store...');
          final url = Uri.parse(
            'market://details?id=com.google.android.apps.healthdata',
          );
          if (await canLaunchUrl(url)) {
            await launchUrl(url);
            print('Play Store launched successfully');
          } else {
            print('Could not launch Play Store URL');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Could not open Health Connect settings'),
                ),
              );
            }
          }
        } catch (e) {
          print('Error opening Play Store: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Could not open Health Connect settings'),
              ),
            );
          }
        }
      }
    }
  }

  String _getHealthDataTypeName(HealthDataType type) {
    switch (type) {
      case HealthDataType.STEPS:
        return 'Steps';
      case HealthDataType.HEART_RATE:
        return 'Heart Rate';
      case HealthDataType.BODY_TEMPERATURE:
        return 'Body Temperature';
      case HealthDataType.BLOOD_OXYGEN:
        return 'Blood Oxygen';
      case HealthDataType.BLOOD_PRESSURE_SYSTOLIC:
        return 'Blood Pressure (Systolic)';
      case HealthDataType.BLOOD_PRESSURE_DIASTOLIC:
        return 'Blood Pressure (Diastolic)';
      case HealthDataType.BODY_MASS_INDEX:
        return 'BMI';
      case HealthDataType.BODY_FAT_PERCENTAGE:
        return 'Body Fat Percentage';
      case HealthDataType.HEIGHT:
        return 'Height';
      case HealthDataType.WEIGHT:
        return 'Weight';
      case HealthDataType.BASAL_ENERGY_BURNED:
        return 'Basal Energy Burned';
      case HealthDataType.ACTIVE_ENERGY_BURNED:
        return 'Active Energy Burned';
      case HealthDataType.FLIGHTS_CLIMBED:
        return 'Flights Climbed';
      case HealthDataType.DISTANCE_DELTA:
        return 'Distance';
      case HealthDataType.EXERCISE_TIME:
        return 'Exercise Time';
      case HealthDataType.WORKOUT:
        return 'Workouts';
      case HealthDataType.HEART_RATE_VARIABILITY_SDNN:
        return 'Heart Rate Variability';
      case HealthDataType.RESTING_HEART_RATE:
        return 'Resting Heart Rate';
      case HealthDataType.SLEEP_IN_BED:
        return 'Sleep (In Bed)';
      case HealthDataType.SLEEP_ASLEEP:
        return 'Sleep (Asleep)';
      case HealthDataType.SLEEP_AWAKE:
        return 'Sleep (Awake)';
      case HealthDataType.SLEEP_DEEP:
        return 'Sleep (Deep)';
      case HealthDataType.SLEEP_LIGHT:
        return 'Sleep (Light)';
      case HealthDataType.SLEEP_REM:
        return 'Sleep (REM)';
      case HealthDataType.WATER:
        return 'Water Intake';
      case HealthDataType.MINDFULNESS:
        return 'Mindfulness';
      case HealthDataType.NUTRITION:
        return 'Nutrition';
      case HealthDataType.BLOOD_GLUCOSE:
        return 'Blood Glucose';
      default:
        return type.toString().split('.').last;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Health Data Permissions',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: _isLoading ? null : _checkPermissionStatus,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Manage which health data types the app can access:',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
                  else
                    Column(
                      children: _permissionStatus.entries.map((entry) {
                        return ListTile(
                          title: Text(_getHealthDataTypeName(entry.key)),
                          trailing: Icon(
                            entry.value ? Icons.check_circle : Icons.cancel,
                            color: entry.value ? Colors.green : Colors.red,
                          ),
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _openHealthConnectSettings,
                      child: const Text('Manage Health Permissions'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Account',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        ref.read(authServiceProvider).signOut(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Logout'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
} 