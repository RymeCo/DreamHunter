import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dreamhunter/widgets/custom_snackbar.dart';
import 'package:dreamhunter/widgets/game_widgets.dart';
import 'package:dreamhunter/widgets/clickable_image.dart';

class ReportDialog extends StatefulWidget {
  final String messageId;
  final String originalMessageText;
  final String senderId;
  final String senderDevice;
  final String messageTimestamp;

  const ReportDialog({
    super.key,
    required this.messageId,
    required this.originalMessageText,
    required this.senderId,
    required this.senderDevice,
    required this.messageTimestamp,
  });

  @override
  State<ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<ReportDialog> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _otherReasonController = TextEditingController();
  
  final Map<String, bool> _categories = {
    'Harassment': false,
    'Hate Speech': false,
    'Spam': false,
    'Inappropriate Language': false,
    'Sexual Content': false,
    'Violence': false,
    'Scam/Fraud': false,
    'Other': false,
  };

  bool _isSubmitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _otherReasonController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Auto-fill email if user is logged in
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.email != null) {
      _emailController.text = user.email!;
    }
  }

  void _submitReport() async {
    final selectedCategories = _categories.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();

    if (selectedCategories.isEmpty) {
      showCustomSnackBar(context, 'Please select at least one reason.', type: SnackBarType.error);
      return;
    }

    if (_categories['Other']! && _otherReasonController.text.trim().isEmpty) {
      showCustomSnackBar(context, 'Please specify your "Other" reason.', type: SnackBarType.error);
      return;
    }

    setState(() => _isSubmitting = true);

    // Artificial delay for UI feel
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    Navigator.pop(context);
    showCustomSnackBar(context, 'Report submitted successfully. Thank you.', type: SnackBarType.success);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const GameDialogHeader(
            title: 'Report Message',
            titleColor: Colors.redAccent,
          ),
          const SizedBox(height: 10),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Text(
                      '"${widget.originalMessageText}"',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontStyle: FontStyle.italic,
                        fontSize: 14,
                      ),
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'REASONS:',
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: _categories.keys.map((String key) {
                      final isSelected = _categories[key]!;
                      return FilterChip(
                        label: Text(
                          key,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: Colors.redAccent.withValues(alpha: 0.6),
                        backgroundColor: Colors.white.withValues(alpha: 0.05),
                        checkmarkColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        onSelected: (bool value) {
                          setState(() {
                            _categories[key] = value;
                          });
                        },
                      );
                    }).toList(),
                  ),
                  if (_categories['Other']!) ...[
                    const SizedBox(height: 15),
                    TextField(
                      controller: _otherReasonController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.05),
                        hintText: 'Please specify other reason...',
                        hintStyle: const TextStyle(color: Colors.white38),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.white10),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.white10),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  const Text(
                    'EMAIL (OPTIONAL):',
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _emailController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      hintText: 'your@email.com',
                      hintStyle: const TextStyle(color: Colors.white38),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.white10),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.white10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  Center(
                    child: GlassButton(
                      onTap: _isSubmitting ? null : _submitReport,
                      glowColor: Colors.redAccent,
                      width: 200,
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'SUBMIT REPORT',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
