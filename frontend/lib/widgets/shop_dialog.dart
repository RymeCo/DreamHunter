import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dreamhunter/services/user_service.dart';
import 'package:dreamhunter/widgets/liquid_glass_dialog.dart';
import 'package:dreamhunter/widgets/custom_snackbar.dart';

class ShopDialog extends StatefulWidget {
  const ShopDialog({super.key});

  @override
  State<ShopDialog> createState() => _ShopDialogState();
}

class _ShopDialogState extends State<ShopDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final UserService _userService = UserService();

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
        width: 400,
        height: 650,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'GHOST SHOP',
                style: TextStyle(
                  color: Colors.amberAccent,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
            ),
            TabBar(
              controller: _tabController,
              indicatorColor: Colors.amberAccent,
              labelColor: Colors.amberAccent,
              unselectedLabelColor: Colors.white38,
              tabs: const [
                Tab(text: 'CHARACTERS'),
                Tab(text: 'POWER-UPS'),
                Tab(text: 'ITEMS'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildShopCategory('character'),
                  _buildShopCategory('powerup'),
                  _buildShopCategory('item'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShopCategory(String type) {
    return StreamBuilder<QuerySnapshot>(
      stream: _userService.getShopItems(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.amberAccent));
        }

        final allItems = snapshot.data?.docs ?? [];
        final filteredItems = allItems.where((doc) => doc['type'] == type).toList();

        if (filteredItems.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shopping_basket_outlined, size: 64, color: Colors.white.withValues(alpha: 0.1)),
                const SizedBox(height: 16),
                Text(
                  'No ${type}s available yet.',
                  style: const TextStyle(color: Colors.white38),
                ),
                const SizedBox(height: 8),
                const Text(
                  '(Placeholder: Add items in Admin App)',
                  style: TextStyle(color: Colors.white10, fontSize: 10),
                ),
              ],
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.75,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: filteredItems.length,
          itemBuilder: (context, index) {
            final item = filteredItems[index].data() as Map<String, dynamic>;
            return _buildShopItemCard(item);
          },
        );
      },
    );
  }

  Widget _buildShopItemCard(Map<String, dynamic> item) {
    final bool isToken = item['currencyType'] == 'tokens';
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Icon(
                _getIconForType(item['type']),
                size: 48,
                color: Colors.white24,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              item['name'] ?? 'Unknown',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isToken ? Icons.stars_rounded : Icons.monetization_on_rounded,
                  size: 14,
                  color: isToken ? Colors.lightBlueAccent : Colors.amberAccent,
                ),
                const SizedBox(width: 4),
                Text(
                  '${item['price'] ?? 0}',
                  style: TextStyle(
                    color: isToken ? Colors.lightBlueAccent : Colors.amberAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: () => showCustomSnackBar(context, 'Purchase system coming soon!'),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: const Text(
                'BUY',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconForType(String? type) {
    switch (type) {
      case 'character': return Icons.person_outline_rounded;
      case 'powerup': return Icons.flash_on_rounded;
      case 'item': return Icons.inventory_2_outlined;
      default: return Icons.help_outline_rounded;
    }
  }
}
