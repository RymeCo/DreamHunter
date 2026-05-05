import 'package:flutter/material.dart';

class PlayerView extends StatelessWidget {
  const PlayerView({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people, size: 64, color: Colors.blue.shade400),
          const SizedBox(height: 16),
          Text(
            'Player Management',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const Text('Search and manage players from here.'),
        ],
      ),
    );
  }
}
