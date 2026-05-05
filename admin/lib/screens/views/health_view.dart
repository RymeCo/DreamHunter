import 'package:flutter/material.dart';

class HealthView extends StatelessWidget {
  const HealthView({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.monitor_heart, size: 64, color: Colors.green.shade400),
          const SizedBox(height: 16),
          Text(
            'System Health',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const Text('Backend status and logs will appear here.'),
        ],
      ),
    );
  }
}
