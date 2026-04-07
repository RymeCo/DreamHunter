import 'package:flutter/material.dart';
import '../game/haunted_dorm_game.dart';
import 'liquid_glass_dialog.dart';

class BuildMenu extends StatefulWidget {
  final HauntedDormGame game;
  const BuildMenu({super.key, required this.game});

  @override
  State<BuildMenu> createState() => _BuildMenuState();
}

class _BuildMenuState extends State<BuildMenu> with SingleTickerProviderStateMixin {
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
        width: 320,
        height: 400,
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.white10)),
              ),
              child: const Text(
                'BUILD MODE',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
            ),
            TabBar(
              controller: _tabController,
              isScrollable: false,
              indicatorColor: Colors.deepPurpleAccent,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white38,
              labelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
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
                  const Center(child: Text('Special Tab', style: TextStyle(color: Colors.white24))),
                  const Center(child: Text('Premium Tab', style: TextStyle(color: Colors.white24))),
                ],
              ),
            ),
            TextButton(
              onPressed: () => widget.game.overlays.remove('BuildMenu'),
              child: const Text('CLOSE', style: TextStyle(color: Colors.white38)),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildDefenseTab() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
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
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
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
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: canAfford ? Colors.white12 : Colors.redAccent.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            Text(
              name,
              style: const TextStyle(color: Colors.white70, fontSize: 10),
            ),
            Text(
              '⚡ $cost',
              style: TextStyle(
                color: canAfford ? Colors.blueAccent : Colors.redAccent,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
