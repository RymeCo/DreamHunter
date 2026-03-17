import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/admin_service.dart';

class AuditScreen extends StatefulWidget {
  const AuditScreen({super.key});

  @override
  State<AuditScreen> createState() => _AuditScreenState();
}

class _AuditScreenState extends State<AuditScreen> {
  final AdminService _adminService = AdminService();
  List<dynamic> _logs = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchLogs();
  }

  Future<void> _fetchLogs() async {
    setState(() => _isLoading = true);
    final results = await _adminService.getAuditLogs();
    if (!mounted) return;
    setState(() {
      _logs = results;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Audit Logs', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            ElevatedButton.icon(
              onPressed: _fetchLogs,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh Logs'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _logs.isEmpty
                  ? const Center(child: Text('No audit logs found.'))
                  : ListView.builder(
                      itemCount: _logs.length,
                      itemBuilder: (context, index) {
                        final log = _logs[index];
                        final dateStr = log['timestamp'] ?? '';
                        String formattedDate = dateStr;
                        try {
                          final dt = DateTime.parse(dateStr).toLocal();
                          formattedDate = DateFormat('MMM d, yyyy - h:mm:ss a').format(dt);
                        } catch (_) {}

                        return Card(
                          color: const Color(0xFF1E1E36),
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: const Icon(Icons.history, color: Colors.blueAccent),
                            title: Text('${log['action']} - ${log['target'] ?? 'System'}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('Admin UID: ${log['adminUid']}\nDetails: ${log['details'] ?? 'None'}', style: const TextStyle(color: Colors.white70)),
                            trailing: Text(formattedDate, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                            isThreeLine: true,
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}
