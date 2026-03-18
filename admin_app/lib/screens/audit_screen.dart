import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/admin_service.dart';
import '../widgets/liquid_glass_dialog.dart';

class AuditScreen extends StatefulWidget {
  const AuditScreen({super.key});

  @override
  State<AuditScreen> createState() => _AuditScreenState();
}

class _AuditScreenState extends State<AuditScreen> {
  final AdminService _adminService = AdminService();
  List<dynamic> _allLogs = [];
  List<dynamic> _filteredLogs = [];
  bool _isLoading = false;
  String _searchQuery = '';
  String _selectedCategory = 'All';

  final List<String> _categories = [
    'All',
    'USER_BANNED',
    'USER_UNBANNED',
    'USER_MUTED',
    'USER_UNMUTED',
    'MAINTENANCE_TOGGLE',
    'GLOBAL_BROADCAST',
    'REPORT_STATUS_UPDATE',
    'AUTOMOD_CONFIG_UPDATE',
  ];

  @override
  void initState() {
    super.initState();
    _fetchLogs();
  }

  Future<void> _fetchLogs() async {
    setState(() => _isLoading = true);
    try {
      final results = await _adminService.getAuditLogs();
      if (!mounted) return;
      setState(() {
        _allLogs = results;
        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredLogs = _allLogs.where((log) {
        final action = log['action']?.toString() ?? '';
        final details = log['details']?.toString().toLowerCase() ?? '';
        final admin = log['adminEmail']?.toString().toLowerCase() ?? '';
        final target = log['target']?.toString().toLowerCase() ?? '';
        
        final matchesCategory = _selectedCategory == 'All' || action == _selectedCategory;
        final matchesSearch = _searchQuery.isEmpty || 
            details.contains(_searchQuery.toLowerCase()) ||
            admin.contains(_searchQuery.toLowerCase()) ||
            target.contains(_searchQuery.toLowerCase());
            
        return matchesCategory && matchesSearch;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Audit Logs', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.refresh, size: 28, color: Colors.amberAccent),
                onPressed: _fetchLogs,
                tooltip: 'Refresh Logs',
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Filters & Search
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'Search logs...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) {
                    _searchQuery = val;
                    _applyFilters();
                  },
                ),
              ),
              const SizedBox(width: 16),
              DropdownButton<String>(
                value: _selectedCategory,
                items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedCategory = val);
                    _applyFilters();
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 24),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredLogs.isEmpty
                    ? const Center(child: Text('No matching audit logs found.'))
                    : ListView.builder(
                        itemCount: _filteredLogs.length,
                        itemBuilder: (context, index) {
                          final log = _filteredLogs[index];
                          final dateStr = log['timestamp'] ?? '';
                          String formattedDate = dateStr;
                          try {
                            final dt = DateTime.parse(dateStr).toLocal();
                            formattedDate = DateFormat('MMM d, h:mm a').format(dt);
                          } catch (_) {}

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: LiquidGlassDialog(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      _buildActionBadge(log['action'] ?? 'UNKNOWN'),
                                      Text(formattedDate, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Admin: ${log['adminEmail'] ?? log['adminUid'] ?? 'System'}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent),
                                  ),
                                  if (log['target'] != null) ...[
                                    const SizedBox(height: 4),
                                    Text('Target: ${log['target']}', style: const TextStyle(color: Colors.orangeAccent, fontSize: 13)),
                                  ],
                                  const SizedBox(height: 8),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.black26,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      log['details'] ?? 'No details provided.',
                                      style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBadge(String action) {
    Color color;
    if (action.contains('BAN')) {
      color = Colors.redAccent;
    } else if (action.contains('MUTE')) {
      color = Colors.orangeAccent;
    } else if (action.contains('MAINTENANCE')) {
      color = Colors.blueAccent;
    } else if (action.contains('BROADCAST')) {
      color = Colors.purpleAccent;
    } else {
      color = Colors.greenAccent;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        action,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
