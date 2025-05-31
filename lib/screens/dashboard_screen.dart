import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/health_provider.dart';
import 'settings_screen.dart';

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
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  Future<void> _checkHealthPermissions() async {
    final hasPermissions = ref.read(healthPermissionsProvider);
    if (!hasPermissions) {
      // Go straight to requesting Health Connect permissions
      final (success, errorMessage) = await ref.read(healthPermissionsProvider.notifier).requestPermissions();
      if (!success && mounted) {
        _showErrorSnackBar(errorMessage ?? 'Failed to get health permissions. Some features may be limited.');
      }
    }
  }

  Future<void> _refreshData() async {
    ref.read(healthDataRefreshProvider.notifier).state++;
  }

  Widget _buildHealthCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
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
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final healthData = ref.watch(healthDataProvider);

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
          child: SizedBox(
            height: MediaQuery.of(context).size.height - 200, // Account for app bar and padding
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 32),
                healthData.when(
                  data: (data) => Column(
                    children: [
                      _buildHealthCard(
                        icon: Icons.directions_walk,
                        title: "Today's Steps",
                        value: _numberFormat.format(data['steps']),
                        color: Colors.blue,
                      ),
                      const SizedBox(height: 16),
                      _buildHealthCard(
                        icon: Icons.local_fire_department,
                        title: "Today's Calories Out",
                        value: '${_numberFormat.format(data['caloriesBurned'])} kcal',
                        color: Colors.orange,
                      ),
                      const SizedBox(height: 16),
                      _buildHealthCard(
                        icon: Icons.restaurant,
                        title: "Today's Calories In",
                        value: '${_numberFormat.format(data['caloriesConsumed'])} kcal',
                        color: Colors.green,
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
                  error: (error, stack) {
                    // Show error in next frame
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _showErrorSnackBar(error.toString());
                    });
                    return Column(
                      children: [
                        _buildHealthCard(
                          icon: Icons.directions_walk,
                          title: "Today's Steps",
                          value: 'N/A',
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        _buildHealthCard(
                          icon: Icons.local_fire_department,
                          title: "Today's Calories Out",
                          value: 'N/A',
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        _buildHealthCard(
                          icon: Icons.restaurant,
                          title: "Today's Calories In",
                          value: 'N/A',
                          color: Colors.grey,
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 