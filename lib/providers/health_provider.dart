import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health/health.dart';
import '../services/health_data_service.dart';

final healthDataServiceProvider = Provider<HealthDataService>((ref) {
  return HealthDataService();
});

final selectedDateProvider = StateProvider<DateTime>((ref) {
  return DateTime.now();
});

// Provider to track the last refresh time
final healthDataLastRefreshProvider = StateProvider<DateTime?>((ref) => null);

// Provider to force refresh the health data
final healthDataRefreshProvider = StateProvider<int>((ref) => 0);

// Provider to check if data needs refresh (older than 15 minutes)
final healthDataNeedsRefreshProvider = Provider<bool>((ref) {
  final lastRefresh = ref.watch(healthDataLastRefreshProvider);
  if (lastRefresh == null) return true;
  
  final now = DateTime.now();
  final difference = now.difference(lastRefresh);
  return difference.inMinutes >= 15;
});

final healthDataProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  // Watch the refresh trigger and selected date
  ref.watch(healthDataRefreshProvider);
  final selectedDate = ref.watch(selectedDateProvider);
  
  final healthService = ref.watch(healthDataServiceProvider);
  final hasPermissions = ref.watch(healthPermissionsProvider);
  
  // Return empty data if no permissions instead of throwing
  if (!hasPermissions) {
    return {
      'steps': 0,
      'caloriesBurned': 0.0,
      'caloriesConsumed': 0.0,
    };
  }
  
  final (data, errorMessage) = await healthService.fetchHealthData(selectedDate);
  if (errorMessage != null) {
    // Return empty data on error instead of throwing
    return {
      'steps': 0,
      'caloriesBurned': 0.0,
      'caloriesConsumed': 0.0,
    };
  }
  
  // Update last refresh time
  ref.read(healthDataLastRefreshProvider.notifier).state = DateTime.now();
  
  return data ?? {};
});

final healthPermissionsProvider = StateProvider<bool>((ref) {
  return false;
});

class HealthPermissionsNotifier extends StateNotifier<(bool, String?)> {
  final HealthDataService _healthService;
  final Ref _ref;

  HealthPermissionsNotifier(this._healthService, this._ref) : super((false, null)) {
    // Check permissions on initialization
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    try {
      final (hasPerms, _) = await _healthService.hasPermissions();
      state = (hasPerms, null);
      // Update the permissions provider
      _ref.read(healthPermissionsProvider.notifier).state = hasPerms;
    } catch (e) {
      print('Error checking permissions: $e');
      state = (false, e.toString());
    }
  }

  Future<(bool, String?)> requestPermissions() async {
    try {
      final (success, error) = await _healthService.requestAuthorization();
      if (success) {
        // If authorization was successful, verify we can actually access the data
        final (hasPerms, _) = await _healthService.hasPermissions();
        state = (hasPerms, null);
        // Update the permissions provider
        _ref.read(healthPermissionsProvider.notifier).state = hasPerms;
        return (hasPerms, null);
      } else {
        state = (false, error);
        return (false, error);
      }
    } catch (e) {
      print('Error requesting permissions: $e');
      state = (false, e.toString());
      return (false, e.toString());
    }
  }
}

final healthPermissionsNotifierProvider = StateNotifierProvider<HealthPermissionsNotifier, (bool, String?)>((ref) {
  final healthService = ref.watch(healthDataServiceProvider);
  return HealthPermissionsNotifier(healthService, ref);
}); 