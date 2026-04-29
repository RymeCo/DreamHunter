import 'package:flutter/material.dart';
import 'package:dreamhunter/services/core/audio_manager.dart';
import 'package:dreamhunter/services/core/haptic_manager.dart';
import 'package:dreamhunter/widgets/liquid_glass_dialog.dart';
import 'package:dreamhunter/core/theme/app_theme.dart';

/// A reusable game-themed confirmation dialog with built-in haptics and audio.
///
/// Use [ConfirmationDialog.show] for standard queries.
class ConfirmationDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final IconData icon;
  final Color? color;
  final bool isDestructive;

  const ConfirmationDialog({
    super.key,
    this.title = 'ARE YOU SURE?',
    required this.message,
    this.confirmLabel = 'CONFIRM',
    this.cancelLabel = 'CANCEL',
    this.icon = Icons.warning_amber_rounded,
    this.color,
    this.isDestructive = false,
  });

  /// The ultimate "Call this once and forget" helper.
  /// Standardizes appearance, haptics, and audio.
  static Future<bool> show(
    BuildContext context, {
    String title = 'ARE YOU SURE?',
    required String message,
    String confirmLabel = 'CONFIRM',
    String cancelLabel = 'CANCEL',
    IconData? icon,
    Color? color,
    bool isDestructive = false,
  }) async {
    final result = await showGeneralDialog<bool>(
      context: context,
      barrierLabel: "ConfirmationDialog",
      barrierDismissible: true,
      barrierColor: Colors.black87, // Slightly darker for focus
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Center(
          child: ConfirmationDialog(
            title: title,
            message: message,
            confirmLabel: confirmLabel,
            cancelLabel: cancelLabel,
            icon:
                icon ??
                (isDestructive
                    ? Icons.delete_forever_rounded
                    : Icons.warning_amber_rounded),
            color: color,
            isDestructive: isDestructive,
          ),
        );
      },
      transitionBuilder: (context, a1, a2, child) {
        return Transform.scale(
          scale: Curves.easeOutBack.transform(a1.value),
          child: FadeTransition(opacity: a1, child: child),
        );
      },
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final glass =
        Theme.of(context).extension<GlassTheme>() ?? const GlassTheme();
    final accentColor =
        color ?? (isDestructive ? Colors.redAccent : Colors.amberAccent);

    return LiquidGlassDialog(
      width: 340,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Visual Cue
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: glass.baseOpacity * 1.5),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: accentColor, size: 40),
          ),
          const SizedBox(height: 20),

          // Content
          Text(
            title.toUpperCase(),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontSize: 18,
              letterSpacing: 1.5,
              color: accentColor,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.7),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 32),

          // Actions
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () {
                    AudioManager.instance.playClick();
                    Navigator.pop(context, false);
                  },
                  child: Text(
                    cancelLabel,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    AudioManager.instance.playClick();
                    // Destructive actions feel "heavy"
                    if (isDestructive) {
                      HapticManager.instance.heavy();
                    } else {
                      HapticManager.instance.medium();
                    }
                    Navigator.pop(context, true);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 0,
                  ),
                  child: Text(
                    confirmLabel,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
