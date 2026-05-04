import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dreamhunter/widgets/liquid_glass_dialog.dart';
import 'package:dreamhunter/widgets/common_ui.dart';
import 'package:dreamhunter/widgets/glass_button.dart';
import 'package:dreamhunter/services/core/audio_manager.dart';
import 'package:dreamhunter/services/core/haptic_manager.dart';
import 'package:dreamhunter/services/game/match_manager.dart';

import 'package:dreamhunter/services/core/ad_manager.dart';

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
  final VoidCallback? onFreeUpgrade;
  final VoidCallback? onSell;
  final int sellRefundCoins;
  final int sellRefundEnergy;

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
    this.onFreeUpgrade,
    this.onSell,
    this.sellRefundCoins = 0,
    this.sellRefundEnergy = 0,
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
    VoidCallback? onFreeUpgrade,
    VoidCallback? onSell,
    int sellRefundCoins = 0,
    int sellRefundEnergy = 0,
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
              onFreeUpgrade: onFreeUpgrade,
              onSell: onSell,
              sellRefundCoins: sellRefundCoins,
              sellRefundEnergy: sellRefundEnergy,
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
        width: 300,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            GameDialogHeader(title: widget.title),

            // Level Indicator Card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "CURRENT LEVEL",
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  if (widget.levelDisplay != null)
                    widget.levelDisplay!
                  else
                    Text(
                      "LV. ${widget.currentLevel}",
                      style: const TextStyle(
                        color: Colors.amberAccent,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                ],
              ),
            ),

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
                        color: Colors.greenAccent,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.tealAccent.withValues(alpha: 0.05),
                      Colors.black26,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.tealAccent.withValues(alpha: 0.2),
                    width: 1.5,
                  ),
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
                    fontWeight: FontWeight.w900,
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
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.05)),
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
                    buttonLabel = "INSUFFICIENT FUNDS";
                  } else if (_showReqNotMet) {
                    buttonLabel = "REQ NOT MET";
                  }

                  return GlassButton(
                    width: double.infinity,
                    height: 56,
                    isClickable: true,
                    pulseEffect: canUpgrade,
                    color: canUpgrade ? Colors.tealAccent : Colors.black45,
                    glowColor: canUpgrade ? Colors.tealAccent : Colors.white10,
                    borderColor: canUpgrade ? Colors.tealAccent : Colors.white10,
                    borderRadius: 16,
                    onTap: () {
                      if (!allRequirementsMet) {
                        if (!_showReqNotMet) {
                          HapticManager.instance.heavy();
                          setState(() => _showReqNotMet = true);
                          Future.delayed(const Duration(milliseconds: 1200),
                              () {
                            if (mounted) {
                              setState(() => _showReqNotMet = false);
                            }
                          });
                        }
                        return;
                      }
                      if (!canAffordCoins || !canAffordEnergy) {
                        if (!_showNotEnough) {
                          HapticManager.instance.heavy();
                          setState(() => _showNotEnough = true);
                          Future.delayed(const Duration(milliseconds: 1200),
                              () {
                            if (mounted) {
                              setState(() => _showNotEnough = false);
                            }
                          });
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
                          Text(
                            buttonLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                              fontSize: 13,
                            ),
                          )
                        else ...[
                          Text(
                            "UPGRADE",
                            style: TextStyle(
                              color: canUpgrade ? Colors.white : Colors.white24,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                              width: 1, height: 20, color: canUpgrade ? Colors.tealAccent.withValues(alpha: 0.3) : Colors.white10),
                          const SizedBox(width: 12),
                          if (widget.coinCost > 0) ...[
                            Icon(
                              Icons.monetization_on_rounded,
                              color: canUpgrade 
                                  ? Colors.white
                                  : (canAffordCoins ? Colors.white70 : Colors.redAccent.withValues(alpha: 0.5)),
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              "${widget.coinCost}",
                              style: TextStyle(
                                color: canUpgrade 
                                    ? Colors.white
                                    : (canAffordCoins ? Colors.white70 : Colors.redAccent.withValues(alpha: 0.5)),
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                          if (widget.energyCost > 0) ...[
                            if (widget.coinCost > 0) const SizedBox(width: 8),
                            Icon(
                              Icons.bolt_rounded,
                              color: canUpgrade 
                                  ? Colors.white
                                  : (canAffordEnergy ? Colors.white70 : Colors.redAccent.withValues(alpha: 0.5)),
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              "${widget.energyCost}",
                              style: TextStyle(
                                color: canUpgrade 
                                    ? Colors.white
                                    : (canAffordEnergy ? Colors.white70 : Colors.redAccent.withValues(alpha: 0.5)),
                                fontSize: 15,
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

            // Free Upgrade via Ad
            if (!widget.isMaxLevel && widget.onFreeUpgrade != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Expanded(child: Divider(color: Colors.white10)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      "OR",
                      style: GoogleFonts.quicksand(
                        color: Colors.white24,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const Expanded(child: Divider(color: Colors.white10)),
                ],
              ),
              const SizedBox(height: 12),
              ListenableBuilder(
                listenable: MatchManager.instance,
                builder: (context, child) {
                  final bool canUseAd = MatchManager.instance.canUseAdUpgrade;
                  final int remaining = MatchManager.maxAdUpgradesPerMatch -
                      MatchManager.instance.adUpgradesUsed;

                  return GlassButton(
                    width: double.infinity,
                    height: 48,
                    isClickable: canUseAd,
                    glowColor: canUseAd ? Colors.amberAccent : Colors.white10,
                    color: canUseAd ? null : Colors.black54,
                    onTap: () {
                      AdManager.instance.showRewardAd(
                        context: context,
                        onRewardEarned: () {
                          widget.onFreeUpgrade!();
                          if (mounted) {
                            Navigator.pop(context);
                          }
                        },
                      );
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          canUseAd ? Icons.play_circle_fill : Icons.lock_clock,
                          color: canUseAd ? Colors.amberAccent : Colors.white24,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          canUseAd
                              ? "FREE UPGRADE ($remaining LEFT)"
                              : "LIMIT REACHED",
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: canUseAd
                                        ? Colors.amberAccent
                                        : Colors.white24,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.2,
                                  ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],

            // Sell Button (More integrated, clean look)
            if (widget.onSell != null) ...[
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () {
                  AudioManager.instance.playClick();
                  HapticManager.instance.heavy();
                  widget.onSell!();
                  if (mounted) {
                    Navigator.pop(context);
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.redAccent.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.delete_forever_rounded,
                        color: Colors.redAccent,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "DISMANTLE",
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        "(REFUND:",
                        style: TextStyle(color: Colors.white24, fontSize: 10),
                      ),
                      const SizedBox(width: 4),
                      if (widget.sellRefundCoins > 0) ...[
                        const Icon(Icons.monetization_on_rounded, color: Colors.amberAccent, size: 12),
                        const SizedBox(width: 2),
                        Text("${widget.sellRefundCoins}", style: const TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                      if (widget.sellRefundEnergy > 0) ...[
                        if (widget.sellRefundCoins > 0) const SizedBox(width: 4),
                        const Icon(Icons.bolt_rounded, color: Colors.cyanAccent, size: 12),
                        const SizedBox(width: 2),
                        Text("${widget.sellRefundEnergy}", style: const TextStyle(color: Colors.cyanAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                      const Text(
                        ")",
                        style: TextStyle(color: Colors.white24, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRequirementRow(BuildContext context, String text, bool isMet) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isMet
              ? Colors.greenAccent.withValues(alpha: 0.05)
              : Colors.redAccent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isMet
                ? Colors.greenAccent.withValues(alpha: 0.1)
                : Colors.redAccent.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            Icon(
              isMet ? Icons.check_circle_rounded : Icons.error_outline_rounded,
              color: isMet ? Colors.greenAccent : Colors.redAccent,
              size: 16,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: isMet ? Colors.white : Colors.redAccent.withValues(alpha: 0.9),
                  fontSize: 12,
                  fontWeight: isMet ? FontWeight.bold : FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
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
            style: const TextStyle(color: Colors.white38),
          ),
        );
        spans.add(
          const TextSpan(
            text: ' ➔ ',
            style: TextStyle(
              color: Colors.tealAccent,
              fontWeight: FontWeight.w900,
            ),
          ),
        );
        spans.add(
          TextSpan(
            text: parts[1],
            style: const TextStyle(
              color: Colors.tealAccent,
              fontWeight: FontWeight.w900,
            ),
          ),
        );
      } else {
        spans.add(
          TextSpan(
            text: line,
            style: const TextStyle(
              color: Colors.white70,
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
        style: GoogleFonts.quicksand(fontSize: 14, height: 1.5),
        children: spans,
      ),
    );
  }
}
