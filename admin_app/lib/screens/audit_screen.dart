import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/admin_service.dart';
import '../widgets/admin_ui_components.dart';

class AuditScreen extends StatefulWidget {
  const AuditScreen({super.key});

  @override
  State<AuditScreen> createState() => _AuditScreenState();
}

class _AuditScreenState extends State<AuditScreen> {
  final AdminService _adminService = AdminService();
  String _selectedAction = 'ALL';
  final List<String> _actionTypes = [
    'ALL',
    'USER_BANNED',
    'USER_UNBANNED',
    'USER_MUTED',
    'USER_UNMUTED',
    'USER_WARNED',
    'MODERATOR_ROLE_UPDATE',
    'GLOBAL_BROADCAST',
    'MAINTENANCE_TOGGLE'
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AdminHeader(
          title: 'System Audit Logs',
          actions: [
            _buildActionFilter(),
          ],
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _buildAuditList(),
          ),
        ),
      ],
    );
  }

  Widget _buildActionFilter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F1E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2A2A4A)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedAction,
          dropdownColor: const Color(0xFF1E1E3A),
          items: _actionTypes
              .map((type) => DropdownMenuItem(
                  value: type,
                  child: Text(type.replaceAll('_', ' '),
                      style: const TextStyle(
                          fontSize: 10, fontWeight: FontWeight.bold))))
              .toList(),
          onChanged: (val) {
            if (val != null) setState(() => _selectedAction = val);
          },
        ),
      ),
    );
  }

  Widget _buildAuditList() {
    return FutureBuilder<List<dynamic>>(
      future: _adminService.getAuditLogs(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final allLogs = snapshot.data ?? [];
        final filteredLogs = _selectedAction == 'ALL'
            ? allLogs
            : allLogs.where((log) => log['action'] == _selectedAction).toList();

        if (filteredLogs.isEmpty) {
          return const Center(
              child: Text('No audit logs found.',
                  style: TextStyle(color: Colors.white12)));
        }

        return ListView.builder(
          itemCount: filteredLogs.length,
          padding: const EdgeInsets.only(bottom: 24),
          itemBuilder: (context, index) {
            final data = filteredLogs[index] as Map<String, dynamic>;
            return _auditItem(data);
          },
        );
      },
    );
  }

  Widget _auditItem(Map<String, dynamic> data) {
    DateTime timestamp = DateTime.now();
    if (data['timestamp'] != null) {
      if (data['timestamp'] is String) {
        timestamp = DateTime.tryParse(data['timestamp']) ?? DateTime.now();
      } else if (data['timestamp'] is Timestamp) {
        timestamp = (data['timestamp'] as Timestamp).toDate();
      }
    }

    final dateStr = DateFormat('MMM d, HH:mm:ss').format(timestamp);
    final action = data['action'] ?? 'UNKNOWN';
    final adminEmail = data['adminEmail'] ?? 'System';
    final targetName = data['targetName'] ?? 'Global';
    final details = data['details'] ?? 'No extra details';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AdminCard(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 40,
              decoration: BoxDecoration(
                color: _getActionColor(action),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        action.replaceAll('_', ' '),
                        style: TextStyle(
                          color: _getActionColor(action),
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const Spacer(),
                      Text(dateStr,
                          style: const TextStyle(
                              color: Colors.white24, fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    children: [
                      Text(adminEmail,
                          style: const TextStyle(
                              color: Colors.amberAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                      const Text('->',
                          style: TextStyle(color: Colors.white38, fontSize: 13)),
                      Text(targetName,
                          style: const TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    details,
                    style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                        fontStyle: FontStyle.italic),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getActionColor(String action) {
    if (action.contains('BAN')) return Colors.redAccent;
    if (action.contains('MUTE')) return Colors.orangeAccent;
    if (action.contains('UNBAN')) return Colors.greenAccent;
    if (action.contains('UNMUTE')) return Colors.blueAccent;
    if (action.contains('WARN')) return Colors.yellowAccent;
    if (action.contains('BROADCAST')) return Colors.purpleAccent;
    if (action.contains('ROLE')) return Colors.cyanAccent;
    return Colors.white24;
  }
}
