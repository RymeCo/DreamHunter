import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/admin_provider.dart';
import '../widgets/admin_ui_components.dart';
import '../widgets/liquid_glass_panel.dart';

class ServiceOpsScreen extends StatefulWidget {
  const ServiceOpsScreen({super.key});

  @override
  State<ServiceOpsScreen> createState() => _ServiceOpsScreenState();
}

class _ServiceOpsScreenState extends State<ServiceOpsScreen> {
  final _broadcastController = TextEditingController();
  bool _isPersistent = false;
  bool _isBroadcasting = false;

  @override
  void dispose() {
    _broadcastController.dispose();
    super.dispose();
  }

  void _sendBroadcast() async {
    final message = _broadcastController.text.trim();
    if (message.isEmpty) return;

    setState(() => _isBroadcasting = true);
    final adminProvider = Provider.of<AdminProvider>(context, listen: false);
    final success = await adminProvider.service.sendGlobalBroadcast(message, _isPersistent);

    if (mounted) {
      setState(() => _isBroadcasting = false);
      if (success) {
        _broadcastController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Broadcast sent successfully!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send broadcast.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Service Operations',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Control "Online Bridge" services and system-wide announcements.',
            style: TextStyle(color: Colors.white38, fontSize: 16),
          ),
          const SizedBox(height: 32),
          
          StreamBuilder(
            stream: Provider.of<AdminProvider>(context, listen: false).service.getSystemConfig(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              
              final config = snapshot.data?.data() as Map<String, dynamic>? ?? {};
              final chatMaintenance = config['chatMaintenance'] ?? false;
              final syncMaintenance = config['syncMaintenance'] ?? false;
              final shopMaintenance = config['shopMaintenance'] ?? false;

              return LayoutBuilder(
                builder: (context, constraints) {
                  final crossAxisCount = constraints.maxWidth > 900 ? 3 : (constraints.maxWidth > 600 ? 2 : 1);
                  return GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: crossAxisCount,
                    childAspectRatio: 2.5,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    children: [
                      _buildMaintenanceCard(
                        'Chat Service',
                        'Disables global chat and moderator coordination.',
                        chatMaintenance,
                        Icons.forum_rounded,
                        (val) => _toggleMaintenance(chat: val),
                      ),
                      _buildMaintenanceCard(
                        'Sync Service',
                        'Disables cloud save uploads and conflict resolution.',
                        syncMaintenance,
                        Icons.sync_rounded,
                        (val) => _toggleMaintenance(sync: val),
                      ),
                      _buildMaintenanceCard(
                        'Shop Service',
                        'Disables server-side purchase verification.',
                        shopMaintenance,
                        Icons.storefront_rounded,
                        (val) => _toggleMaintenance(shop: val),
                      ),
                    ],
                  );
                },
              );
            },
          ),
          
          const SizedBox(height: 32),
          
          AdminCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.campaign_rounded, color: Colors.amberAccent),
                    SizedBox(width: 12),
                    Text(
                      'Global Broadcast',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.amberAccent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Send a high-priority message to all active players. Use sparingly.',
                  style: TextStyle(color: Colors.white54, fontSize: 14),
                ),
                const SizedBox(height: 24),
                AdminTextField(
                  controller: _broadcastController,
                  label: 'Broadcast Message',
                  maxLines: 3,
                  prefixIcon: Icons.message_rounded,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Switch(
                      value: _isPersistent,
                      onChanged: (val) => setState(() => _isPersistent = val),
                      activeThumbColor: Colors.amberAccent,
                    ),
                    const Text('Persistent (Show until closed by user)'),
                    const Spacer(),
                    AdminButton(
                      onPressed: _isBroadcasting ? null : _sendBroadcast,
                      label: 'TRANSMIT',
                      icon: Icons.send_rounded,
                      isLoading: _isBroadcasting,
                      color: Colors.amberAccent,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaintenanceCard(
    String title,
    String description,
    bool isActive,
    IconData icon,
    Function(bool) onChanged,
  ) {
    return LiquidGlassPanel(
      padding: const EdgeInsets.all(16),
      color: isActive 
          ? Colors.redAccent.withValues(alpha: 0.1) 
          : Colors.white.withValues(alpha: 0.05),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isActive ? Colors.redAccent.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: isActive ? Colors.redAccent : Colors.white70,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isActive ? Colors.redAccent : Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Switch(
            value: isActive,
            onChanged: onChanged,
            activeThumbColor: Colors.redAccent,
            inactiveTrackColor: Colors.white10,
          ),
        ],
      ),
    );
  }

  void _toggleMaintenance({bool? chat, bool? shop, bool? sync}) {
    Provider.of<AdminProvider>(context, listen: false).updateMaintenance(
      chat: chat,
      shop: shop,
      sync: sync,
    );
  }
}
