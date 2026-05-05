import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../api_gateway.dart';

class HealthView extends StatefulWidget {
  const HealthView({super.key});

  @override
  State<HealthView> createState() => _HealthViewState();
}

class _HealthViewState extends State<HealthView> {
  final ApiGateway _api = ApiGateway();
  bool _isLoading = false;
  Map<String, dynamic>? _healthData;
  DateTime? _lastChecked;

  Future<void> _checkHealth() async {
    setState(() => _isLoading = true);
    try {
      final response = await _api.get('/admin/system/health');
      if (!mounted) return;
      if (response.statusCode == 200) {
        setState(() {
          _healthData = json.decode(response.body);
          _lastChecked = DateTime.now();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to fetch system health: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'System Health',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _lastChecked == null
                          ? 'Snapshot not yet taken.'
                          : 'Last checked (PHT): ${DateFormat('HH:mm:ss').format(_lastChecked!.toUtc().add(const Duration(hours: 8)))} | ${DateFormat('hh:mm:ss a').format(_lastChecked!.toUtc().add(const Duration(hours: 8)))}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _checkHealth,
                icon: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                label: const Text('Fetch Status'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Expanded(
            child: _healthData == null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.monitor_heart_outlined,
                          size: 64,
                          color: Theme.of(
                            context,
                          ).colorScheme.outline.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Tap "Fetch Status" to perform a manual health check.',
                        ),
                      ],
                    ),
                  )
                : GridView.count(
                    crossAxisCount: MediaQuery.of(context).size.width > 900
                        ? 3
                        : 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: MediaQuery.of(context).size.width > 600
                        ? 1.5
                        : 1.1,
                    children: [
                      _buildMetricCard(
                        'Server Status',
                        'ONLINE',
                        Icons.check_circle_outline,
                        Colors.green,
                      ),
                      _buildMetricCard(
                        'Maintenance',
                        _healthData!['maintenanceMode'] == true
                            ? 'ACTIVE'
                            : 'OFF',
                        Icons.construction,
                        _healthData!['maintenanceMode'] == true
                            ? Colors.red
                            : Colors.green,
                      ),
                      _buildMetricCard(
                        'Total Players',
                        '${_healthData!['totalPlayers']}',
                        Icons.people_outline,
                        Colors.blue,
                      ),
                      _buildMetricCard(
                        'New Today',
                        '${_healthData!['newPlayersToday']}',
                        Icons.person_add_alt_1_outlined,
                        Colors.teal,
                      ),
                      _buildMetricCard(
                        'Banned Players',
                        '${_healthData!['bannedPlayers']}',
                        Icons.block,
                        Colors.red,
                      ),
                      _buildMetricCard(
                        'Chat Connections',
                        '${_healthData!['activeChatConnections']}',
                        Icons.chat_bubble_outline,
                        Colors.orange,
                      ),
                      _buildMetricCard(
                        'Active Regions',
                        '${_healthData!['activeRegions']}',
                        Icons.public,
                        Colors.deepPurple,
                      ),
                      _buildMetricCard(
                        'Leaderboard',
                        _healthData!['leaderboardPaused'] == true
                            ? 'PAUSED'
                            : 'LIVE',
                        Icons.leaderboard_outlined,
                        _healthData!['leaderboardPaused'] == true
                            ? Colors.orange
                            : Colors.blue,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
