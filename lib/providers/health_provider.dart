import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/health_data_service.dart';

final healthDataServiceProvider = Provider<HealthDataService>((ref) {
  return HealthDataService();
});

final healthPermissionsProvider = StateNotifierProvider<HealthPermissionsNotifier, bool>((ref) {
  return HealthPermissionsNotifier(ref.watch(healthDataServiceProvider));
});

class HealthPermissionsNotifier extends StateNotifier<bool> {
  final HealthDataService _healthService;

  HealthPermissionsNotifier(this._healthService) : super(false) {
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final (hasPerms, _) = await _healthService.hasPermissions();
    state = hasPerms;
  }

  Future<(bool, String?)> requestPermissions() async {
    final (granted, errorMessage) = await _healthService.requestAuthorization();
    state = granted;
    return (granted, errorMessage);
  }
}

// Provider to track the last refresh time
final healthDataLastRefreshProvider = StateProvider<DateTime?>((ref) => null);

// Provider to force refresh the health data
final healthDataRefreshProvider = StateProvider<int>((ref) => 0);

final healthDataProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  // Watch the refresh trigger
  ref.watch(healthDataRefreshProvider);
  
  final healthService = ref.watch(healthDataServiceProvider);
  final hasPermissions = ref.watch(healthPermissionsProvider);
  
  if (!hasPermissions) {
    throw Exception('Health permissions not granted');
  }
  
  final (data, errorMessage) = await healthService.fetchTodayHealthData();
  if (errorMessage != null) {
    throw Exception(errorMessage);
  }
  
  // Update last refresh time
  ref.read(healthDataLastRefreshProvider.notifier).state = DateTime.now();
  
  return data!;
});

// Provider to check if data needs refresh (older than 15 minutes)
final healthDataNeedsRefreshProvider = Provider<bool>((ref) {
  final lastRefresh = ref.watch(healthDataLastRefreshProvider);
  if (lastRefresh == null) return true;
  
  final now = DateTime.now();
  final difference = now.difference(lastRefresh);
  return difference.inMinutes >= 15;
}); 