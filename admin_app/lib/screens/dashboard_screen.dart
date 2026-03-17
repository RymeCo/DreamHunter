import 'package:flutter/material.dart';
import '../services/admin_service.dart';

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

  @override
  void initState() {
    super.initState();
    _pingServer();
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
      _pingStatus = latency != null ? 'Online (${latency}ms)' : 'Offline/Timeout';
    });
  }

  void _sendBroadcast() async {
    if (_broadcastController.text.trim().isEmpty) return;
    final success = await _adminService.sendGlobalBroadcast(_broadcastController.text.trim(), false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(success ? 'Broadcast sent!' : 'Failed to send broadcast.'),
      backgroundColor: success ? Colors.green : Colors.red,
    ));
    if (success) {
      _broadcastController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Dashboard Overview', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          
          // Service Health
          Card(
            color: const Color(0xFF1E1E36),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Service Health', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 20,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _isPinging ? null : _pingServer,
                        icon: _isPinging ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.network_ping),
                        label: const Text('Ping Backend'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                      ),
                      Text(
                        'Status: $_pingStatus', 
                        style: TextStyle(
                          color: _pingStatus.contains('Online') ? Colors.greenAccent : Colors.redAccent, 
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Maintenance Controls
          Card(
            color: const Color(0xFF1E1E36),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Maintenance Controls', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  StreamBuilder(
                    stream: _adminService.getSystemConfig(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const CircularProgressIndicator();
                      final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
                      final chatMaint = data['chatMaintenance'] ?? false;
                      final shopMaint = data['shopMaintenance'] ?? false;

                      return Column(
                        children: [
                          SwitchListTile(
                            title: const Text('Chat Maintenance Mode'),
                            subtitle: const Text('Disables the global chat for all players.'),
                            value: chatMaint,
                            onChanged: (val) => _adminService.updateMaintenance(val, null),
                            activeThumbColor: Colors.orangeAccent,
                          ),
                          SwitchListTile(
                            title: const Text('Shop Maintenance Mode'),
                            subtitle: const Text('Disables the shop interface.'),
                            value: shopMaint,
                            onChanged: (val) => _adminService.updateMaintenance(null, val),
                            activeThumbColor: Colors.orangeAccent,
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Emergency Broadcast
          Card(
            color: const Color(0xFF1E1E36),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Emergency Broadcast', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.redAccent)),
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
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
