import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/admin_service.dart';
import '../widgets/custom_snackbar.dart';
import '../widgets/player_actions_dialog.dart';
import '../widgets/admin_ui_components.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final AdminService _adminService = AdminService();
  List<dynamic> _reports = [];
  bool _isLoading = false;
  String _selectedStatus = 'PENDING';

  @override
  void initState() {
    super.initState();
    _fetchReports();
  }

  Future<void> _fetchReports() async {
    setState(() => _isLoading = true);
    try {
      final results = await _adminService.getReports(_selectedStatus);
      if (!mounted) return;
      setState(() {
        _reports = results;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      showCustomSnackBar(context, 'Failed to load reports.',
          type: SnackBarType.error);
    }
  }

  Future<void> _updateStatus(String reportId, String newStatus) async {
    final success = await _adminService.updateReportStatus(reportId, newStatus);
    if (success && mounted) {
      showCustomSnackBar(context, 'Report marked as $newStatus',
          type: SnackBarType.success);
      _fetchReports();
    }
  }

  void _investigateUser(String uid) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final profile = await _adminService.getUserProfile(uid);
    if (!mounted) return;
    Navigator.pop(context);

    if (profile != null) {
      showDialog(
        context: context,
        builder: (context) => PlayerActionsDialog(
          player: profile,
          onActionComplete: _fetchReports,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AdminHeader(
          title: 'Report Investigations',
          actions: [
            _buildStatusFilter(),
            IconButton(
              icon:
                  const Icon(Icons.refresh_rounded, color: Colors.amberAccent),
              onPressed: _fetchReports,
            ),
          ],
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _reports.isEmpty
                    ? const Center(child: Text('No reports matching status.', style: TextStyle(color: Colors.white24)))
                    : ListView.builder(
                        itemCount: _reports.length,
                        padding: const EdgeInsets.only(bottom: 24),
                        itemBuilder: (context, index) {
                          final r = _reports[index];
                          return _buildReportCard(r);
                        },
                      ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusFilter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F1E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2A2A4A)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedStatus,
          dropdownColor: const Color(0xFF1E1E3A),
          items: const [
            DropdownMenuItem(value: 'PENDING', child: Text('Pending')),
            DropdownMenuItem(value: 'WORKING', child: Text('In Progress')),
            DropdownMenuItem(value: 'RESOLVED', child: Text('Resolved')),
            DropdownMenuItem(value: 'ARCHIVED', child: Text('Archived')),
          ],
          onChanged: (val) {
            if (val != null) {
              setState(() => _selectedStatus = val);
              _fetchReports();
            }
          },
        ),
      ),
    );
  }

  Widget _buildReportCard(Map<String, dynamic> r) {
    final date = DateTime.tryParse(r['messageTimestamp'] ?? '')?.toLocal();
    final formattedDate =
        date != null ? DateFormat('MMM d, h:mm a').format(date) : 'Unknown';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: AdminCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _badge(r['categories']?.join(', ') ?? 'General',
                    Colors.orangeAccent),
                const Spacer(),
                Text(formattedDate,
                    style: const TextStyle(color: Colors.white38, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 16),
            const Text('FLAGGED MESSAGE',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: Colors.white24,
                    letterSpacing: 1)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F0F1E),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '"${r['originalMessageText'] ?? ''}"',
                style: const TextStyle(
                    fontStyle: FontStyle.italic, color: Colors.amberAccent),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 24,
              runSpacing: 16,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _infoColumn('SUSPECT UID', r['senderId'] ?? 'Unknown'),
                _infoColumn('REPORTER', r['reporterId'] ?? 'Guest'),
                if (_selectedStatus == 'PENDING')
                  AdminButton(
                    onPressed: () => _updateStatus(r['id'], 'WORKING'),
                    label: 'CLAIM CASE',
                    color: Colors.blueAccent,
                  ),
                AdminButton(
                  onPressed: () => _investigateUser(r['senderId']),
                  label: 'INVESTIGATE',
                  icon: Icons.search_rounded,
                ),
                if (_selectedStatus == 'WORKING')
                  AdminButton(
                    onPressed: () => _updateStatus(r['id'], 'RESOLVED'),
                    label: 'CLOSE CASE',
                    color: Colors.greenAccent,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.white24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 13, color: Colors.white70)),
      ],
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(text,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}
