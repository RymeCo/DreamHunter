import 'package:flutter/material.dart';
import 'package:dreamhunter/widgets/liquid_glass_dialog.dart';
import 'package:dreamhunter/widgets/glass_button.dart';
import 'package:dreamhunter/services/core/update_service.dart';

class UpdateDialog extends StatelessWidget {
  final UpdateInfo info;

  const UpdateDialog({super.key, required this.info});

  static void show(BuildContext context, UpdateInfo info) {
    showGeneralDialog(
      context: context,
      barrierLabel: "UpdateDialog",
      barrierDismissible: true,
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, animation, secondaryAnimation) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          child: FadeTransition(
            opacity: animation,
            child: Center(child: UpdateDialog(info: info)),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return LiquidGlassDialog(
      width: 320,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.system_update_rounded, color: Colors.cyanAccent),
              const SizedBox(width: 12),
              Text(
                "Update Available",
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "Version ${info.latestVersion} is now available.",
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 16),
          const Text(
            "CHANGELOG:",
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxHeight: 180),
            child: SingleChildScrollView(
              child: Text(
                info.changelog,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: GlassButton(
                  label: "LATER",
                  onTap: () => Navigator.of(context).pop(),
                  color: Colors.white10,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GlassButton(
                  label: "UPDATE",
                  onTap: () {
                    UpdateService.downloadUpdate(info.downloadUrl);
                    Navigator.of(context).pop();
                  },
                  color: Colors.cyanAccent,
                  glowColor: Colors.cyanAccent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
