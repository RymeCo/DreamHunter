import 'package:flutter/material.dart';

class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.settings, size: 64, color: Colors.grey.shade600),
          const SizedBox(height: 16),
          Text(
            'General Settings',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const Text('Maintenance mode and backup settings will appear here.'),
        ],
      ),
    );
  }
}
