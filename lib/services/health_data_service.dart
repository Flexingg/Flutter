import 'package:health/health.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class HealthDataService {
  final Health health = Health();

  // Define all available health data types
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

  // Request authorization for health data access
  Future<(bool, String?)> requestAuthorization() async {
    try {
      print('Requesting health permissions...');
      print('Requesting permissions for types: ${types.map((t) => t.toString()).join(', ')}');
      
      // Request all permissions at once
      final permissions = await health.requestAuthorization(types);
      print('Permission request result: $permissions');
      
      // Consider it a success if we got any permissions
      if (!permissions) {
        print('No permissions were granted');
        return (false, 'No health permissions were granted. Some features may be limited.');
      }

      // Wait a moment for permissions to be fully granted
      await Future.delayed(const Duration(seconds: 2));
      
      // Try to verify we can access at least some data
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);
      
      try {
        // Try to fetch steps
        final steps = await health.getTotalStepsInInterval(midnight, now);
        print('Successfully accessed steps data: $steps');
        
        // Try to fetch heart rate
        final heartRate = await health.getHealthDataFromTypes(
          types: [HealthDataType.HEART_RATE],
          startTime: midnight,
          endTime: now,
        );
        print('Successfully accessed heart rate data: ${heartRate.length} records');
        
        // If we can access either steps or heart rate, consider it a success
        if (steps != null || heartRate.isNotEmpty) {
          return (true, null);
        }
        
        return (false, 'Could not verify health data access. Some features may be limited.');
      } catch (e) {
        print('Failed to verify permissions by accessing data: $e');
        // Even if verification fails, return true since we got some permissions
        return (true, null);
      }
    } catch (e) {
      print('Error in requestAuthorization: $e');
      return (false, 'Error requesting permissions: ${e.toString()}');
    }
  }

  // Check if we have any permissions
  Future<(bool, String?)> hasPermissions() async {
    try {
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);
      
      // Try to fetch steps
      final steps = await health.getTotalStepsInInterval(midnight, now);
      print('hasPermissions check - steps: $steps');
      
      // Try to fetch heart rate
      final heartRate = await health.getHealthDataFromTypes(
        types: [HealthDataType.HEART_RATE],
        startTime: midnight,
        endTime: now,
      );
      print('hasPermissions check - heart rate records: ${heartRate.length}');
      
      // If we can access either steps or heart rate, consider it a success
      if (steps != null || heartRate.isNotEmpty) {
        return (true, null);
      }
      
      return (false, 'No health data access available');
    } catch (e) {
      print('Error in hasPermissions: $e');
      return (false, 'Error checking permissions: ${e.toString()}');
    }
  }

  // Check if we have permission for a specific health data type
  Future<bool> hasPermissionForType(HealthDataType type) async {
    try {
      // First try to get authorization status directly
      final authorized = await health.hasPermissions([type]);
      if (authorized == true) {
        print('Direct permission check for $type: Granted');
        return true;
      }

      // If direct check fails, try to fetch a small amount of data
      final now = DateTime.now();
      final startTime = now.subtract(const Duration(minutes: 1));
      
      // Try to fetch data for the specific type
      final data = await health.getHealthDataFromTypes(
        types: [type],
        startTime: startTime,
        endTime: now,
      );
      
      // If we can access the data, we have permission
      final hasAccess = data.isNotEmpty;
      print('Data fetch check for $type: ${hasAccess ? 'Granted' : 'Denied'}');
      return hasAccess;
    } catch (e) {
      print('Error checking permission for $type: $e');
      // If we get a permission error, we definitely don't have access
      if (e.toString().contains('permission')) {
        return false;
      }
      // For other errors, we'll assume we have permission
      // This is because some data types might not have data available
      // but we still have permission to access them
      return true;
    }
  }

  // Fetch today's health data
  Future<(Map<String, dynamic>?, String?)> fetchTodayHealthData() async {
    try {
      // Get the current date
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);

      print('Fetching health data from $midnight to $now');

      // Initialize with default values
      Map<String, dynamic> data = {
        'steps': 0,
        'caloriesBurned': 0.0,
        'caloriesConsumed': 0.0,
      };

      try {
        // Try to fetch steps
        final steps = await health.getTotalStepsInInterval(midnight, now);
        print('Fetched steps: $steps');
        if (steps != null) {
          data['steps'] = steps;
        }
      } catch (e) {
        print('Error fetching steps: $e');
      }
      
      try {
        // Try to fetch calories burned
        final caloriesBurned = await health.getHealthDataFromTypes(
          types: [HealthDataType.ACTIVE_ENERGY_BURNED],
          startTime: midnight,
          endTime: now,
        );
        print('Fetched calories burned: ${caloriesBurned.length} records');

        // Calculate total calories burned
        double totalCaloriesBurned = 0;
        for (var data in caloriesBurned) {
          if (data.value is num) {
            totalCaloriesBurned += (data.value as num).toDouble();
          }
        }
        print('Total calories burned: $totalCaloriesBurned');
        data['caloriesBurned'] = totalCaloriesBurned;
      } catch (e) {
        print('Error fetching calories burned: $e');
      }

      try {
        // Try to fetch nutrition data (calories consumed)
        final nutritionData = await health.getHealthDataFromTypes(
          types: [HealthDataType.NUTRITION],
          startTime: midnight,
          endTime: now,
        );
        print('Fetched nutrition data: ${nutritionData.length} records');

        // Calculate total calories consumed
        double totalCaloriesConsumed = 0;
        for (var data in nutritionData) {
          if (data.value is num && data.sourceName.contains('calories')) {
            totalCaloriesConsumed += (data.value as num).toDouble();
          }
        }
        print('Total calories consumed: $totalCaloriesConsumed');
        data['caloriesConsumed'] = totalCaloriesConsumed;
      } catch (e) {
        print('Error fetching calories consumed: $e');
      }

      return (data, null);
    } catch (e) {
      print('Error in fetchTodayHealthData: $e');
      return (null, 'Error fetching health data: ${e.toString()}');
    }
  }
} 