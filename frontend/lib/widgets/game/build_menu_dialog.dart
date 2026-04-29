import 'package:flutter/material.dart';
import 'package:dreamhunter/widgets/liquid_glass_dialog.dart';
import 'package:dreamhunter/widgets/common_ui.dart';
import 'package:dreamhunter/widgets/glass_button.dart';
import 'package:dreamhunter/services/game/match_manager.dart';
import 'package:dreamhunter/services/core/audio_manager.dart';
import 'package:dreamhunter/services/core/haptic_manager.dart';

/// A tab-based menu for constructing new buildings in a building slot.
class BuildMenuDialog extends StatefulWidget {
  final Function(String buildingId) onBuildSelected;

  const BuildMenuDialog({super.key, required this.onBuildSelected});

  /// Static helper to show the dialog
  static Future<void> show(
    BuildContext context, {
    required Function(String buildingId) onBuildSelected,
  }) async {
    await showGeneralDialog<void>(
      context: context,
      barrierLabel: "BuildMenuDialog",
      barrierDismissible: true,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          child: FadeTransition(
            opacity: animation,
            child: BuildMenuDialog(onBuildSelected: onBuildSelected),
          ),
        );
      },
    );
  }

  @override
  State<BuildMenuDialog> createState() => _BuildMenuDialogState();
}

class _BuildMenuDialogState extends State<BuildMenuDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: LiquidGlassDialog(
        width: MediaQuery.of(context).size.width * 0.85,
        height: 400,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          children: [
            const GameDialogHeader(title: "CONSTRUCT"),

            // Tabs
            TabBar(
              controller: _tabController,
              indicatorColor: Colors.amberAccent,
              indicatorWeight: 3,
              indicatorSize: TabBarIndicatorSize.label,
              labelColor: Colors.amberAccent,
              unselectedLabelColor: Colors.white24,
              dividerColor: Colors.transparent,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 10,
                letterSpacing: 1,
              ),
              tabs: const [
                Tab(text: "OFFENSE"),
                Tab(text: "DEFENSE"),
                Tab(text: "SUPER"),
                Tab(text: "GEN"),
              ],
            ),
            const SizedBox(height: 24),

            // Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                clipBehavior: Clip.none,
                children: [
                  _buildOffenseTab(),
                  _buildComingSoonTab(),
                  _buildComingSoonTab(),
                  _buildGenTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOffenseTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 4),
      clipBehavior: Clip.none,
      children: [
        _buildConstructionItem(
          id: 'turret',
          name: 'Turret',
          imagePath: 'assets/images/game/defenses/turret_sheet-32x32.png',
          cost: 100,
          benefit: 'Auto-fires at ghosts',
          productionIcon: Icons.security_rounded,
          glowColor: Colors.orangeAccent,
          isSpriteSheet: true,
        ),
      ],
    );
  }

  Widget _buildGenTab() {
    return ListView(
      padding: const EdgeInsets.only(top: 24, bottom: 12, left: 4, right: 4),
      clipBehavior: Clip.none,
      children: [
        _buildConstructionItem(
          id: 'generator',
          name: 'Generator',
          imagePath: 'assets/images/game/economy/generator_lv1-32x32.png',
          cost: 200,
          benefit: '+1 Energy/Sec',
          productionIcon: Icons.bolt_rounded,
          glowColor: Colors.cyanAccent,
          isSpriteSheet: false,
        ),
      ],
    );
  }

  Widget _buildConstructionItem({
    required String id,
    required String name,
    required String imagePath,
    required int cost,
    required String benefit,
    required IconData productionIcon,
    required Color glowColor,
    required bool isSpriteSheet,
  }) {
    return ListenableBuilder(
      listenable: MatchManager.instance,
      builder: (context, child) {
        final bool canAfford = MatchManager.instance.matchCoins >= cost;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          child: GlassButton(
            onTap: () {
              if (!canAfford) {
                HapticManager.instance.heavy();
                return;
              }

              final success = MatchManager.instance.spendMatchCoins(cost);
              if (success) {
                AudioManager.instance.playClick();
                HapticManager.instance.medium();
                widget.onBuildSelected(id);
                Navigator.pop(context);
              }
            },
            glowColor: canAfford ? glowColor : Colors.white10,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              child: Row(
                children: [
                  // Building Preview with Production Badge
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: canAfford
                                ? glowColor.withValues(alpha: 0.3)
                                : Colors.white10,
                          ),
                        ),
                        child: isSpriteSheet
                            ? ClipRect(
                                child: OverflowBox(
                                  alignment: Alignment.topLeft,
                                  maxWidth: 56 * 3, // 3 columns
                                  maxHeight: 56 * 9, // 9 rows
                                  child: Transform.translate(
                                    // Level 1 = Row 0, Column 1 (Head)
                                    offset: const Offset(-56 * 1, -56 * 0),
                                    child: Image.asset(
                                      imagePath,
                                      filterQuality: FilterQuality.none,
                                      width: 56 * 3,
                                      fit: BoxFit.fill,
                                      color: canAfford
                                          ? null
                                          : Colors.black.withValues(alpha: 0.5),
                                      colorBlendMode: canAfford
                                          ? null
                                          : BlendMode.dstIn,
                                    ),
                                  ),
                                ),
                              )
                            : Image.asset(
                                imagePath,
                                filterQuality:
                                    FilterQuality.none, // Sharp pixels
                                fit: BoxFit.contain,
                                color: canAfford
                                    ? null
                                    : Colors.black.withValues(alpha: 0.5),
                                colorBlendMode: canAfford
                                    ? null
                                    : BlendMode.dstIn,
                              ),
                      ),
                      // Production Badge
                      Positioned(
                        right: -4,
                        bottom: -4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: canAfford ? glowColor : Colors.grey[900],
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: (canAfford ? glowColor : Colors.black)
                                    .withValues(alpha: 0.5),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: Icon(
                            productionIcon,
                            color: canAfford ? Colors.black : Colors.white24,
                            size: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),

                  // Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            color: canAfford ? Colors.white : Colors.white38,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color:
                                (canAfford ? Colors.greenAccent : Colors.white)
                                    .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            benefit,
                            style: TextStyle(
                              color: canAfford
                                  ? Colors.greenAccent
                                  : Colors.white10,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Cost
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: (canAfford ? Colors.amberAccent : Colors.white10)
                            .withValues(alpha: 0.1),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.monetization_on_rounded,
                          color: canAfford
                              ? Colors.amberAccent
                              : Colors.white24,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$cost',
                          style: TextStyle(
                            color: canAfford
                                ? Colors.amberAccent
                                : Colors.white24,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
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

  Widget _buildComingSoonTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.construction_rounded,
            color: Colors.white.withValues(alpha: 0.1),
            size: 48,
          ),
          const SizedBox(height: 12),
          Text(
            "COMING SOON",
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.2),
              fontWeight: FontWeight.w900,
              fontSize: 14,
              letterSpacing: 4,
            ),
          ),
        ],
      ),
    );
  }
}
