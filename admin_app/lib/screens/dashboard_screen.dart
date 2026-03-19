import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/admin_service.dart';
import '../widgets/custom_snackbar.dart';
import '../widgets/liquid_glass_dialog.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final AdminService _adminService = AdminService();
  bool _isPinging = false;
  String _pingStatus = 'Unknown';
  final TextEditingController _broadcastController = TextEditingController();

  Map<String, dynamic>? _statsSummary;
  bool _isLoadingStats = true;
  String? _statsErrorMessage;

  @override
  void initState() {
    super.initState();
    _pingServer();
    _fetchStats();
  }

  void _fetchStats() async {
    setState(() {
      _isLoadingStats = true;
      _statsErrorMessage = null;
    });
    try {
      final stats = await _adminService.getStatsSummary();
      if (!mounted) return;
      setState(() {
        _statsSummary = stats;
        _isLoadingStats = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statsErrorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoadingStats = false;
      });
    }
  }

  void _pingServer() async {
    if (!mounted) return;
    setState(() {
      _isPinging = true;
      _pingStatus = 'Pinging...';
    });
    final latency = await _adminService.pingServer();
    if (!mounted) return;
    setState(() {
      _isPinging = false;
      _pingStatus = latency != null
          ? 'Online (${latency}ms)'
          : 'Offline/Timeout';
    });
  }

  void _sendBroadcast() async {
    if (_broadcastController.text.trim().isEmpty) return;
    final success = await _adminService.sendGlobalBroadcast(
      _broadcastController.text.trim(),
      false,
    );
    if (!mounted) return;

    showCustomSnackBar(
      context,
      success ? 'Broadcast sent!' : 'Failed to send broadcast.',
      type: success ? SnackBarType.success : SnackBarType.error,
    );

    if (success) {
      _broadcastController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Dashboard Overview',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              IconButton(
                onPressed: _fetchStats,
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh Stats',
              ),
            ],
          ),
          const SizedBox(height: 24),

          if (_isLoadingStats)
            const Center(child: CircularProgressIndicator())
          else if (_statsSummary != null) ...[
            _buildChartsSection(),
            const SizedBox(height: 24),
          ] else ...[
            Center(
              child: Column(
                children: [
                  const Icon(Icons.error_outline, color: Colors.redAccent, size: 40),
                  const SizedBox(height: 8),
                  Text(
                    _statsErrorMessage ?? 'Failed to load dashboard statistics.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                  TextButton(
                    onPressed: _fetchStats,
                    child: const Text('Retry Fetch'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Service Health
          LiquidGlassDialog(
            width: double.infinity,
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Service Health',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 20,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _isPinging ? null : _pingServer,
                      icon: _isPinging
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.network_ping),
                      label: const Text('Ping Backend'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                      ),
                    ),
                    Text(
                      'Status: $_pingStatus',
                      style: TextStyle(
                        color: _pingStatus.contains('Online')
                            ? Colors.greenAccent
                            : Colors.redAccent,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Maintenance Controls
          LiquidGlassDialog(
            width: double.infinity,
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Maintenance Controls',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                StreamBuilder(
                  stream: _adminService.getSystemConfig(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const CircularProgressIndicator();
                    }
                    final data =
                        snapshot.data!.data() as Map<String, dynamic>? ?? {};
                    final chatMaint = data['chatMaintenance'] ?? false;
                    final shopMaint = data['shopMaintenance'] ?? false;

                    return Column(
                      children: [
                        SwitchListTile(
                          title: const Text('Chat Maintenance Mode'),
                          subtitle: const Text(
                            'Disables the global chat for all players.',
                          ),
                          value: chatMaint,
                          onChanged: (val) =>
                              _adminService.updateMaintenance(val, null),
                          activeThumbColor: Colors.orangeAccent,
                        ),
                        SwitchListTile(
                          title: const Text('Shop Maintenance Mode'),
                          subtitle: const Text('Disables the shop interface.'),
                          value: shopMaint,
                          onChanged: (val) =>
                              _adminService.updateMaintenance(null, val),
                          activeThumbColor: Colors.orangeAccent,
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Emergency Broadcast
          LiquidGlassDialog(
            width: double.infinity,
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Emergency Broadcast',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.redAccent,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _broadcastController,
                  decoration: const InputDecoration(
                    labelText: 'Broadcast Message',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.black12,
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _sendBroadcast,
                  icon: const Icon(Icons.campaign),
                  label: const Text('Send Global Alert'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartsSection() {
    final reportStats = _statsSummary?['reportStats'] as Map<String, dynamic>? ?? {};
    final activityTrends = _statsSummary?['activityTrends'] as List<dynamic>? ?? [];

    return Column(
      children: [
        LiquidGlassDialog(
          height: 250,
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Text('Reports Status (Pending, Working, Resolved)',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              Expanded(
                child: BarChart(
                  BarChartData(
                    gridData: const FlGridData(show: false),
                    titlesData: const FlTitlesData(show: false),
                    borderData: FlBorderData(show: false),
                    barGroups: [
                      BarChartGroupData(
                        x: 0,
                        barRods: [
                          BarChartRodData(
                            toY: (reportStats['pending'] as num? ?? 0).toDouble(),
                            color: Colors.redAccent,
                            width: 25,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ],
                      ),
                      BarChartGroupData(
                        x: 1,
                        barRods: [
                          BarChartRodData(
                            toY: (reportStats['working'] as num? ?? 0).toDouble(),
                            color: Colors.orangeAccent,
                            width: 25,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ],
                      ),
                      BarChartGroupData(
                        x: 2,
                        barRods: [
                          BarChartRodData(
                            toY: (reportStats['resolved'] as num? ?? 0).toDouble(),
                            color: Colors.greenAccent,
                            width: 25,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        LiquidGlassDialog(
          height: 300,
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Text('Weekly Activity (Logins & Messages)',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              Expanded(
                child: activityTrends.isEmpty
                    ? const Center(child: Text('No activity data available'))
                    : LineChart(
                        LineChartData(
                          gridData: const FlGridData(show: false),
                          titlesData: const FlTitlesData(show: false),
                          borderData: FlBorderData(show: false),
                          lineBarsData: [
                            LineChartBarData(
                              spots: activityTrends.asMap().entries.map((e) {
                                return FlSpot(e.key.toDouble(),
                                    (e.value['messages'] as num? ?? 0).toDouble());
                              }).toList(),
                              isCurved: false, // Performance: Set to false
                              color: Colors.blueAccent,
                              barWidth: 3,
                              dotData: const FlDotData(show: true),
                              belowBarData: BarAreaData(
                                show: true,
                                color: Colors.blueAccent.withValues(alpha: 0.1),
                              ),
                            ),
                            LineChartBarData(
                              spots: activityTrends.asMap().entries.map((e) {
                                return FlSpot(e.key.toDouble(),
                                    (e.value['logins'] as num? ?? 0).toDouble());
                              }).toList(),
                              isCurved: false, // Performance: Set to false
                              color: Colors.purpleAccent,
                              barWidth: 3,
                              dotData: const FlDotData(show: true),
                              belowBarData: BarAreaData(
                                show: true,
                                color: Colors.purpleAccent.withValues(alpha: 0.1),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
