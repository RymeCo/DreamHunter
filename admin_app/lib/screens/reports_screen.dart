import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../services/admin_service.dart';
import '../widgets/custom_snackbar.dart';
import '../widgets/liquid_glass_dialog.dart';
import '../widgets/player_actions_dialog.dart';

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
    final results = await _adminService.getReports(
      _filterStatus == 'all' ? null : _filterStatus,
    );
    if (!mounted) return;
    setState(() {
      _reports = results;
      _isLoading = false;
    });
  }

  void _updateStatus(String reportId, String newStatus) async {
    final success = await _adminService.updateReportStatus(reportId, newStatus);
    if (!mounted) return;

    if (success) {
      showCustomSnackBar(
        context,
        'Status updated!',
        type: SnackBarType.success,
      );
      _fetchReports();
    } else {
      showCustomSnackBar(
        context,
        'Failed to update status',
        type: SnackBarType.error,
      );
    }
  }

  Future<void> _takeAction(Map<String, dynamic> r) async {
    final uid = r['senderId'];
    if (uid == null) return;

    // Use the player actions dialog
    final result = await showDialog<String>(
      context: context,
      builder: (context) => PlayerActionsDialog(
        player: {
          'uid': uid,
          'displayName': 'Reported User', // Backend will fetch real name if needed in dialog
        },
      ),
    );

    if (result != null && mounted) {
      _showArchiveAndEmailChoice(r, result);
    }
  }

  void _showArchiveAndEmailChoice(Map<String, dynamic> r, String actionTaken) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: LiquidGlassDialog(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: Colors.greenAccent, size: 60),
              const SizedBox(height: 16),
              const Text(
                'Action Applied',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'Would you like to archive this report and notify the reporter?',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Maybe Later'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _archiveReport(r['id']);
                        if (r['reporterEmail'] != null) {
                          _showEmailNotificationDialog(r, actionTaken);
                        }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                      child: const Text('Archive & Notify'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _archiveReport(String? reportId) async {
    if (reportId == null) return;
    await _adminService.updateReportStatus(reportId, 'archived');
    _fetchReports();
  }

  void _showEmailNotificationDialog(Map<String, dynamic> r, String actionTaken) {
    final ticketId = r['id'].toString().substring(0, 8).toUpperCase();
    final reporterEmail = r['reporterEmail'] ?? 'N/A';
    final suspectId = r['senderId'] ?? 'Unknown';
    final date = DateFormat('MMM d, yyyy').format(DateTime.now());
    
    final subject = 'Update on your report #$ticketId - DreamHunter Support';
    final content = '''
Hello,

This is an automated update regarding your report submitted on DreamHunter.

Ticket ID: #$ticketId
Date: $date

We have investigated the message reported and have taken the following action:
Action: ${actionTaken.toUpperCase()} applied to user $suspectId.

Thank you for helping us keep DreamHunter safe!

Best regards,
DreamHunter Moderation Team
''';

    showDialog(
      context: context,
      builder: (context) => Center(
        child: LiquidGlassDialog(
          width: 450,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Notify Reporter', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('To: $reporterEmail', style: const TextStyle(color: Colors.amberAccent)),
              const Divider(color: Colors.white24, height: 24),
              
              const Text('Subject:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white54)),
              Text(subject, style: const TextStyle(fontSize: 14)),
              const SizedBox(height: 12),
              
              const Text('Content:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white54)),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)),
                  child: SingleChildScrollView(child: Text(content, style: const TextStyle(fontSize: 13, height: 1.4))),
                ),
              ),
              const SizedBox(height: 20),
              
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: subject));
                        showCustomSnackBar(context, 'Subject copied!', type: SnackBarType.info);
                      },
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('Subject'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: content));
                        showCustomSnackBar(context, 'Content copied!', type: SnackBarType.info);
                      },
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('Content'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    // In real app would use url_launcher to open mailto:
                    showCustomSnackBar(context, 'Mail details copied! Open your email app.', type: SnackBarType.info);
                    Clipboard.setData(ClipboardData(text: 'Subject: $subject\n\n$content'));
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.mail),
                  label: const Text('COPY FULL EMAIL'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showReportDetails(Map<String, dynamic> r) {
    final reportTimestamp = r['reportTimestamp'] ?? '';
    final messageTimestamp = r['messageTimestamp'] ?? '';
    final senderId = r['senderId'] ?? '';

    String formattedReportDate = reportTimestamp;
    String formattedMsgDate = messageTimestamp;

    try {
      final dt = DateTime.parse(reportTimestamp).toLocal();
      formattedReportDate = DateFormat('MMMM d, yyyy - h:mm:ss a').format(dt);
    } catch (_) {}

    try {
      final dt = DateTime.parse(messageTimestamp).toLocal();
      formattedMsgDate = DateFormat('MMMM d, yyyy - h:mm:ss a').format(dt);
    } catch (_) {}

    showDialog(
      context: context,
      builder: (dialogContext) => Center(
        child: LiquidGlassDialog(
          width: 550,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          child: FutureBuilder<Map<String, dynamic>?>(
            future: _adminService.getUserProfile(senderId),
            builder: (context, snapshot) {
              final profile = snapshot.data;
              final isLoadingProfile =
                  snapshot.connectionState == ConnectionState.waiting;

              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Investigation Log',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white24, height: 32),

                    // SECTION 1: EVIDENCE
                    _detailSection('Evidence: Flagged Message', [
                      _detailRow('Content', '"${r['originalMessageText'] ?? ''}"',
                          isItalic: true),
                      const SizedBox(height: 12),
                      _detailRow('Message ID', r['reportedMessageId'] ?? 'N/A',
                          showCopy: true),
                      _detailRow('Sent At', formattedMsgDate),
                    ]),
                    const SizedBox(height: 24),

                    // SECTION 2: SUSPECT
                    _detailSection('Suspect Profile', [
                      if (isLoadingProfile)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: LinearProgressIndicator(
                            backgroundColor: Colors.white10,
                            color: Colors.orangeAccent,
                          ),
                        )
                      else ...[
                        _detailRow('Display Name',
                            profile?['displayName'] ?? 'Unknown',
                            isBoldValue: true),
                        _detailRow('Email', profile?['email'] ?? 'No Email'),
                        _detailRow('User ID', senderId, showCopy: true),
                        _detailRow('Hardware ID', r['senderDevice'] ?? 'N/A'),
                        const SizedBox(height: 16),
                        _buildSuspectStatusSummary(profile),
                      ],
                    ]),
                    const SizedBox(height: 24),

                    // SECTION 3: REPORTER
                    _detailSection('Report Context', [
                      _detailRow('Reported At', formattedReportDate),
                      _detailRow('Reporter ID', r['reporterId'] ?? 'N/A',
                          showCopy: true),
                      _detailRow('Reporter Email',
                          r['reporterEmail'] ?? 'Not provided'),
                    ]),
                    const SizedBox(height: 24),

                    const Text(
                      'Violations',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.redAccent,
                        fontSize: 14,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          (r['categories'] as List<dynamic>? ?? []).map((c) {
                        return Chip(
                          label: Text(c.toString(),
                              style: const TextStyle(fontSize: 11)),
                          backgroundColor:
                              Colors.redAccent.withValues(alpha: 0.15),
                          side: BorderSide(
                              color: Colors.redAccent.withValues(alpha: 0.3)),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 32),
                    const Divider(color: Colors.white24, height: 1),
                    const SizedBox(height: 24),

                    const Text(
                      'Administrative Actions',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.amberAccent,
                        fontSize: 14,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(dialogContext);
                          _takeAction(r);
                        },
                        icon: const Icon(Icons.gavel, size: 18),
                        label: const Text('MANAGE PLAYER ACCESS'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Current Status:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white54,
                          ),
                        ),
                        _buildStatusBadge(r['status'] ?? 'pending'),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSuspectStatusSummary(Map<String, dynamic>? profile) {
    if (profile == null) return const SizedBox();

    final isBanned = profile['isBanned'] ?? false;
    final isMuted = profile['mutedUntil'] != null;

    if (!isBanned && !isMuted) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.greenAccent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.2)),
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 18),
            SizedBox(width: 8),
            Text(
              'No active restrictions on this account.',
              style: TextStyle(color: Colors.greenAccent, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        if (isBanned)
          _statusAlert(
            'Currently Banned',
            'Banned until: ${profile['bannedUntil'] ?? 'Forever'}',
            Colors.redAccent,
            Icons.block,
          ),
        if (isMuted)
          _statusAlert(
            'Currently Muted',
            'Muted until: ${profile['mutedUntil']}',
            Colors.orangeAccent,
            Icons.volume_off,
          ),
      ],
    );
  }

  Widget _statusAlert(String title, String details, Color color, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                      color: color, fontSize: 13, fontWeight: FontWeight.bold),
                ),
                Text(
                  details,
                  style: TextStyle(
                      color: color.withValues(alpha: 0.7), fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.amberAccent,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _detailRow(String label, String value,
      {bool isItalic = false, bool showCopy = false, bool isBoldValue = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              '$label:',
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isBoldValue ? FontWeight.bold : FontWeight.normal,
                fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
              ),
            ),
          ),
          if (showCopy)
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: value));
                showCustomSnackBar(context, '$label copied!',
                    type: SnackBarType.info);
              },
              child: const Icon(Icons.copy, size: 14, color: Colors.blueAccent),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status) {
      case 'working':
        color = Colors.orangeAccent;
        break;
      case 'resolved':
        color = Colors.greenAccent;
        break;
      case 'archived':
        color = Colors.grey;
        break;
      default:
        color = Colors.redAccent;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 11,
            letterSpacing: 0.8),
      ),
    );
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
              const Text(
                'Report Center',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(
                  Icons.refresh,
                  size: 28,
                  color: Colors.amberAccent,
                ),
                onPressed: _fetchReports,
                tooltip: 'Refresh Reports',
              ),
            ],
          ),
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
                        formattedDate = DateFormat(
                          'MMM d, yyyy - h:mm a',
                        ).format(dt);
                      } catch (_) {}

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: GestureDetector(
                          onTap: () => _showReportDetails(r),
                          child: LiquidGlassDialog(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Reporter: ${r['reporterEmail'] ?? r['reporterId'] ?? 'Unknown'}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      formattedDate,
                                      style: const TextStyle(
                                        color: Colors.white54,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Reported User ID: ${r['senderId'] ?? 'Unknown'}',
                                  style: const TextStyle(
                                    color: Colors.orangeAccent,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.black26,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Message: "${r['originalMessageText'] ?? ''}"',
                                    style: const TextStyle(
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6,
                                  children:
                                      (r['categories'] as List<dynamic>? ?? [])
                                          .map((c) {
                                            return Chip(
                                              label: Text(
                                                c.toString(),
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                ),
                                              ),
                                              backgroundColor: Colors.redAccent
                                                  .withValues(alpha: 0.2),
                                            );
                                          })
                                          .toList(),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    const Text(
                                      'Status: ',
                                      style: TextStyle(color: Colors.white54),
                                    ),
                                    DropdownButton<String>(
                                      value: r['status'] ?? 'pending',
                                      underline: const SizedBox(),
                                      items: const [
                                        DropdownMenuItem(
                                          value: 'pending',
                                          child: Text(
                                            'Pending',
                                            style: TextStyle(
                                              color: Colors.redAccent,
                                            ),
                                          ),
                                        ),
                                        DropdownMenuItem(
                                          value: 'working',
                                          child: Text(
                                            'Working',
                                            style: TextStyle(
                                              color: Colors.orangeAccent,
                                            ),
                                          ),
                                        ),
                                        DropdownMenuItem(
                                          value: 'resolved',
                                          child: Text(
                                            'Resolved',
                                            style: TextStyle(
                                              color: Colors.greenAccent,
                                            ),
                                          ),
                                        ),
                                        DropdownMenuItem(
                                          value: 'archived',
                                          child: Text(
                                            'Archived',
                                            style: TextStyle(color: Colors.grey),
                                          ),
                                        ),
                                      ],
                                      onChanged: (val) {
                                        if (val != null) {
                                          _updateStatus(r['id'], val);
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
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
}
