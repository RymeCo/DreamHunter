import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/admin_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final AdminService _adminService = AdminService();
  List<dynamic> _reports = [];
  bool _isLoading = false;
  String _filterStatus = 'pending';

  @override
  void initState() {
    super.initState();
    _fetchReports();
  }

  Future<void> _fetchReports() async {
    setState(() => _isLoading = true);
    final results = await _adminService.getReports(_filterStatus == 'all' ? null : _filterStatus);
    if (!mounted) return;
    setState(() {
      _reports = results;
      _isLoading = false;
    });
  }

  void _updateStatus(String reportId, String newStatus) async {
    final success = await _adminService.updateReportStatus(reportId, newStatus);
    if (success) {
      _fetchReports();
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update status'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Report Center', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        
        // Filters
        Row(
          children: [
            DropdownButton<String>(
              value: _filterStatus,
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All Reports')),
                DropdownMenuItem(value: 'pending', child: Text('Pending')),
                DropdownMenuItem(value: 'working', child: Text('Working On')),
                DropdownMenuItem(value: 'resolved', child: Text('Resolved')),
                DropdownMenuItem(value: 'archived', child: Text('Archived')),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() => _filterStatus = val);
                  _fetchReports();
                }
              },
            ),
            const SizedBox(width: 16),
            ElevatedButton.icon(
              onPressed: _fetchReports,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Reports List
        Expanded(
          child: _isLoading 
            ? const Center(child: CircularProgressIndicator())
            : _reports.isEmpty 
              ? const Center(child: Text('No reports found.'))
              : ListView.builder(
                  itemCount: _reports.length,
                  itemBuilder: (context, index) {
                    final r = _reports[index];
                    final dateStr = r['reportTimestamp'] ?? '';
                    String formattedDate = dateStr;
                    try {
                      final dt = DateTime.parse(dateStr).toLocal();
                      formattedDate = DateFormat('MMM d, yyyy - h:mm a').format(dt);
                    } catch (_) {}

                    return Card(
                      color: const Color(0xFF1E1E36),
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Reporter: ${r['reporterEmail'] ?? r['reporterId'] ?? 'Unknown'}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                Text(formattedDate, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text('Reported User ID: ${r['senderId'] ?? 'Unknown'}', style: const TextStyle(color: Colors.orangeAccent)),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(4)),
                              child: Text('Message: "${r['originalMessageText'] ?? ''}"', style: const TextStyle(fontStyle: FontStyle.italic)),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              children: (r['categories'] as List<dynamic>? ?? []).map((c) {
                                return Chip(
                                  label: Text(c.toString(), style: const TextStyle(fontSize: 10)),
                                  backgroundColor: Colors.redAccent.withValues(alpha: 0.2),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                const Text('Status: ', style: TextStyle(color: Colors.white54)),
                                DropdownButton<String>(
                                  value: r['status'] ?? 'pending',
                                  underline: const SizedBox(),
                                  items: const [
                                    DropdownMenuItem(value: 'pending', child: Text('Pending', style: TextStyle(color: Colors.redAccent))),
                                    DropdownMenuItem(value: 'working', child: Text('Working', style: TextStyle(color: Colors.orangeAccent))),
                                    DropdownMenuItem(value: 'resolved', child: Text('Resolved', style: TextStyle(color: Colors.greenAccent))),
                                    DropdownMenuItem(value: 'archived', child: Text('Archived', style: TextStyle(color: Colors.grey))),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) _updateStatus(r['id'], val);
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
