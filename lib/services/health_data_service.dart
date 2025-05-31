import 'package:health/health.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class HealthDataService {
  final Health health = Health();

  // Request authorization for health data access
  Future<bool> requestAuthorization(BuildContext context) async {
    try {
      // Request activity recognition permission first
      final activityStatus = await Permission.activityRecognition.request();
      if (!activityStatus.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Activity recognition permission is required")),
        );
        return false;
      }

      // Define the types of health data we want to access
      final types = [
        HealthDataType.STEPS,
        HealthDataType.ACTIVE_ENERGY_BURNED,
        HealthDataType.BASAL_ENERGY_BURNED,
        HealthDataType.NUTRITION,
      ];

      // Request authorization with read/write permissions
      final permissions = List.generate(
        types.length,
        (index) => HealthDataAccess.READ_WRITE,
      );

      final authorized = await health.requestAuthorization(types, permissions: permissions);
      
      if (!authorized) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Health Connect permissions denied")),
        );
      }
      
      return authorized;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error requesting health permissions: $e")),
      );
      return false;
    }
  }

  // Fetch today's health data
  Future<Map<String, double>> fetchTodayHealthData(BuildContext context) async {
    try {
      // Get today's date range
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);
      final tomorrow = midnight.add(const Duration(days: 1));

      // Fetch steps
      final steps = await health.getTotalStepsInInterval(midnight, tomorrow);
      
      // Fetch active calories burned
      final caloriesBurned = await health.getHealthDataFromTypes(
        types: [HealthDataType.ACTIVE_ENERGY_BURNED],
        startTime: midnight,
        endTime: tomorrow,
      );
      
      // Fetch nutrition data (calories consumed)
      final nutritionData = await health.getHealthDataFromTypes(
        types: [HealthDataType.NUTRITION],
        startTime: midnight,
        endTime: tomorrow,
      );

      // Calculate total calories burned
      double totalCaloriesBurned = 0;
      for (var data in caloriesBurned) {
        if (data.value is num) {
          totalCaloriesBurned += (data.value as num).toDouble();
        }
      }

      // Calculate total calories consumed
      double totalCaloriesConsumed = 0;
      for (var data in nutritionData) {
        if (data.value is num) {
          totalCaloriesConsumed += (data.value as num).toDouble();
        }
      }

      return {
        'steps': (steps ?? 0).toDouble(),
        'caloriesBurned': totalCaloriesBurned,
        'caloriesConsumed': totalCaloriesConsumed,
      };
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error fetching health data: $e")),
      );
      return {
        'steps': 0,
        'caloriesBurned': 0,
        'caloriesConsumed': 0,
      };
    }
  }
} 