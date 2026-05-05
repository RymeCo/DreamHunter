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
      if (response.statusCode == 200) {
        setState(() {
          _healthData = json.decode(response.body);
          _lastChecked = DateTime.now();
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'System Health',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _lastChecked == null
                        ? 'Snapshot not yet taken.'
                        : 'Last checked: ${DateFormat('HH:mm:ss').format(_lastChecked!)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
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
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                        Icon(Icons.monitor_heart_outlined,
                            size: 64,
                            color: Theme.of(context)
                                .colorScheme
                                .outline
                                .withValues(alpha: 0.3)),
                        const SizedBox(height: 16),
                        const Text('Tap "Fetch Status" to perform a manual health check.'),
                      ],
                    ),
                  )
                : GridView.count(
                    crossAxisCount: MediaQuery.of(context).size.width > 900 ? 3 : 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.5,
                    children: [
                      _buildMetricCard(
                        'Server Status',
                        'ONLINE',
                        Icons.check_circle_outline,
                        Colors.green,
                      ),
                      _buildMetricCard(
                        'Total Players',
                        '${_healthData!['totalPlayers']}',
                        Icons.people_outline,
                        Colors.blue,
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
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 12),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            Text(
              title,
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
