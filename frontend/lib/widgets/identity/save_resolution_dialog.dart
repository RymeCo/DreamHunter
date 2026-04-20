import 'package:flutter/material.dart';
import 'package:dreamhunter/widgets/liquid_glass_dialog.dart';
import 'package:dreamhunter/widgets/glass_button.dart';
import 'package:dreamhunter/services/core/storage_engine.dart';
import 'package:dreamhunter/services/identity/profile_manager.dart';

/// A specialized dialog to handle conflicts between local Guest saves and Cloud saves.
class SaveResolutionDialog extends StatelessWidget {
  final String targetUid;

  const SaveResolutionDialog({super.key, required this.targetUid});

  static Future<void> showIfNeeded(BuildContext context, String uid) async {
    if (StorageEngine.instance.hasGuestData()) {
      await showGeneralDialog(
        context: context,
        barrierLabel: "SaveConflict",
        barrierDismissible: false, // Force a choice
        barrierColor: Colors.black87,
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, animation, secondaryAnimation) {
          return Center(
            child: ScaleTransition(
              scale: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutBack,
              ),
              child: SaveResolutionDialog(targetUid: uid),
            ),
          );
        },
      );
    } else {
      // No guest data, just ensure services are fresh for the new user
      await ProfileManager.instance.reloadAllServices();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LiquidGlassDialog(
      width: 400,
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'SAVE CONFLICT',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.amberAccent,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 20),
          const Icon(
            Icons.cloud_sync_rounded,
            color: Colors.amberAccent,
            size: 60,
          ),
          const SizedBox(height: 20),
          Text(
            'We found local guest progress on this device.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Do you want to continue with your current Local Progress, or download your Cloud Save?',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 32),
          GlassButton(
            onTap: () async {
              // 1. Promote guest keys to user keys
              await StorageEngine.instance.promoteGuestToUser(targetUid);
              // 2. Clear conflict flag
              await StorageEngine.instance.setPendingConflict(false);
              // 3. Reload services to reflect new local state
              await ProfileManager.instance.reloadAllServices();
              if (context.mounted) Navigator.pop(context);
            },
            glowColor: Colors.amberAccent,
            width: double.infinity,
            label: 'USE LOCAL PROGRESS',
          ),
          const SizedBox(height: 12),
          GlassButton(
            onTap: () async {
              // 1. Clear conflict flag
              await StorageEngine.instance.setPendingConflict(false);
              // 2. Simply reload services (will ignore guest keys and use cloud uid keys)
              await ProfileManager.instance.reloadAllServices();
              if (context.mounted) Navigator.pop(context);
            },
            glowColor: Colors.cyanAccent,
            width: double.infinity,
            color: Colors.transparent,
            label: 'USE CLOUD SAVE',
          ),
        ],
      ),
    );
  }
}
