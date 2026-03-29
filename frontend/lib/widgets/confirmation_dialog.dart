import 'package:flutter/material.dart';
import 'liquid_glass_dialog.dart';

/// A reusable game-themed confirmation dialog.
///
/// Returns `true` if the user confirms, `false` or `null` otherwise.
class ConfirmationDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final IconData icon;
  final Color iconColor;

  const ConfirmationDialog({
    super.key,
    this.title = 'Are you sure?',
    required this.message,
    this.confirmLabel = 'CONFIRM',
    this.cancelLabel = 'CANCEL',
    this.icon = Icons.warning_amber_rounded,
    this.iconColor = Colors.amberAccent,
  });

  /// Static helper to show the dialog
  static Future<bool?> show(
    BuildContext context, {
    String title = 'Are you sure?',
    required String message,
    String confirmLabel = 'CONFIRM',
    String cancelLabel = 'CANCEL',
    IconData icon = Icons.warning_amber_rounded,
    Color iconColor = Colors.amberAccent,
  }) {
    return showGeneralDialog<bool>(
      context: context,
      barrierLabel: "ConfirmationDialog",
      barrierDismissible: true,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Center(
          child: ConfirmationDialog(
            title: title,
            message: message,
            confirmLabel: confirmLabel,
            cancelLabel: cancelLabel,
            icon: icon,
            iconColor: iconColor,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return LiquidGlassDialog(
      width: 300,
      height: 250,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: iconColor, size: 48),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  cancelLabel,
                  style: const TextStyle(
                    color: Colors.white38,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: iconColor,
                  foregroundColor: Colors.black,
                  elevation: 8,
                  shadowColor: iconColor.withValues(alpha: 0.5),
                ),
                child: Text(
                  confirmLabel,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
