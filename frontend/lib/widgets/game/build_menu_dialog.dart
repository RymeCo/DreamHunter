import 'package:flutter/material.dart';
import 'package:dreamhunter/widgets/liquid_glass_dialog.dart';
import 'package:dreamhunter/services/game/match_manager.dart';
import 'package:dreamhunter/services/core/audio_manager.dart';
import 'package:dreamhunter/services/core/haptic_manager.dart';
import 'package:dreamhunter/game/game_config.dart';

/// A tab-based menu for constructing new buildings in a building slot.
class BuildMenuDialog extends StatefulWidget {
  final Function(String buildingId) onBuildSelected;
  final bool hasFridge; // Added to check room restriction

  const BuildMenuDialog({
    super.key,
    required this.onBuildSelected,
    this.hasFridge = false,
  });

  /// Static helper to show the dialog
  static Future<void> show(
    BuildContext context, {
    required Function(String buildingId) onBuildSelected,
    bool hasFridge = false,
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
            child: BuildMenuDialog(
              onBuildSelected: onBuildSelected,
              hasFridge: hasFridge,
            ),
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
        width: MediaQuery.of(context).size.width * 0.9,
        height: 480,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            const Text(
              "Architecture",
              style: TextStyle(
                color: Colors.orangeAccent,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                shadows: [Shadow(color: Colors.black, blurRadius: 4)],
              ),
            ),
            const SizedBox(height: 12),

            // Tabs (Smaller, Scrollable)
            SizedBox(
              height: 32,
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                indicatorColor: Colors.amberAccent,
                indicatorWeight: 2,
                indicatorSize: TabBarIndicatorSize.label,
                labelColor: Colors.amberAccent,
                unselectedLabelColor: Colors.white24,
                dividerColor: Colors.transparent,
                labelPadding: const EdgeInsets.symmetric(horizontal: 12),
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
                tabs: const [
                  Tab(text: "Basics"),
                  Tab(text: "Economy"),
                  Tab(text: "Defense"),
                  Tab(text: "Super"),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                clipBehavior: Clip.none,
                children: [
                  _buildBasicsTab(),
                  _buildGenTab(),
                  _buildDefenseTab(),
                  _buildComingSoonTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBasicsTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        _buildConstructionItem(
          id: 'turret',
          name: 'Turret',
          imagePath: 'assets/images/game/defenses/turret_sheet-32x32.png',
          coinCost: GameConfig.turretBuildCost,
          benefit: 'Output: 10-90 DMG/s',
          productionIcon: Icons.security_rounded,
          glowColor: Colors.orangeAccent,
          isSpriteSheet: true,
        ),
      ],
    );
  }

  Widget _buildDefenseTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        _buildConstructionItem(
          id: 'fridge',
          name: 'Fridge',
          imagePath: 'assets/images/game/defenses/fridge-64x64.png',
          energyCost: GameConfig.fridgeBuildCost,
          benefit: 'Status: Freezes Door',
          productionIcon: Icons.ac_unit_rounded,
          glowColor: Colors.cyanAccent,
          isSpriteSheet: false,
          isLocked: widget.hasFridge,
          lockedLabel: "ONE PER ROOM",
        ),
      ],
    );
  }

  Widget _buildGenTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        // Generator (Level 1 only as requested)
        _buildConstructionItem(
          id: 'generator:1',
          name: 'Generator Lv.1',
          imagePath: 'assets/images/game/economy/generator_lv1-32x32.png',
          coinCost: GameConfig.generatorUpgrades[0].cost.coins,
          energyCost: GameConfig.generatorUpgrades[0].cost.energy,
          benefit: 'Output: ${GameConfig.generatorUpgrades[0].income} Energy/s',
          productionIcon: Icons.bolt_rounded,
          glowColor: Colors.cyanAccent,
          isSpriteSheet: false,
        ),

        const SizedBox(height: 16),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8.0),
          child: Divider(color: Colors.white10),
        ),
        const SizedBox(height: 16),

        // Ore Mines
        ...GameConfig.oreUpgrades.map((upg) {
          final String multiplierInfo = upg.globalMultiplier > 1.0
              ? ' (+${((upg.globalMultiplier - 1) * 100).toInt()}% ALL Income)'
              : '';

          return _buildConstructionItem(
            id: 'ore:${upg.level}',
            name: '${upg.material} Mine',
            imagePath: 'assets/images/game/economy/lv${upg.level}Ore-64x64.png',
            coinCost: upg.cost.coins,
            energyCost: upg.cost.energy,
            benefit: 'Output: ${upg.income} Coins/s$multiplierInfo',
            productionIcon: Icons.monetization_on_rounded,
            glowColor: Colors.amberAccent,
            isSpriteSheet: false,
          );
        }),
      ],
    );
  }

  Widget _buildConstructionItem({
    required String id,
    required String name,
    required String imagePath,
    int coinCost = 0,
    int energyCost = 0,
    required String benefit,
    required IconData productionIcon,
    required Color glowColor,
    required bool isSpriteSheet,
    bool isLocked = false,
    String? lockedLabel,
  }) {
    return ListenableBuilder(
      listenable: MatchManager.instance,
      builder: (context, child) {
        final bool canAffordCoins =
            MatchManager.instance.matchCoins >= coinCost;
        final bool canAffordEnergy =
            MatchManager.instance.matchEnergy >= energyCost;
        final bool canAfford = canAffordCoins && canAffordEnergy && !isLocked;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          height: 100, // Increased height for better spacing
          decoration: BoxDecoration(
            color: Colors.black45, // Slightly darker
            borderRadius: BorderRadius.circular(16), // Rounder
            border: Border.all(
              color: canAfford
                  ? glowColor.withValues(alpha: 0.3)
                  : Colors.white10,
              width: 1.5,
            ),
            boxShadow: canAfford
                ? [
                    BoxShadow(
                      color: glowColor.withValues(alpha: 0.1),
                      blurRadius: 10,
                      spreadRadius: -2,
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              // Icon Section (Large)
              Padding(
                padding: const EdgeInsets.all(10.0),
                child: Container(
                  width: 80,
                  height: 80,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black38,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: isSpriteSheet
                      ? Stack(
                          children: [
                            // Base Layer (Col 0)
                            ClipRect(
                              child: OverflowBox(
                                alignment: Alignment.topLeft,
                                maxWidth: 80 * 3,
                                maxHeight: 80 * 9,
                                child: Image.asset(
                                  imagePath,
                                  width: 80 * 3,
                                  height: 80 * 9,
                                  filterQuality: FilterQuality.none,
                                  fit: BoxFit.fill,
                                  color: canAfford && !isLocked
                                      ? null
                                      : Colors.black.withValues(alpha: 0.5),
                                  colorBlendMode: canAfford && !isLocked
                                      ? null
                                      : BlendMode.dstIn,
                                ),
                              ),
                            ),
                            // Head Layer (Col 1)
                            ClipRect(
                              child: OverflowBox(
                                alignment: Alignment.topLeft,
                                maxWidth: 80 * 3,
                                maxHeight: 80 * 9,
                                child: Transform.translate(
                                  offset: const Offset(-80 * 1, -80 * 0),
                                  child: Image.asset(
                                    imagePath,
                                    width: 80 * 3,
                                    height: 80 * 9,
                                    filterQuality: FilterQuality.none,
                                    fit: BoxFit.fill,
                                    color: canAfford && !isLocked
                                        ? null
                                        : Colors.black.withValues(alpha: 0.5),
                                    colorBlendMode: canAfford && !isLocked
                                        ? null
                                        : BlendMode.dstIn,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      : Image.asset(
                          imagePath,
                          filterQuality: FilterQuality.none,
                          fit: BoxFit.contain,
                          color: canAfford && !isLocked
                              ? null
                              : Colors.black.withValues(alpha: 0.5),
                          colorBlendMode: canAfford && !isLocked
                              ? null
                              : BlendMode.dstIn,
                        ),
                ),
              ),

              // Details Section
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          color: canAfford && !isLocked
                              ? Colors.white
                              : Colors.white38,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          shadows: canAfford
                              ? [
                                  Shadow(
                                    color: glowColor.withValues(alpha: 0.5),
                                    blurRadius: 8,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            productionIcon,
                            size: 14,
                            color: canAfford && !isLocked
                                ? glowColor
                                : Colors.white24,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              isLocked ? (lockedLabel ?? benefit) : benefit,
                              style: TextStyle(
                                color: isLocked
                                    ? Colors.redAccent
                                    : (canAfford
                                          ? Colors.white70
                                          : Colors.white24),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Cost / Buy Button Section
              GestureDetector(
                onTap: () {
                  if (!canAfford) {
                    HapticManager.instance.heavy();
                    return;
                  }

                  final success = MatchManager.instance.spendResources(
                    coins: coinCost,
                    energy: energyCost,
                  );
                  if (success) {
                    AudioManager.instance.playClick();
                    HapticManager.instance.medium();
                    widget.onBuildSelected(id);
                    Navigator.pop(context);
                  }
                },
                child: Container(
                  width: 90,
                  margin: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: canAfford
                        ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Colors.grey[800]!, Colors.grey[900]!],
                          )
                        : null,
                    color: canAfford ? null : Colors.black45,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: canAfford
                        ? [
                            BoxShadow(
                              color: Colors.black45,
                              offset: const Offset(0, 4),
                              blurRadius: 4,
                            ),
                          ]
                        : null,
                    border: Border.all(
                      color: canAfford ? Colors.white10 : Colors.transparent,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (coinCost > 0) ...[
                        const Icon(
                          Icons.monetization_on_rounded,
                          color: Colors.amberAccent,
                          size: 20,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$coinCost',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                      if (energyCost > 0) ...[
                        if (coinCost > 0) const SizedBox(height: 4),
                        const Icon(
                          Icons.bolt_rounded,
                          color: Colors.cyanAccent,
                          size: 20,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$energyCost',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                      if (coinCost == 0 && energyCost == 0)
                        const Text(
                          "FREE",
                          style: TextStyle(
                            color: Colors.greenAccent,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
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
