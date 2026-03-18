import 'package:flutter/material.dart';
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

class SuspectCase {
  final String senderId;
  final List<dynamic> reports;
  Map<String, dynamic>? profile;

  SuspectCase({required this.senderId, required this.reports, this.profile});
}

class _ReportsScreenState extends State<ReportsScreen> {
  final AdminService _adminService = AdminService();
  List<SuspectCase> _cases = [];
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

    final Map<String, List<dynamic>> grouped = {};
    for (var r in results) {
      final sid = r['senderId'] ?? 'Unknown';
      grouped.putIfAbsent(sid, () => []).add(r);
    }

    final casesList = grouped.entries
        .map((e) => SuspectCase(senderId: e.key, reports: e.value))
        .toList();

    setState(() {
      _cases = casesList;
      _isLoading = false;
    });

    for (var c in casesList) {
      if (c.senderId != 'Unknown') {
        _adminService.getUserProfile(c.senderId).then((p) {
          if (mounted) {
            setState(() {
              c.profile = p;
            });
          }
        });
      }
    }
  }

  Future<void> _takeAction(SuspectCase c) async {
    final uid = c.senderId;
    if (uid == 'Unknown') return;

    // PR FIX: Fetch fresh profile before opening dialog to ensure status is current
    showCustomSnackBar(context, 'Fetching latest suspect status...', type: SnackBarType.info);
    final freshProfile = await _adminService.getUserProfile(uid);
    if (!mounted) return;

    final result = await showDialog<String>(
      context: context,
      builder: (context) => PlayerActionsDialog(
        player: freshProfile ?? c.profile ?? {'uid': uid, 'displayName': 'Suspect'},
        onActionComplete: _fetchReports,
      ),
    );

    if (result != null && mounted) {
      // Re-fetch reports to update local state if status changed
      _fetchReports();
      _showArchiveAndEmailChoice(c, result);
    }
  }

  void _showArchiveAndEmailChoice(SuspectCase c, String actionTaken) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Center(
        child: LiquidGlassDialog(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: Colors.greenAccent, size: 60),
              const SizedBox(height: 16),
              const Text('Action Applied', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              const Text(
                'Would you like to archive ALL reports for this suspect and notify the primary reporter?',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Maybe Later'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        for (var r in c.reports) {
                          _archiveReport(r['id']);
                        }
                        if (c.reports.isNotEmpty && c.reports.first['reporterEmail'] != null) {
                          _showEmailNotificationDialog(c.reports.first, actionTaken);
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
  }

  void _showEmailNotificationDialog(Map<String, dynamic> r, String actionTaken,
      {bool isAlreadyRestricted = false}) {
    final ticketId = r['id'].toString().substring(0, 8).toUpperCase();
    final reporterEmail = r['reporterEmail'] ?? 'N/A';
    final suspectId = r['senderId'] ?? 'Unknown';
    final date = DateFormat('MMM d, yyyy').format(DateTime.now());

    final subject = 'Update on your report #$ticketId - DreamHunter Support';

    String content;
    if (isAlreadyRestricted) {
      content = '''
Hello,

This is an update regarding your report submitted on DreamHunter.

Ticket ID: #$ticketId
Date: $date

Our records show that administrative action has already been taken on the reported individual ($suspectId) due to multiple recent violations. The user is currently restricted from platform access.

Thank you for your vigilance in helping us keep the community safe!

Best regards,
DreamHunter Moderation Team
''';
    } else {
      // PR FIX: Map return values to readable text
      String actionLabel = actionTaken.toUpperCase();
      if (actionTaken == 'unban') actionLabel = 'UNBANNED';
      if (actionTaken == 'unmute') actionLabel = 'RESTRICTIONS REMOVED';

      content = '''
Hello,

This is an update regarding your report submitted on DreamHunter.

Ticket ID: #$ticketId
Date: $date

We have investigated the message reported and have taken the following action:
Action: $actionLabel applied to user $suspectId.

Thank you for helping us keep DreamHunter safe!

Best regards,
DreamHunter Moderation Team
''';
    }

    showDialog(
      context: context,
      builder: (dialogContext) => Center(
        child: LiquidGlassDialog(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Notify Reporter',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('To: $reporterEmail',
                  style: const TextStyle(color: Colors.amberAccent)),
              const Divider(color: Colors.white24, height: 24),
              const Text('Subject:',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Colors.white54)),
              Text(subject, style: const TextStyle(fontSize: 14)),
              const SizedBox(height: 12),
              const Text('Content:',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Colors.white54)),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(8)),
                  child: SingleChildScrollView(
                      child: Text(content,
                          style: const TextStyle(fontSize: 13, height: 1.4))),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => copyToClipboardWithFeedback(
                          context, subject, 'Subject'),
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('Subject'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => copyToClipboardWithFeedback(
                          context, content, 'Content'),
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
                    copyToClipboardWithFeedback(
                        context, 'Subject: $subject\n\n$content', 'Full Email');
                    Navigator.pop(dialogContext);
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

  void _showCaseInvestigation(SuspectCase c) {
    final profile = c.profile;
    final isRestricted =
        (profile?['isBanned'] ?? false) || (profile?['mutedUntil'] != null);

    // Grouping by reporter to provide individual outreach buttons
    final Map<String, Map<String, dynamic>> reporters = {};
    for (var r in c.reports) {
      final rid = r['reporterEmail'] ?? r['reporterId'] ?? 'Anonymous';
      reporters[rid] = r; // Map email/id to the specific report object
    }

    final screenWidth = MediaQuery.of(context).size.width;

    showDialog(
      context: context,
      builder: (dialogContext) => Center(
        child: LiquidGlassDialog(
          width: screenWidth > 600 ? 500 : screenWidth * 0.85,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Case Investigation',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    IconButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: const Icon(Icons.close)),
                  ],
                ),
                const Divider(color: Colors.white24, height: 32),

                _detailSection('Suspect Overview', [
                  _detailRow('Display Name', profile?['displayName'] ?? 'Loading...',
                      isBoldValue: true),
                  _detailRow('User ID', c.senderId, showCopy: true),
                  _detailRow('Total Reports', c.reports.length.toString()),
                  const SizedBox(height: 12),
                  _buildSuspectStatusSummary(profile),
                ]),

                const SizedBox(height: 24),
                _detailSection('Involved Reporters', [
                  for (var rid in reporters.keys)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(rid,
                                style: const TextStyle(fontSize: 13),
                                overflow: TextOverflow.ellipsis),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            height: 28,
                            child: ElevatedButton(
                              onPressed: () => _showEmailNotificationDialog(
                                  reporters[rid]!, 'manual'),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blueAccent,
                                  padding: const EdgeInsets.symmetric(horizontal: 12)),
                              child: const Text('NOTIFY',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ),
                ]),

                const SizedBox(height: 24),
                _detailSection('Flagged Evidence', [
                  for (var r in c.reports)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(8)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('"${r['originalMessageText'] ?? ''}"',
                              style: const TextStyle(
                                  fontStyle: FontStyle.italic, fontSize: 13)),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                  DateFormat('MMM d, h:mm a')
                                      .format(DateTime.parse(r['reportTimestamp'])),
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.white54)),
                              _miniStatusBadge(r['status'] ?? 'pending'),
                            ],
                          ),
                        ],
                      ),
                    ),
                ]),

                const SizedBox(height: 32),
                const Text('Administrative Actions',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.amberAccent,
                        fontSize: 14)),
                const SizedBox(height: 16),

                if (isRestricted)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          // Allow admin to pick which reporter to notify about restriction
                          showDialog(
                            context: context,
                            builder: (ctx) => Center(
                              child: LiquidGlassDialog(
                                width: 350,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('Notify of Restriction',
                                        style: TextStyle(fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 16),
                                    for (var r in c.reports)
                                      ListTile(
                                        title: Text(r['reporterEmail'] ?? 'Unknown',
                                            style: const TextStyle(fontSize: 12)),
                                        onTap: () {
                                          Navigator.pop(ctx);
                                          _showEmailNotificationDialog(
                                              r, 'RESTRICTED',
                                              isAlreadyRestricted: true);
                                        },
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.notification_important),
                        label: const Text('NOTIFY REPORTER: ALREADY RESTRICTED'),
                        style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.orangeAccent,
                            side: const BorderSide(color: Colors.orangeAccent)),
                      ),
                    ),
                  ),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(dialogContext);
                      _takeAction(c);
                    },
                    icon: const Icon(Icons.gavel),
                    label: const Text('OPEN MODERATION PANEL'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _miniStatusBadge(String status) {
    return Text(status.toUpperCase(),
        style: const TextStyle(
            fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white38));
  }

  Widget _buildSuspectStatusSummary(Map<String, dynamic>? profile) {
    if (profile == null) return const LinearProgressIndicator();
    final isBanned = profile['isBanned'] ?? false;
    final isMuted = profile['mutedUntil'] != null;
    if (!isBanned && !isMuted) {
      return const Text('Status: Active/Clean',
          style: TextStyle(color: Colors.greenAccent, fontSize: 12));
    }
    return Column(
      children: [
        if (isBanned)
          _statusAlert('Banned', 'Until: ${profile['bannedUntil'] ?? 'Forever'}',
              Colors.redAccent, Icons.block),
        if (isMuted)
          _statusAlert('Muted', 'Until: ${profile['mutedUntil']}',
              Colors.orangeAccent, Icons.volume_off),
      ],
    );
  }

  Widget _statusAlert(String title, String details, Color color, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.2))),
      child: Row(children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 8),
        Expanded(
            child: Text('$title - $details',
                style: TextStyle(color: color, fontSize: 11))),
      ]),
    );
  }

  Widget _detailSection(String title, List<Widget> children) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title.toUpperCase(),
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.amberAccent,
              letterSpacing: 1.2)),
      const SizedBox(height: 12),
      ...children,
    ]);
  }

  Widget _detailRow(String label, String value,
      {bool isItalic = false, bool showCopy = false, bool isBoldValue = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 100,
              child: Text('$label:',
                  style: const TextStyle(color: Colors.white54, fontSize: 13))),
          Expanded(
              child: Text(value,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          isBoldValue ? FontWeight.bold : FontWeight.normal,
                      fontStyle:
                          isItalic ? FontStyle.italic : FontStyle.normal))),
          if (showCopy)
            GestureDetector(
                onTap: () =>
                    copyToClipboardWithFeedback(context, value, label),
                child:
                    const Icon(Icons.copy, size: 14, color: Colors.blueAccent)),
        ],
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
              const Text('Report Center',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              IconButton(
                  icon: const Icon(Icons.refresh, size: 28, color: Colors.amberAccent),
                  onPressed: _fetchReports),
            ],
          ),
          const SizedBox(height: 16),
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
                  label: const Text('Refresh')),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _cases.isEmpty
                    ? const Center(child: Text('No reports found.'))
                    : ListView.builder(
                        itemCount: _cases.length,
                        itemBuilder: (context, index) {
                          final c = _cases[index];
                          final latestReport = c.reports.first;
                          final profile = c.profile;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: GestureDetector(
                              onTap: () => _showCaseInvestigation(c),
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
                                            profile?['displayName'] ??
                                                'Loading Suspect...',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 18),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                              color: Colors.redAccent
                                                  .withValues(alpha: 0.2),
                                              borderRadius:
                                                  BorderRadius.circular(12)),
                                          child: Text('${c.reports.length} Reports',
                                              style: const TextStyle(
                                                  color: Colors.redAccent,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text('UID: ${c.senderId}',
                                        style: const TextStyle(
                                            color: Colors.white38, fontSize: 11)),
                                    const SizedBox(height: 12),
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                          color: Colors.black26,
                                          borderRadius: BorderRadius.circular(4)),
                                      child: Text(
                                        'Latest: "${latestReport['originalMessageText'] ?? ''}"',
                                        style: const TextStyle(
                                            fontStyle: FontStyle.italic,
                                            fontSize: 13),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                            'Last reported: ${DateFormat('MMM d, h:mm a').format(DateTime.parse(latestReport['reportTimestamp']))}',
                                            style: const TextStyle(
                                                color: Colors.white54,
                                                fontSize: 11)),
                                        const Icon(Icons.arrow_forward_ios,
                                            size: 14, color: Colors.white24),
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
