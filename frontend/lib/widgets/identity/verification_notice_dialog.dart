import 'package:dreamhunter/services/core/audio_manager.dart';
import 'package:dreamhunter/widgets/liquid_glass_dialog.dart';
import 'package:flutter/material.dart';

class VerificationNoticeDialog extends StatelessWidget {
  final String email;
  final VoidCallback onContinue;

  const VerificationNoticeDialog({
    super.key,
    required this.email,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return LiquidGlassDialog(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.mark_email_unread_outlined,
            size: 64,
            color: Colors.cyanAccent,
          ),
          const SizedBox(height: 24),
          Text(
            'VERIFICATION SENT',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
              color: Colors.cyanAccent,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'We have sent a confirmation link to:',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 8),
          Text(
            email,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.orangeAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.orangeAccent.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  size: 16,
                  color: Colors.orangeAccent,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Can\'t find it? Please check your Spam or All Mail folders.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.orangeAccent,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Divider(color: Colors.white10),
          const SizedBox(height: 16),
          _buildBenefitItem(
            context,
            Icons.cloud_done,
            'Enable Cloud Backup to secure your progress.',
          ),
          const SizedBox(height: 12),
          _buildBenefitItem(
            context,
            Icons.leaderboard,
            'Get included in the Global Leaderboard.',
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                AudioManager().playClick();
                onContinue();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyanAccent.withValues(alpha: 0.2),
                foregroundColor: Colors.cyanAccent,
                side: const BorderSide(color: Colors.cyanAccent),
              ),
              child: const Text('GOT IT'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitItem(BuildContext context, IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.cyanAccent.withValues(alpha: 0.7)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.white60, height: 1.4),
          ),
        ),
      ],
    );
  }
}
