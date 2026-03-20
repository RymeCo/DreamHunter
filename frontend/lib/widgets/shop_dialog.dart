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
        width: 450, // Slightly wider to avoid cramping
        height: 700, // Slightly taller
        child: Column(
          children: [
            // Header with Currency HUD
            Container(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Column(
                children: [
                  const Text(
                    'GHOST SHOP',
                    style: TextStyle(
                      color: Colors.amberAccent,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Real-time Currency HUD inside Shop
                  StreamBuilder<DocumentSnapshot>(
                    stream: _userService.getUserStats(),
                    builder: (context, snapshot) {
                      final userData = snapshot.data?.data() as Map<String, dynamic>? ?? {};
                      final coins = userData['ghostCoins'] ?? 0;
                      final tokens = userData['ghostTokens'] ?? 0;

                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildCurrencyDisplay(
                            icon: Icons.monetization_on_rounded,
                            value: '$coins',
                            color: Colors.amberAccent,
                          ),
                          const SizedBox(width: 16),
                          _buildCurrencyDisplay(
                            icon: Icons.stars_rounded,
                            value: '$tokens',
                            color: Colors.lightBlueAccent,
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            
            TabBar(
              controller: _tabController,
              indicatorColor: Colors.amberAccent,
              indicatorWeight: 3,
              labelColor: Colors.amberAccent,
              unselectedLabelColor: Colors.white38,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
              tabs: const [
                Tab(text: 'CHARACTERS'),
                Tab(text: 'POWER-UPS'),
                Tab(text: 'ITEMS'),
              ],
            ),
            const SizedBox(height: 8),
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
            // Close Button at bottom
            Padding(
              padding: const EdgeInsets.only(bottom: 16, top: 8),
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'CLOSE SHOP',
                  style: TextStyle(color: Colors.white38, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrencyDisplay({
    required IconData icon,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
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
                  style: const TextStyle(color: Colors.white38, fontSize: 16),
                ),
                const SizedBox(height: 8),
                const Text(
                  '(Placeholder: Add items in Admin App)',
                  style: TextStyle(color: Colors.white10, fontSize: 12),
                ),
              ],
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(20), // Increased padding to avoid cramping
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.78,
            crossAxisSpacing: 20,
            mainAxisSpacing: 20,
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
        borderRadius: BorderRadius.circular(16), // Softer corners
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _getIconForType(item['type']),
                size: 40,
                color: Colors.white24,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Text(
              item['name'] ?? 'Unknown',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white, 
                fontWeight: FontWeight.bold, 
                fontSize: 14,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 12, top: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isToken ? Icons.stars_rounded : Icons.monetization_on_rounded,
                  size: 16,
                  color: isToken ? Colors.lightBlueAccent : Colors.amberAccent,
                ),
                const SizedBox(width: 6),
                Text(
                  '${item['price'] ?? 0}',
                  style: TextStyle(
                    color: isToken ? Colors.lightBlueAccent : Colors.amberAccent,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => showCustomSnackBar(context, 'Purchase system coming soon!'),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: const Text(
                  'GET',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white, 
                    fontWeight: FontWeight.w900, 
                    fontSize: 13,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconForType(String? type) {
    switch (type) {
      case 'character': return Icons.person_rounded;
      case 'powerup': return Icons.bolt_rounded;
      case 'item': return Icons.category_rounded;
      default: return Icons.help_outline_rounded;
    }
  }
}
