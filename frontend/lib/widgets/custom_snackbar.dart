import 'package:flutter/material.dart';

/// Defines the visual style of the snackbar.
enum SnackBarType { success, error, info }

/// Represents a single snackbar request in the queue.
class _SnackBarRequest {
  final String message;
  final SnackBarType type;
  final String? actionLabel;
  final VoidCallback? onAction;

  _SnackBarRequest({
    required this.message,
    required this.type,
    this.actionLabel,
    this.onAction,
  });
}

/// A manager for stylized, game-themed snackbar messages.
/// Implements a queue system to ensure messages are shown sequentially.
class CustomSnackBar {
  static final List<_SnackBarRequest> _queue = [];
  static bool _isProcessing = false;
  static OverlayEntry? _currentEntry;

  /// Dismisses the current snackbar and clears the queue.
  static void dismiss() {
    _queue.clear();
    if (_currentEntry != null) {
      _currentEntry!.remove();
      _currentEntry = null;
    }
    _isProcessing = false;
  }

  /// Displays a stylized, game-themed snackbar message.
  /// If another snackbar is showing, this one will be queued.
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
    // 1. Add to queue
    _queue.add(_SnackBarRequest(
      message: message,
      type: type,
      actionLabel: actionLabel,
      onAction: onAction,
    ));

    // 2. Start processing if not already
    _processQueue(context);
  }

  static Future<void> _processQueue(BuildContext context) async {
    if (_isProcessing || _queue.isEmpty) return;

    _isProcessing = true;

    try {
      final overlay = Overlay.of(context);

      while (_queue.isNotEmpty) {
        final request = _queue.removeAt(0);
        
        _currentEntry = _createOverlayEntry(request);
        overlay.insert(_currentEntry!);

        // Wait for the specified duration (2.5 seconds as requested)
        await Future.delayed(const Duration(milliseconds: 2500));

        if (_currentEntry != null) {
          _currentEntry!.remove();
          _currentEntry = null;
        }

        // Small gap between messages for smoother transitions
        if (_queue.isNotEmpty) {
          await Future.delayed(const Duration(milliseconds: 300));
        }
      }
    } catch (e) {
      debugPrint('Error processing snackbar queue: $e');
    } finally {
      _isProcessing = false;
    }
  }

  static OverlayEntry _createOverlayEntry(_SnackBarRequest request) {
    return OverlayEntry(
      builder: (context) {
        Color bgColor;
        IconData icon;

        switch (request.type) {
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
                      request.message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (request.actionLabel != null && request.onAction != null)
                    TextButton(
                      onPressed: () {
                        request.onAction!();
                        // When action is clicked, we might want to skip the remaining wait
                        if (_currentEntry != null) {
                          _currentEntry!.remove();
                          _currentEntry = null;
                        }
                      },
                      child: Text(
                        request.actionLabel!,
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
