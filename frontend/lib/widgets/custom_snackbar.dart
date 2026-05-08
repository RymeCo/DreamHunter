import 'package:flutter/material.dart';
import 'package:dreamhunter/services/core/haptic_manager.dart';
import 'package:dreamhunter/core/theme/app_theme.dart';
import 'dart:ui';
import 'dart:async';

enum SnackBarType { success, error, warning, info }

/// A globally positioned notification system that appears ABOVE all dialogs and blurs.
/// Uses Flutter's Overlay system instead of ScaffoldMessenger for absolute visibility.
class CustomSnackBar {
  static OverlayEntry? _currentEntry;
  static Timer? _hideTimer;

  static void show(
    BuildContext context,
    String message, {
    SnackBarType type = SnackBarType.info,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(milliseconds: 3000),
  }) {
    // 1. Cleanup existing
    _currentEntry?.remove();
    _currentEntry = null;
    _hideTimer?.cancel();

    // 2. Perception & Haptics
    _triggerHaptic(type);

    // 3. Create Entry
    final overlay = Overlay.of(context);
    final glass =
        Theme.of(context).extension<GlassTheme>() ?? const GlassTheme();

    _currentEntry = OverlayEntry(
      builder: (context) => _SnackBarWidget(
        message: message,
        type: type,
        actionLabel: actionLabel,
        onAction: onAction,
        glass: glass,
        onDismiss: () {
          _currentEntry?.remove();
          _currentEntry = null;
          _hideTimer?.cancel();
        },
      ),
    );

    overlay.insert(_currentEntry!);

    // 4. Auto-hide logic
    _hideTimer = Timer(duration, () {
      if (_currentEntry != null) {
        _currentEntry?.remove();
        _currentEntry = null;
      }
    });
  }

  static Color _getColor(SnackBarType type) {
    switch (type) {
      case SnackBarType.success:
        return Colors.greenAccent;
      case SnackBarType.error:
        return Colors.redAccent;
      case SnackBarType.warning:
        return Colors.amberAccent;
      case SnackBarType.info:
        return Colors.blueAccent;
    }
  }

  static IconData _getIcon(SnackBarType type) {
    switch (type) {
      case SnackBarType.success:
        return Icons.check_circle_rounded;
      case SnackBarType.error:
        return Icons.error_rounded;
      case SnackBarType.warning:
        return Icons.warning_rounded;
      case SnackBarType.info:
        return Icons.info_rounded;
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

class _SnackBarWidget extends StatefulWidget {
  final String message;
  final SnackBarType type;
  final String? actionLabel;
  final VoidCallback? onAction;
  final GlassTheme glass;
  final VoidCallback onDismiss;

  const _SnackBarWidget({
    required this.message,
    required this.type,
    this.actionLabel,
    this.onAction,
    required this.glass,
    required this.onDismiss,
  });

  @override
  State<_SnackBarWidget> createState() => _SnackBarWidgetState();
}

class _SnackBarWidgetState extends State<_SnackBarWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _opacityAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = CustomSnackBar._getColor(widget.type);
    final icon = CustomSnackBar._getIcon(widget.type);

    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.only(top: 20, left: 16, right: 16),
          child: SlideTransition(
            position: _offsetAnimation,
            child: FadeTransition(
              opacity: _opacityAnimation,
              child: Material(
                color: Colors.transparent,
                child: GestureDetector(
                  onTap: widget.onDismiss,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(
                        sigmaX: widget.glass.blurSigma,
                        sigmaY: widget.glass.blurSigma,
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(
                            alpha: widget.glass.baseOpacity * 4,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: color.withValues(
                              alpha: widget.glass.borderAlpha * 2,
                            ),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: color.withValues(alpha: 0.1),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(icon, color: color, size: 24),
                            const SizedBox(width: 12),
                            Flexible(
                              child: Text(
                                widget.message.toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            if (widget.actionLabel != null) ...[
                              const SizedBox(width: 12),
                              TextButton(
                                onPressed: () {
                                  widget.onAction?.call();
                                  widget.onDismiss();
                                },
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                ),
                                child: Text(
                                  widget.actionLabel!,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Project-wide convenience wrapper.
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
