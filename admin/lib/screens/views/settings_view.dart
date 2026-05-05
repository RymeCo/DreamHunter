import 'dart:convert';
import 'package:flutter/material.dart';
import '../../api_gateway.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  final ApiGateway _api = ApiGateway();
  bool _isLoading = true;
  
  // Settings state
  bool _maintenanceMode = false;
  bool _leaderboardPaused = false;
  bool _chatEnabled = true;

  @override
  void initState() {
    super.initState();
    _fetchSettings();
  }

  Future<void> _fetchSettings() async {
    try {
      final response = await _api.get('/settings');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _maintenanceMode = data['maintenance_mode'] ?? false;
          _leaderboardPaused = data['leaderboard_paused'] ?? false;
          _chatEnabled = data['chat_enabled'] ?? true;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching settings: $e')),
        );
      }
    }
  }

  Future<void> _updateSetting(String key, bool value) async {
    final originalSettings = {
      'maintenance_mode': _maintenanceMode,
      'leaderboard_paused': _leaderboardPaused,
      'chat_enabled': _chatEnabled,
    };

    setState(() {
      if (key == 'maintenance_mode') _maintenanceMode = value;
      if (key == 'leaderboard_paused') _leaderboardPaused = value;
      if (key == 'chat_enabled') _chatEnabled = value;
    });

    try {
      final response = await _api.patch(
        '/settings',
        body: {key: value},
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to update settings');
      }
    } catch (e) {
      setState(() {
        _maintenanceMode = originalSettings['maintenance_mode']!;
        _leaderboardPaused = originalSettings['leaderboard_paused']!;
        _chatEnabled = originalSettings['chat_enabled']!;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating setting: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'General Settings',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Global system switches and maintenance controls.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 32),
          
          _buildToggleCard(
            title: 'Maintenance Mode',
            subtitle: 'When enabled, only admins can log in and play.',
            value: _maintenanceMode,
            icon: Icons.construction,
            onChanged: (val) => _updateSetting('maintenance_mode', val),
            isDestructive: true,
          ),
          
          const SizedBox(height: 16),
          
          _buildToggleCard(
            title: 'Pause Leaderboard',
            subtitle: 'Temporarily hide and stop leaderboard updates.',
            value: _leaderboardPaused,
            icon: Icons.pause_circle_outline,
            onChanged: (val) => _updateSetting('leaderboard_paused', val),
          ),
          
          const SizedBox(height: 16),
          
          _buildToggleCard(
            title: 'Enable Chat',
            subtitle: 'Global toggle for the player chat system.',
            value: _chatEnabled,
            icon: Icons.chat_outlined,
            onChanged: (val) => _updateSetting('chat_enabled', val),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleCard({
    required String title,
    required String subtitle,
    required bool value,
    required IconData icon,
    required ValueChanged<bool> onChanged,
    bool isDestructive = false,
  }) {
    return Card(
      elevation: 0,
      color: Theme.of(context)
          .colorScheme
          .surfaceContainerHighest
          .withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: SwitchListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        value: value,
        onChanged: onChanged,
        secondary: Icon(
          icon,
          color: value
              ? (isDestructive ? Colors.orange : Theme.of(context).colorScheme.primary)
              : Theme.of(context).colorScheme.outline,
        ),
      ),
    );
  }
}
