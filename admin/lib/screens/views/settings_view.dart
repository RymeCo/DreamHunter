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
  bool _isRefreshing = false;
  
  // Settings state
  bool _maintenanceMode = false;
  bool _leaderboardPaused = false;
  bool _leaderboardDisabled = false;
  bool _backupDisabled = false;
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
          _leaderboardDisabled = data['leaderboard_disabled'] ?? false;
          _backupDisabled = data['backup_disabled'] ?? false;
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
      'leaderboard_disabled': _leaderboardDisabled,
      'backup_disabled': _backupDisabled,
      'chat_enabled': _chatEnabled,
    };

    setState(() {
      if (key == 'maintenance_mode') _maintenanceMode = value;
      if (key == 'leaderboard_paused') _leaderboardPaused = value;
      if (key == 'leaderboard_disabled') _leaderboardDisabled = value;
      if (key == 'backup_disabled') _backupDisabled = value;
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
        _leaderboardDisabled = originalSettings['leaderboard_disabled']!;
        _backupDisabled = originalSettings['backup_disabled']!;
        _chatEnabled = originalSettings['chat_enabled']!;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating setting: $e')),
        );
      }
    }
  }

  Future<void> _forceRefresh() async {
    setState(() => _isRefreshing = true);
    try {
      final response = await _api.post('/leaderboard/refresh');
      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Leaderboard refreshed successfully!')),
          );
        }
      } else {
        throw Exception('Server returned ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to refresh leaderboard: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  Future<void> _clearLeaderboard(String metric) async {
    setState(() => _isRefreshing = true);
    try {
      final response = await _api.post('/leaderboard/clear?metric=$metric');
      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Leaderboard for $metric cleared!')),
          );
        }
      } else {
        throw Exception('Server returned ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to clear leaderboard: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  void _showClearLeaderboardDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Leaderboard'),
        content: const Text(
            'Which metric do you want to clear? This will reset the rankings for all players in that category.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _clearLeaderboard('level');
            },
            child: const Text('Reset Levels', style: TextStyle(color: Colors.orange)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _clearLeaderboard('coins');
            },
            child: const Text('Reset Coins', style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: ListView(
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
            'Global system switches and access controls.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 32),
          
          _buildToggleCard(
            title: 'Disable Login',
            subtitle: 'When enabled, only admins can log in and play.',
            value: _maintenanceMode,
            icon: Icons.block,
            onChanged: (val) => _updateSetting('maintenance_mode', val),
            isDestructive: true,
          ),
          
          const SizedBox(height: 16),
          
          _buildToggleCard(
            title: 'Pause Leaderboard',
            subtitle: 'Stop calculating new rankings. The last results remain visible.',
            value: _leaderboardPaused,
            icon: Icons.pause_circle_outline,
            onChanged: (val) => _updateSetting('leaderboard_paused', val),
          ),

          const SizedBox(height: 16),
          
          _buildToggleCard(
            title: 'Disable Leaderboard',
            subtitle: 'Hide all leaderboard data. No one will show up.',
            value: _leaderboardDisabled,
            icon: Icons.visibility_off_outlined,
            onChanged: (val) => _updateSetting('leaderboard_disabled', val),
            isDestructive: true,
          ),

          const SizedBox(height: 16),
          
          _buildToggleCard(
            title: 'Disable Backup',
            subtitle: 'Prevent players from backing up their local data to the cloud.',
            value: _backupDisabled,
            icon: Icons.cloud_off,
            onChanged: (val) => _updateSetting('backup_disabled', val),
            isDestructive: true,
          ),
          
          const SizedBox(height: 16),
          
          _buildToggleCard(
            title: 'Enable Chat',
            subtitle: 'Global toggle for the player chat system.',
            value: _chatEnabled,
            icon: Icons.chat_outlined,
            onChanged: (val) => _updateSetting('chat_enabled', val),
          ),
          
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 24),
          
          Text(
            'Actions',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          
          Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: 280,
              child: OutlinedButton.icon(
                onPressed: _isRefreshing || _leaderboardPaused ? null : _forceRefresh,
                icon: _isRefreshing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                label: Text(_isRefreshing ? 'Refreshing...' : 'Force Leaderboard Refresh'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: 280,
              child: OutlinedButton.icon(
                onPressed: _isRefreshing || _leaderboardPaused ? null : _showClearLeaderboardDialog,
                icon: const Icon(Icons.delete_sweep, color: Colors.orange),
                label: const Text('Clear Leaderboard Cache'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
          if (_leaderboardPaused)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                'Cannot refresh while leaderboard is paused.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
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
