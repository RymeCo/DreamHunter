import 'package:flutter/material.dart';

/// Defines the visual style of the snackbar.
enum SnackBarType { success, error, info }

/// Displays a stylized, game-themed snackbar message at the top of the screen.
///
/// ### How to use:
/// ```dart
/// showCustomSnackBar(
///   context,
///   'Quest Completed!',
///   type: SnackBarType.success,
/// );
/// ```
void showCustomSnackBar(
  BuildContext context,
  String message, {
  SnackBarType type = SnackBarType.info,
}) {
  final overlay = Overlay.of(context);
  final overlayEntry = OverlayEntry(
    builder: (context) {
      Color bgColor;
      IconData icon;

      switch (type) {
        case SnackBarType.success:
          bgColor = Colors.greenAccent.withValues(alpha: 0.9);
          icon = Icons.check_circle_outline;
          break;
        case SnackBarType.error:
          bgColor = Colors.redAccent.withValues(alpha: 0.9);
          icon = Icons.error_outline;
          break;
        case SnackBarType.info:
          bgColor = Colors.blueAccent.withValues(alpha: 0.9);
          icon = Icons.info_outline;
          break;
      }

      return Positioned(
        bottom: 50,
        left: 20,
        right: 20,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(icon, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  overlay.insert(overlayEntry);
  Future.delayed(const Duration(seconds: 3), () {
    overlayEntry.remove();
  });
}
