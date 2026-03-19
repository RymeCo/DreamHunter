import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/admin_provider.dart';
import '../services/admin_service.dart';
import '../widgets/custom_snackbar.dart';
import '../widgets/admin_ui_components.dart';

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
  }

  @override
  void dispose() {
    _refreshIconController.dispose();
    _broadcastController.dispose();
    super.dispose();
  }

  Future<void> _handleRefresh(AdminProvider provider) async {
    _refreshIconController.repeat();
    try {
      await provider.fetchStats(forceRefresh: true);
    } finally {
      if (mounted) {
        _refreshIconController.stop();
        _refreshIconController.reset();
      }
    }
  }

  void _sendBroadcast() async {
    if (_broadcastController.text.trim().isEmpty) return;
    final success = await _adminService.sendSystemBroadcastToAllRegions(
      _broadcastController.text.trim(),
    );
    if (!mounted) return;

    showCustomSnackBar(
      context,
      success ? 'Broadcast sent to all regions!' : 'Failed to send broadcast.',
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminHeader(
            title: 'System Overview',
            actions: [
              RotationTransition(
                turns: _refreshIconController,
                child: IconButton(
                  onPressed: () => _handleRefresh(provider),
                  icon: const Icon(Icons.sync_rounded,
                      size: 22, color: Colors.amberAccent),
                  tooltip: 'Sync Live Stats',
                ),
              ),
            ],
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final bool isWide = constraints.maxWidth > 900;
                final bool isMedium = constraints.maxWidth > 600;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Statistics Grid Logic: 2 top, 1 bottom stretch
                    if (provider.isLoadingStats)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 60),
                          child: CircularProgressIndicator(color: Colors.amberAccent),
                        ),
                      )
                    else if (provider.statsSummary != null)
                      _buildResponsiveStats(provider, isMedium)
                    else if (provider.statsErrorMessage != null)
                      _buildErrorState(provider),

                    const SizedBox(height: 32),

                    // Panel Grid Logic: side-by-side or stacked
                    if (isWide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 3, child: _buildBroadcastPanel()),
                          const SizedBox(width: 24),
                          Expanded(flex: 2, child: _buildMaintenancePanel(provider)),
                        ],
                      )
                    else
                      Column(
                        children: [
                          _buildBroadcastPanel(width: double.infinity),
                          const SizedBox(height: 24),
                          _buildMaintenancePanel(provider, width: double.infinity),
                        ],
                      ),
                    
                    const SizedBox(height: 48),
                  ],
                );
              }
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResponsiveStats(AdminProvider provider, bool isMedium) {
    final stats = provider.statsSummary!;
    final reportStats = stats['reportStats'] as Map<String, dynamic>? ?? {};
    final systemHealth = stats['systemHealth'] as Map<String, dynamic>? ?? {};
    final userGrowth = stats['userGrowth'] as Map<String, dynamic>? ?? {};

    if (isMedium) {
      return Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _statSection('Reports & Cases', [
                  _statRow('Pending', reportStats['pending'], Colors.redAccent),
                  _statRow('Active', reportStats['working'], Colors.orangeAccent),
                  _statRow('Resolved', reportStats['resolved'], Colors.greenAccent),
                ]),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: _statSection('System Health', [
                  _statRow('Latency', '${systemHealth['latency'] ?? 0}ms', Colors.blueAccent),
                  _statRow('Errors', systemHealth['errorCount'], Colors.redAccent),
                  _statRow('Status', systemHealth['status'] ?? 'Online', Colors.greenAccent),
                ]),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _statSection('Platform Growth', [
            _statRow('Total Users', userGrowth['total'], Colors.amberAccent),
            _statRow('New Today', userGrowth['newToday'], Colors.amberAccent),
            _statRow('Active (DAU)', userGrowth['dau'], Colors.amberAccent),
          ], width: double.infinity),
          const SizedBox(height: 24),
          _buildModerationOverview(),
        ],
      );
    } else {
      return Column(
        children: [
          _statSection('Reports & Cases', [
            _statRow('Pending', reportStats['pending'], Colors.redAccent),
            _statRow('Active', reportStats['working'], Colors.orangeAccent),
            _statRow('Resolved', reportStats['resolved'], Colors.greenAccent),
          ], width: double.infinity),
          const SizedBox(height: 24),
          _statSection('System Health', [
            _statRow('Latency', '${systemHealth['latency'] ?? 0}ms', Colors.blueAccent),
            _statRow('Errors', systemHealth['errorCount'], Colors.redAccent),
            _statRow('Status', systemHealth['status'] ?? 'Online', Colors.greenAccent),
          ], width: double.infinity),
          const SizedBox(height: 24),
          _statSection('Platform Growth', [
            _statRow('Total Users', userGrowth['total'], Colors.amberAccent),
            _statRow('New Today', userGrowth['newToday'], Colors.amberAccent),
            _statRow('Active (DAU)', userGrowth['dau'], Colors.amberAccent),
          ], width: double.infinity),
          const SizedBox(height: 24),
          _buildModerationOverview(),
        ],
      );
    }
  }

  Widget _buildModerationOverview() {
    return FutureBuilder<List<dynamic>>(
      future: _adminService.getAuditLogs(),
      builder: (context, snapshot) {
        final logs = snapshot.data ?? [];
        final recentCount = logs.length;
        
        return _statSection('Moderation Status', [
          _statRow('Recent Actions', recentCount, Colors.cyanAccent),
          _statRow('Last Action', recentCount > 0 ? (logs[0]['action'] ?? 'N/A') : 'None', Colors.white70),
          _statRow('Admin Activity', 'Stable', Colors.greenAccent),
        ], width: double.infinity);
      },
    );
  }

  Widget _buildBroadcastPanel({double? width}) {
    return AdminCard(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Emergency Broadcast',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.redAccent,
            ),
          ),
          const SizedBox(height: 16),
          AdminTextField(
            controller: _broadcastController,
            label: 'Broadcast Message',
            hint: 'Alert all active players...',
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          AdminButton(
            onPressed: _sendBroadcast,
            label: 'SEND ALERT',
            icon: Icons.campaign_rounded,
            color: Colors.redAccent,
          ),
        ],
      ),
    );
  }

  Widget _buildMaintenancePanel(AdminProvider provider, {double? width}) {
    return AdminCard(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Maintenance Controls',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          StreamBuilder(
            stream: _adminService.getSystemConfig(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};
              final chatMaint = data['chatMaintenance'] ?? false;
              final shopMaint = data['shopMaintenance'] ?? false;

              return Column(
                children: [
                  _maintSwitch(
                    'Global Chat Mode',
                    chatMaint,
                    (v) => provider.updateMaintenance(v, null),
                  ),
                  const Divider(height: 24, color: Color(0xFF2A2A4A)),
                  _maintSwitch(
                    'Marketplace Mode',
                    shopMaint,
                    (v) => provider.updateMaintenance(null, v),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _statSection(String title, List<Widget> rows, {double? width}) {
    return AdminCard(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: Colors.white24,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          ...rows,
        ],
      ),
    );
  }

  Widget _statRow(String label, dynamic value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value.toString(),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _maintSwitch(String label, bool value, ValueChanged<bool> onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Switch(
          value: value,
          onChanged: onChanged,
          activeTrackColor: Colors.amberAccent.withValues(alpha: 0.2),
          activeThumbColor: Colors.amberAccent,
        ),
      ],
    );
  }

  Widget _buildErrorState(AdminProvider provider) {
    return AdminCard(
      width: double.infinity,
      child: Column(
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 40),
          const SizedBox(height: 16),
          Text(provider.statsErrorMessage!, style: const TextStyle(color: Colors.redAccent)),
          const SizedBox(height: 16),
          AdminButton(
            onPressed: () => _handleRefresh(provider),
            label: 'RETRY CONNECTION',
            color: Colors.white24,
          ),
        ],
      ),
    );
  }
}
