import 'package:flutter/material.dart';
import 'liquid_glass_dialog.dart';
import 'game_widgets.dart';

class ShopDialog extends StatefulWidget {
  const ShopDialog({super.key});

  @override
  State<ShopDialog> createState() => _ShopDialogState();
}

class _ShopDialogState extends State<ShopDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Hardcoded items specifying image location, name, description, and amount
  final List<Map<String, dynamic>> _gearItems = [
    {
      'image': 'assets/images/dashboard/signage.png',
      'name': 'Wooden Sword',
      'description': 'A basic sword made of sturdy oak.',
      'amount': 100,
    },
    {
      'image': 'assets/images/dashboard/signage.png',
      'name': 'Iron Shield',
      'description': 'Provides decent protection against physical hits.',
      'amount': 250,
    },
    {
      'image': 'assets/images/dashboard/signage.png',
      'name': 'Steel Armor',
      'description': 'Heavy plate armor for elite dream hunters.',
      'amount': 500,
    },
  ];

  final List<Map<String, dynamic>> _boostItems = [
    {
      'image': 'assets/images/dashboard/sandwich.png',
      'name': 'XP Booster (1h)',
      'description': 'Double your XP gain for one hour.',
      'amount': 50,
    },
    {
      'image': 'assets/images/dashboard/sandwich.png',
      'name': 'Coin Magnet',
      'description': 'Attracts nearby coins automatically.',
      'amount': 75,
    },
    {
      'image': 'assets/images/dashboard/sandwich.png',
      'name': 'Health Potion',
      'description': 'Restores 50 HP immediately.',
      'amount': 20,
    },
  ];

  final List<Map<String, dynamic>> _relicItems = [
    {
      'image': 'assets/images/dashboard/profile_logo.png',
      'name': 'Ancient Totem',
      'description': 'A mysterious relic from the old world.',
      'amount': 1000,
    },
    {
      'image': 'assets/images/dashboard/profile_logo.png',
      'name': 'Dragon Scale',
      'description': 'Impervious to heat and extremely durable.',
      'amount': 2500,
    },
    {
      'image': 'assets/images/dashboard/profile_logo.png',
      'name': 'Phoenix Feather',
      'description': 'Revives you once per dream session.',
      'amount': 5000,
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
        height: MediaQuery.of(context).size.height * 0.75,
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            const GameDialogHeader(
              title: 'DREAM SHOP',
              isCentered: true,
            ),
            TabBar(
              controller: _tabController,
              indicatorColor: Colors.amberAccent,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
              tabs: const [
                Tab(text: 'Gear'),
                Tab(text: 'Boosts'),
                Tab(text: 'Relics'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildItemGrid(_gearItems),
                  _buildItemGrid(_boostItems),
                  _buildItemGrid(_relicItems),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemGrid(List<Map<String, dynamic>> items) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.7,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                item['image'],
                width: 60,
                height: 60,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => 
                  const Icon(Icons.broken_image, color: Colors.white24, size: 60),
              ),
              const SizedBox(height: 12),
              Text(
                item['name'],
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 4),
              Text(
                item['description'],
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white54, fontSize: 10),
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.toll_rounded, color: Colors.amberAccent, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '${item['amount']}',
                    style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.w900, fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () {
                  // UI feedback only
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Purchased ${item['name']}! (Demo)'),
                      backgroundColor: Colors.blueAccent,
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent.withValues(alpha: 0.2),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 32),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('BUY', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }
}
