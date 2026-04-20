import 'package:flutter/material.dart';
import 'package:dreamhunter/services/core/haptic_manager.dart';
import 'package:dreamhunter/core/theme/app_theme.dart';
import 'dart:ui';

enum SnackBarType { success, error, warning, info }

/// A simplified, theme-centric snackbar that leverages Flutter's ScaffoldMessenger
/// for stability, queuing, and animations.
class CustomSnackBar {
  static void show(
    BuildContext context,
    String message, {
    SnackBarType type = SnackBarType.info,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final glass = Theme.of(context).extension<GlassTheme>() ?? const GlassTheme();

    // Trigger standard haptics based on type
    _triggerHaptic(type);

    // Clear existing to prevent overlap/wait times
    scaffoldMessenger.removeCurrentSnackBar();

    scaffoldMessenger.showSnackBar(
      SnackBar(
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent, // We use the container for glass effect
        duration: const Duration(milliseconds: 2500),
        padding: EdgeInsets.zero,
        content: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: glass.blurSigma, sigmaY: glass.blurSigma),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: _getColor(type).withValues(alpha: glass.baseOpacity * 2.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _getColor(type).withValues(alpha: glass.borderAlpha),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Icon(_getIcon(type), color: _getColor(type), size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      message.toUpperCase(),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontSize: 13,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  if (actionLabel != null && onAction != null)
                    TextButton(
                      onPressed: onAction,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        visualDensity: VisualDensity.compact,
                      ),
                      child: Text(
                        actionLabel,
                        style: const TextStyle(fontWeight: FontWeight.w900, decoration: TextDecoration.underline),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Color _getColor(SnackBarType type) {
    switch (type) {
      case SnackBarType.success: return Colors.greenAccent;
      case SnackBarType.error: return Colors.redAccent;
      case SnackBarType.warning: return Colors.amberAccent;
      case SnackBarType.info: return Colors.blueAccent;
    }
  }

  static IconData _getIcon(SnackBarType type) {
    switch (type) {
      case SnackBarType.success: return Icons.check_circle_rounded;
      case SnackBarType.error: return Icons.error_rounded;
      case SnackBarType.warning: return Icons.warning_rounded;
      case SnackBarType.info: return Icons.info_rounded;
    }
  }

  static void _triggerHaptic(SnackBarType type) {
    switch (type) {
      case SnackBarType.error:
        HapticManager.instance.medium();
        break;
      case SnackBarType.warning:
        HapticManager.instance.light();
        break;
      default:
        HapticManager.instance.light();
    }
  }
}

/// Legacy wrapper kept for simplicity and project-wide usage.
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
