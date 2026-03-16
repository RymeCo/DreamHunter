import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dreamhunter/widgets/custom_snackbar.dart';
import 'package:dreamhunter/services/chat_service.dart';

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
  final ChatService _chatService = ChatService();
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

    // If 'Other' is selected, append the custom text to the category list for the backend to see
    final finalCategories = selectedCategories.map((c) {
      if (c == 'Other') {
        return 'Other: ${_otherReasonController.text.trim()}';
      }
      return c;
    }).toList();

    final success = await _chatService.reportMessage(
      messageId: widget.messageId,
      originalMessageText: widget.originalMessageText,
      senderId: widget.senderId,
      senderDevice: widget.senderDevice,
      messageTimestamp: widget.messageTimestamp,
      categories: finalCategories,
      reporterEmail: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
    );

    if (!mounted) return;

    if (success) {
      Navigator.pop(context);
      showCustomSnackBar(context, 'Report submitted successfully. Thank you.', type: SnackBarType.success);
    } else {
      setState(() => _isSubmitting = false);
      showCustomSnackBar(context, 'Failed to submit report. Please try again.', type: SnackBarType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: Text(
                'Report Message',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '"${widget.originalMessageText}"',
                style: const TextStyle(color: Colors.white70, fontStyle: FontStyle.italic),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 20),
            const Text('Select reasons:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: _categories.keys.map((String key) {
                final isSelected = _categories[key]!;
                return FilterChip(
                  label: Text(key, style: TextStyle(color: isSelected ? Colors.white : Colors.white70)),
                  selected: isSelected,
                  selectedColor: Colors.redAccent.withValues(alpha: 0.8),
                  backgroundColor: Colors.white10,
                  checkmarkColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                  fillColor: Colors.white12,
                  hintText: 'Please specify other reason...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            const Text('Email (Optional for follow-up):', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            TextField(
              controller: _emailController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white12,
                hintText: 'your@email.com',
                hintStyle: const TextStyle(color: Colors.white38),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 30),
            Center(
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitReport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent.withValues(alpha: 0.8),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _isSubmitting 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Submit Report', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
