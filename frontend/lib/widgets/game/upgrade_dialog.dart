import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dreamhunter/widgets/liquid_glass_dialog.dart';
import 'package:dreamhunter/widgets/common_ui.dart';
import 'package:dreamhunter/widgets/glass_button.dart';
import 'package:dreamhunter/services/core/audio_manager.dart';
import 'package:dreamhunter/services/core/haptic_manager.dart';
import 'package:dreamhunter/services/game/match_manager.dart';

/// Represents a specific condition that must be met for an upgrade.
class UpgradeRequirement {
  final String label;
  final bool isMet;
  const UpgradeRequirement({required this.label, required this.isMet});
}

/// A reusable, standardized dialog for upgrading buildings (Bed, Generator, Door, Turrets).
class UpgradeDialog extends StatefulWidget {
  final String title;
  final int currentLevel;
  final Widget? levelDisplay;
  final List<UpgradeRequirement> requirements;
  final int coinCost;
  final int energyCost;
  final String? upgradeBenefit;
  final bool isMaxLevel;
  final VoidCallback onUpgrade;

  const UpgradeDialog({
    super.key,
    required this.title,
    required this.currentLevel,
    this.levelDisplay,
    required this.requirements,
    required this.coinCost,
    this.energyCost = 0,
    this.upgradeBenefit,
    this.isMaxLevel = false,
    required this.onUpgrade,
  });

  /// Static helper to show the dialog
  static Future<void> show(
    BuildContext context, {
    required String title,
    required int currentLevel,
    Widget? levelDisplay,
    required List<UpgradeRequirement> requirements,
    required int coinCost,
    int energyCost = 0,
    String? upgradeBenefit,
    bool isMaxLevel = false,
    required VoidCallback onUpgrade,
  }) async {
    await showGeneralDialog<void>(
      context: context,
      barrierLabel: "UpgradeDialog",
      barrierDismissible: true,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          child: FadeTransition(
            opacity: animation,
            child: UpgradeDialog(
              title: title,
              currentLevel: currentLevel,
              levelDisplay: levelDisplay,
              requirements: requirements,
              coinCost: coinCost,
              energyCost: energyCost,
              upgradeBenefit: upgradeBenefit,
              isMaxLevel: isMaxLevel,
              onUpgrade: onUpgrade,
            ),
          ),
        );
      },
    );
  }

  @override
  State<UpgradeDialog> createState() => _UpgradeDialogState();
}

class _UpgradeDialogState extends State<UpgradeDialog> {
  bool _showNotEnough = false;
  bool _showReqNotMet = false;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: LiquidGlassDialog(
        width: 280,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            GameDialogHeader(title: widget.title),

            // Level Indicator
            _buildLevelIndicator(context),

            if (widget.upgradeBenefit != null) ...[
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "UPGRADE EFFECT",
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.white38,
                        letterSpacing: 2.0,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Text(
                      "FULL HEAL",
                      style: TextStyle(
                        color: Colors.amberAccent,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.greenAccent.withValues(alpha: 0.1),
                      Colors.black26,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.greenAccent.withValues(alpha: 0.2),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.greenAccent.withValues(alpha: 0.05),
                      blurRadius: 10,
                      spreadRadius: -2,
                    ),
                  ],
                ),
                child: _buildUpgradeBenefitText(
                  context,
                  widget.upgradeBenefit!,
                ),
              ),
            ],

            // Requirements Section
            if (widget.requirements.isNotEmpty &&
                widget.requirements.any((r) => !r.isMet)) ...[
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "REQUIREMENTS",
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.white38,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ...widget.requirements.map(
                (req) => _buildRequirementRow(context, req.label, req.isMet),
              ),
            ],

            const SizedBox(height: 24),

            // Upgrade Button or Max Level Indicator
            if (widget.isMaxLevel)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10),
                ),
                child: Text(
                  "MAXIMUM LEVEL",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.2),
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    fontSize: 12,
                  ),
                ),
              )
            else
              ListenableBuilder(
                listenable: MatchManager.instance,
                builder: (context, child) {
                  final bool allRequirementsMet = widget.requirements.every(
                    (r) => r.isMet,
                  );
                  final bool canAffordCoins =
                      MatchManager.instance.matchCoins >= widget.coinCost;
                  final bool canAffordEnergy =
                      MatchManager.instance.matchEnergy >= widget.energyCost;
                  final bool canUpgrade =
                      allRequirementsMet && canAffordCoins && canAffordEnergy;

                  // Determine button label
                  String? buttonLabel;
                  if (_showNotEnough) {
                    buttonLabel = "NOT ENOUGH!";
                  } else if (_showReqNotMet) {
                    buttonLabel = "REQ NOT MET";
                  }

                  return GlassButton(
                    width: double.infinity,
                    height: 50,
                    pulseEffect:
                        canUpgrade, // Only pulse when ready to upgrade!
                    glowColor: (_showNotEnough || _showReqNotMet)
                        ? Colors.redAccent
                        : (canUpgrade ? Colors.tealAccent : Colors.white10),
                    color: canUpgrade
                        ? null
                        : Colors.black54, // Darker when locked/not affordable
                    onTap: () {
                      if (!allRequirementsMet) {
                        if (!_showReqNotMet) {
                          HapticManager.instance.heavy();
                          setState(() => _showReqNotMet = true);
                          Future.delayed(
                            const Duration(milliseconds: 1200),
                            () {
                              if (mounted) {
                                setState(() => _showReqNotMet = false);
                              }
                            },
                          );
                        }
                        return;
                      }
                      if (!canAffordCoins || !canAffordEnergy) {
                        if (!_showNotEnough) {
                          HapticManager.instance.heavy();
                          setState(() => _showNotEnough = true);
                          Future.delayed(
                            const Duration(milliseconds: 1200),
                            () {
                              if (mounted) {
                                setState(() => _showNotEnough = false);
                              }
                            },
                          );
                        }
                        return;
                      }

                      AudioManager.instance.playClick();
                      HapticManager.instance.medium();
                      widget.onUpgrade();
                      if (mounted) {
                        Navigator.pop(context);
                      }
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (buttonLabel != null)
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                buttonLabel,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2,
                                ),
                              ),
                            ),
                          )
                        else ...[
                          // Coin Cost Indicator
                          if (widget.coinCost > 0) ...[
                            Icon(
                              Icons.monetization_on_rounded,
                              color: canAffordCoins
                                  ? Colors.amberAccent
                                  : Colors.white10,
                              size: 18,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              "${widget.coinCost}",
                              style: TextStyle(
                                color: canAffordCoins
                                    ? Colors.amberAccent
                                    : Colors.white10,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],

                          if (widget.energyCost > 0) ...[
                            if (widget.coinCost > 0) const SizedBox(width: 12),
                            // Energy Cost Indicator
                            Icon(
                              Icons.bolt_rounded,
                              color: canAffordEnergy
                                  ? Colors.cyanAccent
                                  : Colors.white10,
                              size: 18,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              "${widget.energyCost}",
                              style: TextStyle(
                                color: canAffordEnergy
                                    ? Colors.cyanAccent
                                    : Colors.white10,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelIndicator(BuildContext context) {
    if (widget.levelDisplay != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Current Level",
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
            widget.levelDisplay!,
          ],
        ),
      );
    }

    return _buildInfoRow(
      context,
      "Current Level",
      "Lv. ${widget.currentLevel}",
      Colors.white70,
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    String label,
    String value,
    Color valueColor,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  color: valueColor,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequirementRow(BuildContext context, String text, bool isMet) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Icon(
            isMet
                ? Icons.check_circle_outline_rounded
                : Icons.radio_button_unchecked_rounded,
            color: isMet
                ? Colors.greenAccent
                : Colors.redAccent.withValues(alpha: 0.5),
            size: 14,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: isMet ? Colors.white : Colors.white24,
                fontSize: 13,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpgradeBenefitText(BuildContext context, String text) {
    final lines = text.split('\n');
    final List<TextSpan> spans = [];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.contains('➔')) {
        final parts = line.split('➔');
        spans.add(
          TextSpan(
            text: parts[0],
            style: const TextStyle(color: Colors.white70),
          ),
        );
        spans.add(
          const TextSpan(
            text: ' ➔ ',
            style: TextStyle(
              color: Colors.greenAccent,
              fontWeight: FontWeight.w900,
            ),
          ),
        );
        spans.add(
          TextSpan(
            text: parts[1],
            style: const TextStyle(
              color: Colors.greenAccent,
              fontWeight: FontWeight.w900,
            ),
          ),
        );
      } else {
        spans.add(
          TextSpan(
            text: line,
            style: const TextStyle(
              color: Colors.greenAccent,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
      }

      if (i < lines.length - 1) {
        spans.add(const TextSpan(text: '\n'));
      }
    }

    return RichText(
      text: TextSpan(
        style: GoogleFonts.quicksand(fontSize: 16, height: 1.5),
        children: spans,
      ),
    );
  }
}
