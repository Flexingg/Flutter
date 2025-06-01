import 'package:health/health.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:developer' as developer;

class HealthDataService {
  final Health health = Health();
  static const String TAG = "HealthDataService";

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

  // Define weight-specific types
  static final List<HealthDataType> weightTypes = [
    HealthDataType.WEIGHT,
    HealthDataType.BODY_MASS_INDEX,
    HealthDataType.BODY_FAT_PERCENTAGE,
  ];

  // Request authorization for health data access
  Future<(bool, String?)> requestAuthorization() async {
    try {
      developer.log('Requesting health permissions...', name: TAG);
      
      // Request permissions for all types at once
      final permissions = await health.requestAuthorization(types);
      developer.log('Permissions request result: $permissions', name: TAG);
      
      // Wait a moment for permissions to be fully granted
      await Future.delayed(const Duration(seconds: 2));
      
      // Try to verify we can access each type of data
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);
      
      // Track which permissions we successfully verified
      Map<String, bool> verifiedPermissions = {};
      
      // Try to verify each type of data
      for (var type in types) {
        try {
          final data = await health.getHealthDataFromTypes(
            types: [type],
            startTime: midnight,
            endTime: now,
          );
          verifiedPermissions[type.toString()] = true;
          developer.log('Successfully verified permission for $type', name: TAG);
        } catch (e) {
          developer.log('Failed to verify permission for $type: $e', name: TAG, error: e);
          verifiedPermissions[type.toString()] = false;
        }
      }
      
      // Log which permissions we successfully verified
      developer.log('Verified permissions: $verifiedPermissions', name: TAG);
      
      // Return true if we got any permissions, even if some failed
      if (verifiedPermissions.values.any((v) => v)) {
        return (true, null);
      }
      
      return (false, 'Could not verify any health data access. Please check Health Connect settings.');
    } catch (e) {
      developer.log('Error in requestAuthorization: $e', name: TAG, error: e);
      return (false, 'Error requesting permissions. Please check Health Connect settings.');
    }
  }

  // Request authorization for weight data
  Future<(bool, String?)> requestWeightAuthorization() async {
    try {
      developer.log('Requesting weight data permissions...', name: TAG);
      
      // Request permissions for weight data
      final authorized = await health.requestAuthorization(weightTypes);
      developer.log('Weight permissions request result: $authorized', name: TAG);
      
      if (!authorized) {
        developer.log('Weight permissions not granted', name: TAG);
        return (false, 'Weight permissions not granted');
      }

      // Request access to read historic data
      await health.requestHealthDataHistoryAuthorization();
      
      // Request access in background
      await health.requestHealthDataInBackgroundAuthorization();
      
      developer.log('Weight permissions granted successfully', name: TAG);
      return (true, null);
    } catch (e) {
      developer.log('Error requesting weight permissions: $e', name: TAG, error: e);
      return (false, 'Error requesting weight permissions: ${e.toString()}');
    }
  }

  // Fetch energy data with specific handling for Android 14
  Future<(double?, double?, String?)> fetchEnergyData(DateTime startTime, DateTime endTime) async {
    try {
      developer.log('Fetching energy data from $startTime to $endTime', name: TAG);
      
      // First check if we have the required permissions
      final hasActiveEnergy = await hasPermissionForType(HealthDataType.ACTIVE_ENERGY_BURNED);
      final hasBasalEnergy = await hasPermissionForType(HealthDataType.BASAL_ENERGY_BURNED);
      
      if (!hasActiveEnergy && !hasBasalEnergy) {
        return (null, null, 'Missing required permissions for energy data');
      }
      
      // Fetch active energy burned
      List<HealthDataPoint> activeEnergyData = [];
      try {
        final adjustedStartTime = startTime.subtract(const Duration(hours: 1));
        final adjustedEndTime = endTime.add(const Duration(hours: 1));
        
        activeEnergyData = await health.getHealthDataFromTypes(
          types: [HealthDataType.ACTIVE_ENERGY_BURNED],
          startTime: adjustedStartTime,
          endTime: adjustedEndTime,
        );
        
        // If no active energy data, try to get it from workouts
        if (activeEnergyData.isEmpty) {
          final workoutData = await health.getHealthDataFromTypes(
            types: [HealthDataType.WORKOUT],
            startTime: adjustedStartTime,
            endTime: adjustedEndTime,
          );
          
          for (var workout in workoutData) {
            if (workout.value is num) {
              activeEnergyData.add(workout);
            }
          }
        }
      } catch (e) {
        developer.log('Error fetching active energy: $e', name: TAG, error: e);
      }
      
      // Fetch basal energy burned using BasalMetabolicRateRecord approach
      List<HealthDataPoint> basalEnergyData = [];
      try {
        // First try to get the most recent BMR record
        final bmrData = await health.getHealthDataFromTypes(
          types: [HealthDataType.BASAL_ENERGY_BURNED],
          startTime: startTime.subtract(const Duration(days: 7)), // Look back 7 days for BMR
          endTime: endTime,
        );
        
        if (bmrData.isNotEmpty) {
          // Sort by date to get the most recent BMR
          bmrData.sort((a, b) => b.dateFrom.compareTo(a.dateFrom));
          final latestBMR = bmrData.first;
          
          if (latestBMR.value is num) {
            // BMR is in kcal/day, convert to kcal for the time period
            final bmrPerDay = (latestBMR.value as num).toDouble();
            final hoursInPeriod = endTime.difference(startTime).inHours;
            final basalEnergy = (bmrPerDay / 24) * hoursInPeriod;
            
            // Use the existing BMR data point but update its value
            basalEnergyData.add(latestBMR);
          }
        }
      } catch (e) {
        developer.log('Error fetching basal energy: $e', name: TAG, error: e);
      }
      
      // Calculate total active energy burned
      double? activeEnergy = 0;
      if (activeEnergyData.isNotEmpty) {
        activeEnergy = activeEnergyData.fold(0.0, (sum, data) {
          if (data.value is num) {
            return sum + (data.value as num).toDouble();
          }
          return sum;
        });
      }
      
      // Calculate total basal energy burned
      double? basalEnergy = 0;
      if (basalEnergyData.isNotEmpty) {
        // Get the most recent BMR record
        final latestBMR = basalEnergyData.first;
        if (latestBMR.value is num) {
          // BMR is in kcal/day, convert to kcal for the time period
          final bmrPerDay = (latestBMR.value as num).toDouble();
          final hoursInPeriod = endTime.difference(startTime).inHours;
          basalEnergy = (bmrPerDay / 24) * hoursInPeriod;
          developer.log('Calculated basal energy: $basalEnergy kcal (BMR: $bmrPerDay kcal/day, Period: $hoursInPeriod hours)', name: TAG);
        }
      }
      
      // If no basal energy data is available, try to estimate it
      if (basalEnergy == 0 || basalEnergyData.isEmpty) {
        try {
          final weightData = await health.getHealthDataFromTypes(
            types: [HealthDataType.WEIGHT],
            startTime: startTime.subtract(const Duration(days: 7)),
            endTime: endTime,
          );
          
          final heightData = await health.getHealthDataFromTypes(
            types: [HealthDataType.HEIGHT],
            startTime: startTime.subtract(const Duration(days: 7)),
            endTime: endTime,
          );
          
          if (weightData.isNotEmpty && heightData.isNotEmpty) {
            weightData.sort((a, b) => b.dateFrom.compareTo(a.dateFrom));
            heightData.sort((a, b) => b.dateFrom.compareTo(a.dateFrom));
            
            final weight = (weightData.first.value as num).toDouble();
            final height = (heightData.first.value as num).toDouble();
            
            const age = 30;
            // Using Mifflin-St Jeor Equation for BMR estimation
            final estimatedBMR = (10 * weight) + (6.25 * height) - (5 * age) + 5;
            final hoursInPeriod = endTime.difference(startTime).inHours;
            basalEnergy = (estimatedBMR / 24) * hoursInPeriod;
          }
        } catch (e) {
          developer.log('Failed to estimate basal energy: $e', name: TAG, error: e);
        }
      }
      
      return (activeEnergy, basalEnergy, null);
    } catch (e) {
      developer.log('Error fetching energy data: $e', name: TAG, error: e);
      return (null, null, 'Error fetching energy data: ${e.toString()}');
    }
  }

  // Check if we have any permissions
  Future<(bool, String?)> hasPermissions() async {
    try {
      // First try direct permission check
      final authorized = await health.hasPermissions([
        HealthDataType.STEPS,
        HealthDataType.HEART_RATE,
        HealthDataType.ACTIVE_ENERGY_BURNED,
      ]);
      
      if (authorized == true) {
        developer.log('Permission check successful - direct verification', name: TAG);
        return (true, null);
      }

      // If direct check fails, try to fetch some data
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);
      
      // Try to fetch steps
      try {
      final steps = await health.getTotalStepsInInterval(midnight, now);
        if (steps != null) {
          developer.log('Permission check successful - found steps data', name: TAG);
          return (true, null);
        }
      } catch (e) {
        developer.log('Error checking steps permission: $e', name: TAG, error: e);
      }
      
      // Try to fetch heart rate
      try {
      final heartRate = await health.getHealthDataFromTypes(
        types: [HealthDataType.HEART_RATE],
        startTime: midnight,
        endTime: now,
      );
        if (heartRate.isNotEmpty) {
          developer.log('Permission check successful - found heart rate data', name: TAG);
          return (true, null);
        }
      } catch (e) {
        developer.log('Error checking heart rate permission: $e', name: TAG, error: e);
      }
      
      // Try to fetch active energy
      try {
        final activeEnergy = await health.getHealthDataFromTypes(
          types: [HealthDataType.ACTIVE_ENERGY_BURNED],
          startTime: midnight,
          endTime: now,
        );
        if (activeEnergy.isNotEmpty) {
          developer.log('Permission check successful - found active energy data', name: TAG);
        return (true, null);
        }
      } catch (e) {
        developer.log('Error checking active energy permission: $e', name: TAG, error: e);
      }
      
      // If we get here, we couldn't verify any permissions
      developer.log('Permission check failed - no data access verified', name: TAG);
      return (false, 'No health data access available');
    } catch (e) {
      developer.log('Error in hasPermissions: $e', name: TAG, error: e);
      // If we get an error, assume we have permissions
      // This is because some data types might not have data available
      // but we still have permission to access them
      return (true, null);
    }
  }

  // Check if we have permission for a specific health data type
  Future<bool> hasPermissionForType(HealthDataType type) async {
    try {
      // First try to get authorization status directly
      final authorized = await health.hasPermissions([type]);
      if (authorized == true) {
        developer.log('Direct permission check for $type: Granted', name: TAG);
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
      developer.log('Data fetch check for $type: ${hasAccess ? 'Granted' : 'Denied'}', name: TAG);
      return hasAccess;
    } catch (e) {
      developer.log('Error checking permission for $type: $e', name: TAG, error: e);
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

  // Fetch blood oxygen data with Health Connect support
  Future<(double?, String?)> fetchBloodOxygen(DateTime startTime, DateTime endTime) async {
    try {
      developer.log('Fetching blood oxygen data from $startTime to $endTime', name: TAG);
      
      // Check if we have permission for blood oxygen
      final hasPermission = await hasPermissionForType(HealthDataType.BLOOD_OXYGEN);
      if (!hasPermission) {
        developer.log('Missing permission for blood oxygen data', name: TAG);
        return (null, 'Missing permission for blood oxygen data');
      }
      
      // Fetch blood oxygen data with retry logic
      List<HealthDataPoint> bloodOxygenData = [];
      try {
        bloodOxygenData = await health.getHealthDataFromTypes(
          types: [HealthDataType.BLOOD_OXYGEN],
          startTime: startTime,
          endTime: endTime,
        );
      } catch (e) {
        developer.log('First attempt to fetch blood oxygen failed: $e', name: TAG, error: e);
        // Try again with a different time range
        try {
          final adjustedStartTime = startTime.subtract(const Duration(hours: 1));
          bloodOxygenData = await health.getHealthDataFromTypes(
            types: [HealthDataType.BLOOD_OXYGEN],
            startTime: adjustedStartTime,
            endTime: endTime,
          );
        } catch (e) {
          developer.log('Second attempt to fetch blood oxygen failed: $e', name: TAG, error: e);
          return (null, 'Failed to fetch blood oxygen data: ${e.toString()}');
        }
      }
      
      developer.log('Blood oxygen records: ${bloodOxygenData.length}', name: TAG);
      
      // Log detailed information about the data
      for (var data in bloodOxygenData) {
        developer.log('Blood Oxygen - Source: ${data.sourceName}, Value: ${data.value}, Unit: ${data.unit}, Type: ${data.type}', name: TAG);
      }
      
      // Calculate average blood oxygen level
      double? averageBloodOxygen;
      if (bloodOxygenData.isNotEmpty) {
        double sum = 0;
        int count = 0;
        
        for (var data in bloodOxygenData) {
          if (data.value is num) {
            sum += (data.value as num).toDouble();
            count++;
          }
        }
        
        if (count > 0) {
          averageBloodOxygen = sum / count;
          developer.log('Average blood oxygen: $averageBloodOxygen%', name: TAG);
        }
      }
      
      return (averageBloodOxygen, null);
    } catch (e) {
      developer.log('Error fetching blood oxygen data: $e', name: TAG, error: e);
      return (null, 'Error fetching blood oxygen data: ${e.toString()}');
    }
  }

  // Fetch body fat percentage data
  Future<(double?, String?)> fetchBodyFatPercentage(DateTime startTime, DateTime endTime) async {
    try {
      developer.log('Fetching body fat percentage data from $startTime to $endTime', name: TAG);
      
      // Check if we have permission for body fat percentage
      final hasPermission = await hasPermissionForType(HealthDataType.BODY_FAT_PERCENTAGE);
      if (!hasPermission) {
        developer.log('Missing permission for body fat percentage data', name: TAG);
        return (null, 'Missing permission for body fat percentage data');
      }
      
      // Fetch body fat percentage data with retry logic
      List<HealthDataPoint> bodyFatData = [];
      try {
        bodyFatData = await health.getHealthDataFromTypes(
          types: [HealthDataType.BODY_FAT_PERCENTAGE],
          startTime: startTime,
          endTime: endTime,
        );
      } catch (e) {
        developer.log('First attempt to fetch body fat percentage failed: $e', name: TAG, error: e);
        // Try again with a different time range
        try {
          final adjustedStartTime = startTime.subtract(const Duration(days: 7));
          bodyFatData = await health.getHealthDataFromTypes(
            types: [HealthDataType.BODY_FAT_PERCENTAGE],
            startTime: adjustedStartTime,
            endTime: endTime,
          );
        } catch (e) {
          developer.log('Second attempt to fetch body fat percentage failed: $e', name: TAG, error: e);
          return (null, 'Failed to fetch body fat percentage data: ${e.toString()}');
        }
      }
      
      developer.log('Body fat percentage records: ${bodyFatData.length}', name: TAG);
      
      // Log detailed information about the data
      for (var data in bodyFatData) {
        developer.log('Body Fat - Source: ${data.sourceName}, Value: ${data.value}, Unit: ${data.unit}, Type: ${data.type}', name: TAG);
      }
      
      // Get the most recent valid body fat percentage
      double? bodyFatPercentage;
      if (bodyFatData.isNotEmpty) {
        // Sort by date to get the most recent
        bodyFatData.sort((a, b) => b.dateFrom.compareTo(a.dateFrom));
        
        // Find the first valid reading
        for (var data in bodyFatData) {
          if (data.value is num) {
            final value = (data.value as num).toDouble();
            // Validate the value is within reasonable range (0-100%)
            if (value >= 0 && value <= 100) {
              bodyFatPercentage = value;
              developer.log('Most recent body fat percentage: $bodyFatPercentage%', name: TAG);
              break;
            } else {
              developer.log('Invalid body fat percentage value: $value%', name: TAG);
            }
          }
        }
      }
      
      // If no valid reading found, try to estimate from BMI if available
      if (bodyFatPercentage == null) {
        developer.log('No valid body fat percentage found, attempting to estimate from BMI...', name: TAG);
        try {
          final bmiData = await health.getHealthDataFromTypes(
            types: [HealthDataType.BODY_MASS_INDEX],
            startTime: startTime,
            endTime: endTime,
          );
          
          if (bmiData.isNotEmpty) {
            // Sort by date to get the most recent
            bmiData.sort((a, b) => b.dateFrom.compareTo(a.dateFrom));
            
            for (var data in bmiData) {
              if (data.value is num) {
                final bmi = (data.value as num).toDouble();
                // Simple estimation formula: Body Fat % = (1.20 × BMI) + (0.23 × Age) - (3.8 × Gender) - 5.4
                // Using age 30 and gender 1 (male) as defaults
                const age = 30;
                const gender = 1; // 1 for male, 0 for female
                final estimatedBodyFat = (1.20 * bmi) + (0.23 * age) - (3.8 * gender) - 5.4;
                
                if (estimatedBodyFat >= 0 && estimatedBodyFat <= 100) {
                  bodyFatPercentage = estimatedBodyFat;
                  developer.log('Estimated body fat percentage from BMI: $bodyFatPercentage%', name: TAG);
                  break;
                }
              }
            }
          }
        } catch (e) {
          developer.log('Failed to estimate body fat from BMI: $e', name: TAG, error: e);
        }
      }
      
      return (bodyFatPercentage, null);
    } catch (e) {
      developer.log('Error fetching body fat percentage data: $e', name: TAG, error: e);
      return (null, 'Error fetching body fat percentage data: ${e.toString()}');
    }
  }

  // Fetch flights climbed data
  Future<(int?, String?)> fetchFlightsClimbed(DateTime startTime, DateTime endTime) async {
    try {
      developer.log('Fetching flights climbed data from $startTime to $endTime', name: TAG);
      
      // Check if we have permission for flights climbed
      final hasPermission = await hasPermissionForType(HealthDataType.FLIGHTS_CLIMBED);
      if (!hasPermission) {
        developer.log('Missing permission for flights climbed data', name: TAG);
        return (null, 'Missing permission for flights climbed data');
      }
      
      // Fetch flights climbed data with retry logic
      List<HealthDataPoint> flightsData = [];
      try {
        flightsData = await health.getHealthDataFromTypes(
          types: [HealthDataType.FLIGHTS_CLIMBED],
          startTime: startTime,
          endTime: endTime,
        );
      } catch (e) {
        developer.log('First attempt to fetch flights climbed failed: $e', name: TAG, error: e);
        // Try again with a different time range
        try {
          final adjustedStartTime = startTime.subtract(const Duration(hours: 1));
          flightsData = await health.getHealthDataFromTypes(
            types: [HealthDataType.FLIGHTS_CLIMBED],
            startTime: adjustedStartTime,
            endTime: endTime,
          );
        } catch (e) {
          developer.log('Second attempt to fetch flights climbed failed: $e', name: TAG, error: e);
          return (null, 'Failed to fetch flights climbed data: ${e.toString()}');
        }
      }
      
      developer.log('Flights climbed records: ${flightsData.length}', name: TAG);
      
      // Log detailed information about the data
      for (var data in flightsData) {
        developer.log('Flights Climbed - Source: ${data.sourceName}, Value: ${data.value}, Unit: ${data.unit}, Type: ${data.type}', name: TAG);
      }
      
      // Calculate total flights climbed
      int? totalFlights = 0;
      if (flightsData.isNotEmpty) {
        totalFlights = flightsData.fold(0, (sum, data) {
          if (data.value is num) {
            // Round to nearest integer since flights are whole numbers
            return sum + (data.value as num).round();
          }
          return sum;
        });
        
        // Validate the total is reasonable (e.g., not negative)
        if (totalFlights < 0) {
          developer.log('Invalid total flights climbed: $totalFlights', name: TAG);
          totalFlights = 0;
        }
        
        developer.log('Total flights climbed: $totalFlights', name: TAG);
      }
      
      // If no flights data is available, try to estimate from steps
      if (totalFlights == 0 && flightsData.isEmpty) {
        developer.log('No flights climbed data available, attempting to estimate from steps...', name: TAG);
        try {
          final stepsData = await health.getHealthDataFromTypes(
            types: [HealthDataType.STEPS],
            startTime: startTime,
            endTime: endTime,
          );
          
          if (stepsData.isNotEmpty) {
            // Calculate total steps
            int totalSteps = stepsData.fold(0, (sum, data) {
              if (data.value is num) {
                return sum + (data.value as num).round();
              }
              return sum;
            });
            
            // Rough estimation: 1 flight ≈ 10-12 steps
            // Using 11 steps per flight as an average
            const stepsPerFlight = 11;
            final estimatedFlights = (totalSteps / stepsPerFlight).round();
            
            if (estimatedFlights > 0) {
              totalFlights = estimatedFlights;
              developer.log('Estimated flights climbed from steps: $totalFlights', name: TAG);
            }
          }
        } catch (e) {
          developer.log('Failed to estimate flights from steps: $e', name: TAG, error: e);
        }
      }
      
      return (totalFlights, null);
    } catch (e) {
      developer.log('Error fetching flights climbed data: $e', name: TAG, error: e);
      return (null, 'Error fetching flights climbed data: ${e.toString()}');
    }
  }

  // Fetch heart rate data with proper error handling
  Future<(double?, String?)> fetchHeartRate(DateTime startTime, DateTime endTime) async {
    try {
      developer.log('Fetching heart rate data from $startTime to $endTime', name: TAG);
      
      // Check if we have permission for heart rate
      final hasPermission = await hasPermissionForType(HealthDataType.HEART_RATE);
      if (!hasPermission) {
        developer.log('Missing permission for heart rate data', name: TAG);
        return (null, 'Missing permission for heart rate data');
      }
      
      // Fetch heart rate data with retry logic
      List<HealthDataPoint> heartRateData = [];
      try {
        // Use a wider time range like steps
        final adjustedStartTime = startTime.subtract(const Duration(hours: 1));
        final adjustedEndTime = endTime.add(const Duration(hours: 1));
        
        heartRateData = await health.getHealthDataFromTypes(
          types: [HealthDataType.HEART_RATE],
          startTime: adjustedStartTime,
          endTime: adjustedEndTime,
        );
      } catch (e) {
        developer.log('First attempt to fetch heart rate failed: $e', name: TAG, error: e);
        // Try again with an even wider time range
        try {
          final adjustedStartTime = startTime.subtract(const Duration(hours: 2));
          final adjustedEndTime = endTime.add(const Duration(hours: 2));
          
          heartRateData = await health.getHealthDataFromTypes(
            types: [HealthDataType.HEART_RATE],
            startTime: adjustedStartTime,
            endTime: adjustedEndTime,
          );
        } catch (e) {
          developer.log('Second attempt to fetch heart rate failed: $e', name: TAG, error: e);
          // Don't return null on error, just log it
          developer.log('Failed to fetch heart rate data: ${e.toString()}', name: TAG, error: e);
        }
      }
      
      developer.log('Heart rate records: ${heartRateData.length}', name: TAG);
      
      // Log detailed information about the data
      for (var data in heartRateData) {
        developer.log('Heart Rate - Source: ${data.sourceName}, Value: ${data.value}, Unit: ${data.unit}, Type: ${data.type}', name: TAG);
      }
      
      // Get the most recent heart rate reading
      double? latestHeartRate;
      if (heartRateData.isNotEmpty) {
        // Sort by date to get the most recent
        heartRateData.sort((a, b) => b.dateFrom.compareTo(a.dateFrom));
        
        // Find the first valid reading
        for (var data in heartRateData) {
          if (data.value is num) {
            final value = (data.value as num).toDouble();
            // Validate the value is within reasonable range (30-250 bpm)
            if (value >= 30 && value <= 250) {
              latestHeartRate = value;
              developer.log('Most recent heart rate: $latestHeartRate bpm', name: TAG);
              break;
            } else {
              developer.log('Invalid heart rate value: $value bpm', name: TAG);
            }
          }
        }
      }
      
      return (latestHeartRate, null);
    } catch (e) {
      developer.log('Error fetching heart rate data: $e', name: TAG, error: e);
      return (null, 'Error fetching heart rate data: ${e.toString()}');
    }
  }

  // Fetch weight data with proper error handling
  Future<(List<HealthDataPoint>?, String?)> fetchWeightData(DateTime startTime, DateTime endTime) async {
    try {
      developer.log('Fetching weight data from $startTime to $endTime', name: TAG);
      
      // Check if we have permission for weight
      final hasPermission = await health.hasPermissions(weightTypes);
      if (hasPermission != true) {
        developer.log('Missing weight permissions, requesting...', name: TAG);
        final (authorized, error) = await requestWeightAuthorization();
        if (!authorized) {
          developer.log('Failed to get weight permissions: $error', name: TAG);
          return (null, error ?? 'Failed to get weight permissions');
        }
      }

      // Fetch weight data
      List<HealthDataPoint> weightData = [];
      try {
        weightData = await health.getHealthDataFromTypes(
          types: [HealthDataType.WEIGHT], // Only fetch weight data, not BMI or body fat
          startTime: startTime,
          endTime: endTime,
        );
        
        developer.log('Found ${weightData.length} weight records', name: TAG);
        
        // Log detailed information about the data
        for (var data in weightData) {
          developer.log('Weight Record - Source: ${data.sourceName}, Value: ${data.value}, Unit: ${data.unit}, Type: ${data.type}, Time: ${data.dateFrom}', name: TAG);
        }

        // Sort by date
        weightData.sort((a, b) => b.dateFrom.compareTo(a.dateFrom));
        
        return (weightData, null);
      } catch (e) {
        developer.log('Error fetching weight data: $e', name: TAG, error: e);
        return (null, 'Error fetching weight data: ${e.toString()}');
      }
    } catch (e) {
      developer.log('Error in fetchWeightData: $e', name: TAG, error: e);
      return (null, 'Error fetching weight data: ${e.toString()}');
    }
  }

  // Write weight data
  Future<(bool, String?)> writeWeight(double weightInKg, DateTime timestamp) async {
    try {
      developer.log('Writing weight data: $weightInKg kg at $timestamp', name: TAG);
      
      // Check if we have permission for weight
      final hasPermission = await health.hasPermissions([HealthDataType.WEIGHT]);
      if (hasPermission != true) {
        developer.log('Missing weight permissions, requesting...', name: TAG);
        final (authorized, error) = await requestWeightAuthorization();
        if (!authorized) {
          developer.log('Failed to get weight permissions: $error', name: TAG);
          return (false, error ?? 'Failed to get weight permissions');
        }
      }
      
      // Write weight data
      final success = await health.writeHealthData(
        value: weightInKg,
        type: HealthDataType.WEIGHT,
        startTime: timestamp,
        endTime: timestamp,
        recordingMethod: RecordingMethod.manual,
      );
      
      if (success) {
        developer.log('Successfully wrote weight data: $weightInKg kg at $timestamp', name: TAG);
        return (true, null);
      } else {
        developer.log('Failed to write weight data', name: TAG);
        return (false, 'Failed to write weight data');
      }
    } catch (e) {
      developer.log('Error writing weight data: $e', name: TAG, error: e);
      return (false, 'Error writing weight data: ${e.toString()}');
    }
  }

  // Fetch health data for a specific date
  Future<(Map<String, dynamic>?, String?)> fetchHealthData(DateTime date) async {
    try {
      // Get the start and end of the specified date
      final startTime = DateTime(date.year, date.month, date.day);
      final endTime = startTime.add(const Duration(days: 1));

      developer.log('Fetching health data from $startTime to $endTime', name: TAG);

      // Initialize with default values
      Map<String, dynamic> data = {
        'date': date,
        'steps': 0,
        'caloriesBurned': 0.0,
        'caloriesConsumed': 0.0,
        'basalCaloriesBurned': 0.0,
        'activeCaloriesBurned': 0.0,
        'bloodOxygen': null,
        'bodyFatPercentage': null,
        'flightsClimbed': 0,
        'heartRate': null,
        'restingHeartRate': null,
        'heartRateVariability': null,
        'sleepInBed': 0.0,
        'sleepAsleep': 0.0,
        'sleepDeep': 0.0,
        'sleepLight': 0.0,
        'sleepRem': 0.0,
        'waterIntake': 0.0,
        'exerciseTime': 0.0,
        'weight': null,
        'bmi': null,
        'bloodPressureSystolic': null,
        'bloodPressureDiastolic': null,
      };

      // Fetch weight data first since other calculations might depend on it
      try {
        final (weightData, weightError) = await fetchWeightData(startTime, endTime);
        if (weightError == null && weightData != null) {
          // Store the raw weight data points
          data['weight'] = weightData;
          developer.log('Successfully fetched weight data: ${weightData.length} records', name: TAG);
        } else {
          developer.log('Error fetching weight: $weightError', name: TAG);
        }
      } catch (e) {
        developer.log('Error in weight fetch: $e', name: TAG, error: e);
      }

      try {
        // Try to fetch steps with a wider time range to ensure we get all data
        final stepsStartTime = startTime.subtract(const Duration(hours: 1));
        final stepsEndTime = endTime.add(const Duration(hours: 1));
        final steps = await health.getTotalStepsInInterval(stepsStartTime, stepsEndTime);
        developer.log('Fetched steps from $stepsStartTime to $stepsEndTime: $steps', name: TAG);
        if (steps != null) {
          data['steps'] = steps;
        }
      } catch (e) {
        developer.log('Error fetching steps: $e', name: TAG, error: e);
      }
      
      try {
        // Fetch energy data (active and basal calories)
        final (activeEnergy, basalEnergy, error) = await fetchEnergyData(startTime, endTime);
        if (error == null) {
          if (activeEnergy != null) {
            data['activeCaloriesBurned'] = activeEnergy;
            data['caloriesBurned'] = activeEnergy; // Keep for backward compatibility
          }
          if (basalEnergy != null) {
            data['basalCaloriesBurned'] = basalEnergy;
          }
          developer.log('Energy data - Active: ${data['activeCaloriesBurned']}, Basal: ${data['basalCaloriesBurned']}', name: TAG);
        } else {
          developer.log('Error fetching energy data: $error', name: TAG);
        }
      } catch (e) {
        developer.log('Error in energy data fetch: $e', name: TAG, error: e);
      }

      try {
        // Try to fetch nutrition data (calories consumed)
        final nutritionData = await health.getHealthDataFromTypes(
          types: [HealthDataType.NUTRITION],
          startTime: startTime,
          endTime: endTime,
        );
        developer.log('Fetched nutrition data: ${nutritionData.length} records', name: TAG);

        // Calculate total calories consumed
        double totalCaloriesConsumed = 0;
        for (var data in nutritionData) {
          // Check if this is a calories entry
          if (data.value is num && 
              (data.sourceName.toLowerCase().contains('calories') || 
               data.sourceName.toLowerCase().contains('energy'))) {
            final value = (data.value as num).toDouble();
            totalCaloriesConsumed += value;
            developer.log('Found calories entry: ${data.sourceName} - $value', name: TAG);
          }
        }
        developer.log('Total calories consumed: $totalCaloriesConsumed', name: TAG);
        data['caloriesConsumed'] = totalCaloriesConsumed;
      } catch (e) {
        developer.log('Error fetching calories consumed: $e', name: TAG, error: e);
      }

      try {
        // Fetch heart rate data using the new method
        final (heartRate, heartRateError) = await fetchHeartRate(startTime, endTime);
        if (heartRateError == null && heartRate != null) {
          data['heartRate'] = heartRate;
        } else {
          developer.log('Error fetching heart rate: $heartRateError', name: TAG);
        }
      } catch (e) {
        developer.log('Error in heart rate fetch: $e', name: TAG, error: e);
      }

      try {
        // Fetch heart rate variability
        final hrvData = await health.getHealthDataFromTypes(
          types: [HealthDataType.HEART_RATE_VARIABILITY_SDNN],
          startTime: startTime,
          endTime: endTime,
        );
        if (hrvData.isNotEmpty) {
          // Get the most recent HRV reading
          hrvData.sort((a, b) => b.dateFrom.compareTo(a.dateFrom));
          final latestHrv = hrvData.first;
          if (latestHrv.value is num) {
            data['heartRateVariability'] = (latestHrv.value as num).toDouble();
          }
        }
      } catch (e) {
        developer.log('Error fetching heart rate variability: $e', name: TAG, error: e);
      }

      try {
        // Fetch resting heart rate
        final restingHeartRateData = await health.getHealthDataFromTypes(
          types: [HealthDataType.RESTING_HEART_RATE],
          startTime: startTime,
          endTime: endTime,
        );
        if (restingHeartRateData.isNotEmpty) {
          // Get the most recent resting heart rate
          restingHeartRateData.sort((a, b) => b.dateFrom.compareTo(a.dateFrom));
          final latestRestingHeartRate = restingHeartRateData.first;
          if (latestRestingHeartRate.value is num) {
            data['restingHeartRate'] = (latestRestingHeartRate.value as num).toDouble();
          }
        }
      } catch (e) {
        developer.log('Error fetching resting heart rate: $e', name: TAG, error: e);
      }

      try {
        // Fetch sleep data
        final sleepInBedData = await health.getHealthDataFromTypes(
          types: [HealthDataType.SLEEP_IN_BED],
          startTime: startTime,
          endTime: endTime,
        );
        if (sleepInBedData.isNotEmpty) {
          data['sleepInBed'] = sleepInBedData.fold(0.0, (sum, data) {
            if (data.value is num) {
              return sum + (data.value as num).toDouble();
            }
            return sum;
          });
        }

        final sleepAsleepData = await health.getHealthDataFromTypes(
          types: [HealthDataType.SLEEP_ASLEEP],
          startTime: startTime,
          endTime: endTime,
        );
        if (sleepAsleepData.isNotEmpty) {
          data['sleepAsleep'] = sleepAsleepData.fold(0.0, (sum, data) {
            if (data.value is num) {
              return sum + (data.value as num).toDouble();
            }
            return sum;
          });
        }

        final sleepDeepData = await health.getHealthDataFromTypes(
          types: [HealthDataType.SLEEP_DEEP],
          startTime: startTime,
          endTime: endTime,
        );
        if (sleepDeepData.isNotEmpty) {
          data['sleepDeep'] = sleepDeepData.fold(0.0, (sum, data) {
            if (data.value is num) {
              return sum + (data.value as num).toDouble();
            }
            return sum;
          });
        }

        final sleepLightData = await health.getHealthDataFromTypes(
          types: [HealthDataType.SLEEP_LIGHT],
          startTime: startTime,
          endTime: endTime,
        );
        if (sleepLightData.isNotEmpty) {
          data['sleepLight'] = sleepLightData.fold(0.0, (sum, data) {
            if (data.value is num) {
              return sum + (data.value as num).toDouble();
            }
            return sum;
          });
        }

        final sleepRemData = await health.getHealthDataFromTypes(
          types: [HealthDataType.SLEEP_REM],
          startTime: startTime,
          endTime: endTime,
        );
        if (sleepRemData.isNotEmpty) {
          data['sleepRem'] = sleepRemData.fold(0.0, (sum, data) {
            if (data.value is num) {
              return sum + (data.value as num).toDouble();
            }
            return sum;
          });
        }
      } catch (e) {
        developer.log('Error fetching sleep data: $e', name: TAG, error: e);
      }

      try {
        // Fetch water intake
        final waterData = await health.getHealthDataFromTypes(
          types: [HealthDataType.WATER],
          startTime: startTime,
          endTime: endTime,
        );
        if (waterData.isNotEmpty) {
          data['waterIntake'] = waterData.fold(0.0, (sum, data) {
            if (data.value is num) {
              return sum + (data.value as num).toDouble();
            }
            return sum;
          });
        }
      } catch (e) {
        developer.log('Error fetching water intake: $e', name: TAG, error: e);
      }

      try {
        // Fetch exercise time
        final exerciseData = await health.getHealthDataFromTypes(
          types: [HealthDataType.EXERCISE_TIME],
          startTime: startTime,
          endTime: endTime,
        );
        if (exerciseData.isNotEmpty) {
          data['exerciseTime'] = exerciseData.fold(0.0, (sum, data) {
            if (data.value is num) {
              return sum + (data.value as num).toDouble();
            }
            return sum;
          });
        }
      } catch (e) {
        developer.log('Error fetching exercise time: $e', name: TAG, error: e);
      }

      try {
        // Fetch BMI
        final bmiData = await health.getHealthDataFromTypes(
          types: [HealthDataType.BODY_MASS_INDEX],
          startTime: startTime,
          endTime: endTime,
        );
        if (bmiData.isNotEmpty) {
          bmiData.sort((a, b) => b.dateFrom.compareTo(a.dateFrom));
          final latestBmi = bmiData.first;
          if (latestBmi.value is num) {
            data['bmi'] = (latestBmi.value as num).toDouble();
          }
        }
      } catch (e) {
        developer.log('Error fetching BMI: $e', name: TAG, error: e);
      }

      try {
        // Fetch blood pressure
        final systolicData = await health.getHealthDataFromTypes(
          types: [HealthDataType.BLOOD_PRESSURE_SYSTOLIC],
          startTime: startTime,
          endTime: endTime,
        );
        if (systolicData.isNotEmpty) {
          systolicData.sort((a, b) => b.dateFrom.compareTo(a.dateFrom));
          final latestSystolic = systolicData.first;
          if (latestSystolic.value is num) {
            data['bloodPressureSystolic'] = (latestSystolic.value as num).toDouble();
          }
        }

        final diastolicData = await health.getHealthDataFromTypes(
          types: [HealthDataType.BLOOD_PRESSURE_DIASTOLIC],
          startTime: startTime,
          endTime: endTime,
        );
        if (diastolicData.isNotEmpty) {
          diastolicData.sort((a, b) => b.dateFrom.compareTo(a.dateFrom));
          final latestDiastolic = diastolicData.first;
          if (latestDiastolic.value is num) {
            data['bloodPressureDiastolic'] = (latestDiastolic.value as num).toDouble();
          }
        }
      } catch (e) {
        developer.log('Error fetching blood pressure: $e', name: TAG, error: e);
      }

      // After all data is fetched, verify weight data is still present
      developer.log('Final weight value in data map: ${data['weight']}', name: TAG);
      
      return (data, null);
    } catch (e) {
      developer.log('Error in fetchHealthData: $e', name: TAG, error: e);
      return (null, 'Error fetching health data: ${e.toString()}');
    }
  }

  // Keep the old method for backward compatibility
  Future<(Map<String, dynamic>?, String?)> fetchTodayHealthData() async {
    return fetchHealthData(DateTime.now());
  }

  // Test Health Connect connection
  Future<(bool, String?)> testHealthConnectConnection() async {
    try {
      developer.log('=== STARTING HEALTH CONNECT TEST ===', name: TAG);
      
      // Check Health Connect SDK status
      final status = await health.getHealthConnectSdkStatus();
      developer.log('Health Connect SDK Status: ${status?.name}', name: TAG);
      
      if (status != HealthConnectSdkStatus.sdkAvailable) {
        developer.log('Health Connect SDK not available', name: TAG);
        return (false, 'Health Connect SDK not available');
      }
      
      // Check if we have any permissions
      final hasPermission = await health.hasPermissions(weightTypes);
      developer.log('Weight permissions status: $hasPermission', name: TAG);
      
      if (hasPermission != true) {
        developer.log('No weight permissions found', name: TAG);
        return (false, 'No weight permissions found');
      }
      
      // Try to fetch a small amount of weight data
      final now = DateTime.now();
      final testStartTime = now.subtract(const Duration(days: 7));
      
      developer.log('Testing weight data fetch...', name: TAG);
      final (weightData, error) = await fetchWeightData(testStartTime, now);
      
      if (error != null) {
        developer.log('Weight data fetch test failed: $error', name: TAG);
        return (false, error);
      }
      
      developer.log('Weight data fetch test successful', name: TAG);
      developer.log('=== HEALTH CONNECT TEST COMPLETE ===', name: TAG);
      
      return (true, null);
    } catch (e) {
      developer.log('Error testing Health Connect connection: $e', name: TAG, error: e);
      return (false, 'Error testing Health Connect connection: ${e.toString()}');
    }
  }
} 