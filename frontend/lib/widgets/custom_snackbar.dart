import 'package:flutter/material.dart';

/// Defines the visual style of the snackbar.
enum SnackBarType { success, error, info }

/// A manager for stylized, game-themed snackbar messages.
/// Ensures only one snackbar is visible at a time by dismissing previous ones.
class CustomSnackBar {
  static OverlayEntry? _currentEntry;
  static bool _isRemoved = false;

  /// Dismisses any active snackbar.
  static void dismiss() {
    if (_currentEntry != null && !_isRemoved) {
      _isRemoved = true;
      _currentEntry!.remove();
      _currentEntry = null;
    }
  }

  /// Displays a stylized, game-themed snackbar message.
  ///
  /// ### How to use:
  /// ```dart
  /// CustomSnackBar.show(
  ///   context,
  ///   'Quest Completed!',
  ///   type: SnackBarType.success,
  /// );
  /// ```
  static void show(
    BuildContext context,
    String message, {
    SnackBarType type = SnackBarType.info,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    // 1. Dismiss any existing snackbar before showing a new one
    dismiss();
    _isRemoved = false;

    final overlay = Overlay.of(context);
    late final OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
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
                  if (actionLabel != null && onAction != null)
                    TextButton(
                      onPressed: () {
                        onAction();
                        dismiss();
                      },
                      child: Text(
                        actionLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
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

    _currentEntry = overlayEntry;
    overlay.insert(overlayEntry);

    // Auto-dismiss after a delay
    Future.delayed(const Duration(seconds: 4), () {
      if (_currentEntry == overlayEntry) {
        dismiss();
      }
    });
  }
}

/// Legacy wrapper to maintain compatibility while migrating to CustomSnackBar.show
void showCustomSnackBar(
  BuildContext context,
  String message, {
  SnackBarType type = SnackBarType.info,
  String? actionLabel,
  VoidCallback? onAction,
}) {
  CustomSnackBar.show(
    context,
    message,
    type: type,
    actionLabel: actionLabel,
    onAction: onAction,
  );
}
