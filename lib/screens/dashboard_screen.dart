import 'package:flutter/material.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 32),
            Card(
              child: ListTile(
                leading: const Icon(Icons.directions_walk),
                title: const Text("Today's Steps"),
                trailing: const Text('12346'), // Placeholder
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.local_fire_department),
                title: const Text("Today's Calories Out"),
                trailing: const Text('N/A'), // Placeholder
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.restaurant),
                title: const Text("Today's Calories In"),
                trailing: const Text('N/A'), // Placeholder
              ),
            ),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: () {
                // TODO: Implement logout functionality
              },
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 