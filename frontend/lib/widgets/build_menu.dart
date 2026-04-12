import 'package:flutter/material.dart';
import '../game/haunted_dorm_game.dart';
import 'liquid_glass_dialog.dart';

class BuildMenu extends StatefulWidget {
  final HauntedDormGame game;
  const BuildMenu({super.key, required this.game});

  @override
  State<BuildMenu> createState() => _BuildMenuState();
}

class _BuildMenuState extends State<BuildMenu>
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
    return Stack(
      children: [
        // Click outside to close
        GestureDetector(
          onTap: () => widget.game.overlays.remove('BuildMenu'),
          child: Container(
            color: Colors.black26, // Dim background
          ),
        ),
        Center(
          child: LiquidGlassDialog(
            width: 380, // WIDER
            height: 600, // TALLER
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: Colors.white10)),
                  ),
                  child: const Text(
                    'BUILDING MODE',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                      fontSize: 20,
                    ),
                  ),
                ),
                TabBar(
                  controller: _tabController,
                  isScrollable: false,
                  indicatorColor: Colors.deepPurpleAccent,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white38,
                  labelStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                  tabs: const [
                    Tab(text: 'DEFENSE'),
                    Tab(text: 'GEN'),
                    Tab(text: 'SPEC'),
                    Tab(text: 'PREM'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildDefenseTab(),
                      _buildGeneratorTab(),
                      const Center(
                        child: Text(
                          'Special',
                          style: TextStyle(color: Colors.white24),
                        ),
                      ),
                      const Center(
                        child: Text(
                          'Premium',
                          style: TextStyle(color: Colors.white24),
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => widget.game.overlays.remove('BuildMenu'),
                  child: const Text(
                    'CLOSE',
                    style: TextStyle(color: Colors.white38),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDefenseTab() {
    return GridView.builder(
      padding: const EdgeInsets.all(24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.75,
      ),
      itemCount: 1,
      itemBuilder: (context, index) {
        return _buildBuildItem(
          name: 'Turret Lv1',
          cost: 10,
          emoji: '🏹',
          onTap: () {
            widget.game.buildTurret();
            widget.game.overlays.remove('BuildMenu');
          },
        );
      },
    );
  }

  Widget _buildGeneratorTab() {
    return GridView.builder(
      padding: const EdgeInsets.all(24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.75,
      ),
      itemCount: 1,
      itemBuilder: (context, index) {
        return _buildBuildItem(
          name: 'Wood Gen',
          cost: 50,
          emoji: '🪵',
          onTap: () {
            widget.game.buildGenerator(1);
            widget.game.overlays.remove('BuildMenu');
          },
        );
      },
    );
  }

  Widget _buildBuildItem({
    required String name,
    required int cost,
    required String emoji,
    required VoidCallback onTap,
  }) {
    final bool canAfford = widget.game.player.energy >= cost;

    return GestureDetector(
      onTap: canAfford ? onTap : null,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: canAfford
                ? Colors.white12
                : Colors.redAccent.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 32)),
            const SizedBox(height: 8),
            Text(
              name,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '⚡ $cost',
              style: TextStyle(
                color: canAfford ? Colors.blueAccent : Colors.redAccent,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
