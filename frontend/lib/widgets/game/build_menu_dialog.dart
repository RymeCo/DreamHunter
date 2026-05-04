import 'package:flutter/material.dart';
import 'package:dreamhunter/widgets/liquid_glass_dialog.dart';
import 'package:dreamhunter/widgets/common_ui.dart';
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
        width: 360,
        height: 580,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          children: [
            // Header (Standardized with X button)
            const GameDialogHeader(title: "Architecture"),
            const SizedBox(height: 8),

            // Tabs (Modern, Underlined)
            TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorColor: Colors.amberAccent,
              indicatorWeight: 3,
              indicatorSize: TabBarIndicatorSize.label,
              labelColor: Colors.amberAccent,
              unselectedLabelColor: Colors.white24,
              dividerColor: Colors.white.withValues(alpha: 0.05),
              labelPadding: const EdgeInsets.symmetric(horizontal: 16),
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 12,
                letterSpacing: 1.2,
              ),
              tabs: const [
                Tab(text: "BASICS"),
                Tab(text: "ECONOMY"),
                Tab(text: "DEFENSE"),
                Tab(text: "SUPER"),
              ],
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
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        _buildConstructionItem(
          id: 'turret',
          name: 'Sentry Turret',
          description: 'Automated defense system. Fires rapid shots at nearby nightmares.',
          imagePath: 'assets/images/game/defenses/turret_sheet-32x32.png',
          coinCost: GameConfig.turretBuildCost,
          benefit: '10-90 DMG/s (Max 2 per Room)',
          productionIcon: Icons.security_rounded,
          glowColor: Colors.orangeAccent,
          isSpriteSheet: true,
        ),
      ],
    );
  }

  Widget _buildDefenseTab() {
    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        _buildConstructionItem(
          id: 'fridge',
          name: 'Sub-Zero Fridge',
          description: 'A heavy appliance that freezes the door, making it nearly unbreakable for a time.',
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
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        _buildConstructionItem(
          id: 'generator:1',
          name: 'Plasma Generator',
          description: 'Extracts energy from the dreamscape. Essential for high-tier upgrades.',
          imagePath: 'assets/images/game/economy/generator_lv1-32x32.png',
          coinCost: GameConfig.generatorUpgrades[0].cost.coins,
          energyCost: GameConfig.generatorUpgrades[0].cost.energy,
          benefit: 'Output: ${GameConfig.generatorUpgrades[0].income} Energy/s',
          productionIcon: Icons.bolt_rounded,
          glowColor: Colors.cyanAccent,
          isSpriteSheet: false,
        ),

        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
          child: Row(
            children: [
              Expanded(child: Divider(color: Colors.white10)),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12.0),
                child: Text(
                  "ORE MINES",
                  style: TextStyle(
                    color: Colors.white24,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ),
              Expanded(child: Divider(color: Colors.white10)),
            ],
          ),
        ),

        ...GameConfig.oreUpgrades.map((upg) {
          final String multiplierInfo = upg.globalMultiplier > 1.0
              ? ' (+${((upg.globalMultiplier - 1) * 100).toInt()}% ALL Income)'
              : '';

          return _buildConstructionItem(
            id: 'ore:${upg.level}',
            name: '${upg.material} Mine',
            description: 'Extracts precious minerals from the void. Multiplies coin generation.',
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
    required String description,
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
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.black26,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: canAfford
                  ? glowColor.withValues(alpha: 0.3)
                  : Colors.white.withValues(alpha: 0.05),
              width: 1.5,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Section: Image & Basic Info
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        glowColor.withValues(alpha: 0.05),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      // Item Image
                      Container(
                        width: 72,
                        height: 72,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black38,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                        child: _buildItemImage(imagePath, isSpriteSheet, canAfford && !isLocked),
                      ),
                      const SizedBox(width: 16),
                      // Name & Benefit
                      Expanded(
                        child: Column(
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
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  productionIcon,
                                  size: 14,
                                  color: canAfford && !isLocked
                                      ? glowColor
                                      : Colors.white24,
                                ),
                                const SizedBox(width: 6),
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
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Middle Section: Description
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                  child: Text(
                    description,
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      height: 1.4,
                    ),
                  ),
                ),

                // Bottom Section: Build Action
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      // Costs
                      Expanded(
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 4,
                          children: [
                            if (coinCost > 0)
                              _buildCostChip(
                                icon: Icons.monetization_on_rounded,
                                amount: coinCost,
                                color: Colors.amberAccent,
                                isAffordable: canAffordCoins,
                              ),
                            if (energyCost > 0)
                              _buildCostChip(
                                icon: Icons.bolt_rounded,
                                amount: energyCost,
                                color: Colors.cyanAccent,
                                isAffordable: canAffordEnergy,
                              ),
                            if (coinCost == 0 && energyCost == 0)
                              const Text(
                                "FREE CONSTRUCTION",
                                style: TextStyle(
                                  color: Colors.greenAccent,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1,
                                ),
                              ),
                          ],
                        ),
                      ),

                      // Buy Button
                      _buildBuyButton(
                        canAfford: canAfford,
                        glowColor: glowColor,
                        onTap: () {
                          if (!canAfford) {
                            HapticManager.instance.heavy();
                            return;
                          }

                          // Logic Gap Fix: Resource deduction is now handled internally by tryBuild(owner: game.player)
                          // We still play the sound and haptics here for UI feedback.
                          AudioManager.instance.playClick();
                          HapticManager.instance.medium();
                          widget.onBuildSelected(id);
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildItemImage(String path, bool isSpriteSheet, bool active) {
    if (!isSpriteSheet) {
      return Image.asset(
        path,
        filterQuality: FilterQuality.none,
        fit: BoxFit.contain,
        color: active ? null : Colors.black.withValues(alpha: 0.5),
        colorBlendMode: active ? null : BlendMode.dstIn,
      );
    }

    // Sprite Sheet Logic for Turret (Sheet is 3x9, 32x32 tiles)
    return ClipRect(
      child: OverflowBox(
        alignment: Alignment.topLeft,
        maxWidth: 56 * 3, // Scaled for the 72x72 container (8px padding)
        maxHeight: 56 * 9,
        child: Stack(
          children: [
             // Base (Col 0)
             Image.asset(
                path,
                width: 56 * 3,
                height: 56 * 9,
                filterQuality: FilterQuality.none,
                fit: BoxFit.fill,
                color: active ? null : Colors.black.withValues(alpha: 0.5),
                colorBlendMode: active ? null : BlendMode.dstIn,
              ),
              // Head (Col 1) - Transposed
              Transform.translate(
                offset: const Offset(-56 * 1, 0),
                child: Image.asset(
                  path,
                  width: 56 * 3,
                  height: 56 * 9,
                  filterQuality: FilterQuality.none,
                  fit: BoxFit.fill,
                  color: active ? null : Colors.black.withValues(alpha: 0.5),
                  colorBlendMode: active ? null : BlendMode.dstIn,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCostChip({
    required IconData icon,
    required int amount,
    required Color color,
    required bool isAffordable,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: isAffordable ? color : Colors.white24,
          size: 16,
        ),
        const SizedBox(width: 4),
        Text(
          "$amount",
          style: TextStyle(
            color: isAffordable ? Colors.white : Colors.white24,
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _buildBuyButton({
    required bool canAfford,
    required Color glowColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: canAfford ? glowColor : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          boxShadow: canAfford
              ? [
                  BoxShadow(
                    color: glowColor.withValues(alpha: 0.4),
                    blurRadius: 12,
                    spreadRadius: -2,
                  ),
                ]
              : null,
        ),
        child: Text(
          "BUILD",
          style: TextStyle(
            color: canAfford ? Colors.black : Colors.white24,
            fontWeight: FontWeight.w900,
            fontSize: 12,
            letterSpacing: 1.5,
          ),
        ),
      ),
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
