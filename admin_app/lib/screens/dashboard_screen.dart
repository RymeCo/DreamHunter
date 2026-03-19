import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/admin_provider.dart';
import '../services/admin_service.dart';
import '../widgets/custom_snackbar.dart';
import '../widgets/liquid_glass_dialog.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  final AdminService _adminService = AdminService();
  final TextEditingController _broadcastController = TextEditingController();

  late AnimationController _refreshIconController;

  @override
  void initState() {
    super.initState();
    _refreshIconController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    // Initial fetch handled by Provider
  }

  @override
  void dispose() {
    _refreshIconController.dispose();
    _broadcastController.dispose();
    super.dispose();
  }

  Future<void> _handleRefresh(AdminProvider provider) async {
    _refreshIconController.repeat();
    await provider.fetchStats(forceRefresh: true);
    if (mounted) {
      _refreshIconController.stop();
      _refreshIconController.reset();
    }
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
    final provider = Provider.of<AdminProvider>(context);

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
              RotationTransition(
                turns: _refreshIconController,
                child: IconButton(
                  onPressed: () => _handleRefresh(provider),
                  icon: const Icon(Icons.refresh, size: 32),
                  tooltip: 'Refresh Stats',
                  color: Colors.amberAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Emergency Broadcast (MOVED TO TOP)
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
          const SizedBox(height: 24),

          // Statistics Section
          if (provider.isLoadingStats)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: CircularProgressIndicator(),
              ),
            )
          else if (provider.statsSummary != null) ...[
            _buildSpreadsheetSection(provider),
            const SizedBox(height: 24),
          ] else if (provider.statsErrorMessage != null) ...[
            Center(
              child: Column(
                children: [
                  const Icon(Icons.error_outline,
                      color: Colors.redAccent, size: 40),
                  const SizedBox(height: 8),
                  Text(
                    provider.statsErrorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                  TextButton(
                    onPressed: () => _handleRefresh(provider),
                    child: const Text('Retry Fetch'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

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
                              provider.updateMaintenance(val, null),
                          activeThumbColor: Colors.orangeAccent,
                        ),
                        SwitchListTile(
                          title: const Text('Shop Maintenance Mode'),
                          subtitle: const Text('Disables the shop interface.'),
                          value: shopMaint,
                          onChanged: (val) =>
                              provider.updateMaintenance(null, val),
                          activeThumbColor: Colors.orangeAccent,
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpreadsheetSection(AdminProvider provider) {
    final stats = provider.statsSummary!;
    final reportStats = stats['reportStats'] as Map<String, dynamic>? ?? {};
    final systemHealth = stats['systemHealth'] as Map<String, dynamic>? ?? {};
    final userGrowth = stats['userGrowth'] as Map<String, dynamic>? ?? {};

    return Column(
      children: [
        _buildDataLayer('Support & Reports', [
          _dataRow('Pending Reports', reportStats['pending'], Colors.redAccent),
          _dataRow('Active Cases', reportStats['working'], Colors.orangeAccent),
          _dataRow(
              'Resolved Today', reportStats['resolved'], Colors.greenAccent),
        ]),
        const SizedBox(height: 16),
        _buildDataLayer('System Performance', [
          _dataRow(
            'API Latency',
            '${systemHealth['latency'] ?? 0} ms',
            Colors.blueAccent,
            onTap: () => _handleRefresh(provider),
          ),
          _dataRow(
              'Recent Errors', systemHealth['errorCount'], Colors.redAccent),
          _dataRow('Server Status', systemHealth['status'] ?? 'Unknown',
              Colors.greenAccent),
        ]),
        const SizedBox(height: 16),
        _buildDataLayer('Platform Growth', [
          _dataRow(
              'Registered Players', userGrowth['total'], Colors.amberAccent),
          _dataRow('New Today', userGrowth['newToday'], Colors.amberAccent),
          _dataRow('Daily Active (DAU)', userGrowth['dau'], Colors.amberAccent),
        ]),
      ],
    );
  }

  Widget _buildDataLayer(String title, List<Widget> rows) {
    return LiquidGlassDialog(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.amberAccent,
            ),
          ),
          const SizedBox(height: 12),
          ...rows,
        ],
      ),
    );
  }

  Widget _dataRow(String label, dynamic value, Color color,
      {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(label, style: const TextStyle(fontSize: 15)),
                if (onTap != null) ...[
                  const SizedBox(width: 8),
                  RotationTransition(
                    turns: _refreshIconController,
                    child: Icon(
                      Icons.refresh,
                      size: 18,
                      color: color.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Text(
                value.toString(),
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
