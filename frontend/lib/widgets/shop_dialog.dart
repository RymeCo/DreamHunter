import 'package:flutter/material.dart';
import '../services/offline_cache.dart';
import '../services/user_service.dart';
import 'custom_snackbar.dart';
import 'liquid_glass_dialog.dart';
import 'confirmation_dialog.dart';

class ShopDialog extends StatefulWidget {
  const ShopDialog({super.key});

  @override
  State<ShopDialog> createState() => _ShopDialogState();
}

class _ShopDialogState extends State<ShopDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final UserService _userService = UserService();
  List<_ShopItem> _allItem = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadItems();
  }

  Future<void> _loadItems() async {
    try {
      final cachedItems = await _userService.getCachedShopItems();
      if (cachedItems.isNotEmpty) {
        _allItem = cachedItems.map((item) => _ShopItem.fromMap(item)).toList();
      } else {
        // Hardcoded fallbacks if no cache
        _allItem = [
          _ShopItem('Health Potion', 'Restore 50 HP', 150, Icons.healing, 'Essential Gear'),
          _ShopItem('Energy Bar', 'Speed boost for 30s', 200, Icons.bolt, 'Essential Gear'),
          _ShopItem('Map Fragment', 'Reveal nearby ghosts', 100, Icons.map, 'Essential Gear'),
          _ShopItem('Ghost Veil', 'Invisibility for 10s', 500, Icons.visibility_off, 'Ethereal Boosts'),
          _ShopItem('Spirit Shield', 'Ignore next hit', 750, Icons.shield, 'Ethereal Boosts'),
          _ShopItem('Gold Magnet', 'Auto-collect coins', 600, Icons.attractions, 'Ethereal Boosts'),
          _ShopItem('Night Vision', 'Permanent dark sight', 5000, Icons.nights_stay, 'Arcane Relics'),
          _ShopItem('Dream Walker', 'Walk through walls', 10000, Icons.auto_fix_high, 'Arcane Relics'),
          _ShopItem('Soul Tether', 'Half respawn time', 3500, Icons.link, 'Arcane Relics'),
        ];
      }
    } catch (e) {
      debugPrint('Error loading shop items: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _buyItem(_ShopItem item) async {
    final Map<String, int> currency = await OfflineCache.getCurrency();
    final int currentDream = currency['dreamCoins'] ?? 0;

    if (currentDream < item.price) {
      if (mounted) {
        showCustomSnackBar(context, 'Insufficient Dream Coins!', type: SnackBarType.error);
      }
      return;
    }

    if (item.price > 500) {
      if (!mounted) return;
      final confirmed = await ConfirmationDialog.show(
        context,
        title: 'Confirm Purchase?',
        message: 'Spend ${item.price} coins on ${item.name}?',
        confirmLabel: 'BUY NOW',
      );
      if (confirmed != true) return;
    }

    await _processPurchase(item);
  }

  Future<void> _processPurchase(_ShopItem item) async {
    await OfflineCache.addTransaction(
      type: 'PURCHASE',
      itemId: item.name,
      dreamDelta: -item.price,
    );

    if (mounted) {
      showCustomSnackBar(context, 'Purchased ${item.name}!', type: SnackBarType.success);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Center(
      child: LiquidGlassDialog(
        width: MediaQuery.of(context).size.width * 0.85,
        height: MediaQuery.of(context).size.height * 0.7,
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'DREAM SHOP',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            
            // Tab Bar
            TabBar(
              controller: _tabController,
              indicatorColor: Colors.amberAccent,
              labelColor: Colors.amberAccent,
              unselectedLabelColor: Colors.white60,
              tabs: const [
                Tab(text: 'Essential Gear'),
                Tab(text: 'Ethereal Boosts'),
                Tab(text: 'Arcane Relics'),
              ],
            ),
            
            // Tab View
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildShopCategory(_allItem.where((i) => i.category == 'Essential Gear').toList()),
                  _buildShopCategory(_allItem.where((i) => i.category == 'Ethereal Boosts').toList()),
                  _buildShopCategory(_allItem.where((i) => i.category == 'Arcane Relics').toList()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShopCategory(List<_ShopItem> items) {
    if (items.isEmpty) {
      return const Center(child: Text('No items in this category', style: TextStyle(color: Colors.white38)));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        childAspectRatio: 0.75,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return InkWell(
          onTap: () => _buyItem(item),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(item.icon, size: 48, color: Colors.amberAccent),
                const SizedBox(height: 12),
                Text(
                  item.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.description,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.amberAccent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.toll_rounded, size: 14, color: Colors.amberAccent),
                      const SizedBox(width: 4),
                      Text(
                        item.price.toString(),
                        style: const TextStyle(
                          color: Colors.amberAccent,
                          fontWeight: FontWeight.bold,
                        ),
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
}

class _ShopItem {
  final String name;
  final String description;
  final int price;
  final IconData icon;
  final String category;

  _ShopItem(this.name, this.description, this.price, this.icon, this.category);

  factory _ShopItem.fromMap(Map<String, dynamic> map) {
    return _ShopItem(
      map['name'] ?? 'Unknown',
      map['description'] ?? '',
      (map['price'] as num?)?.toInt() ?? 0,
      _getIconData(map['icon']),
      map['category'] ?? 'Essential Gear',
    );
  }

  static IconData _getIconData(String? iconName) {
    switch (iconName) {
      case 'healing': return Icons.healing;
      case 'bolt': return Icons.bolt;
      case 'map': return Icons.map;
      case 'visibility_off': return Icons.visibility_off;
      case 'shield': return Icons.shield;
      case 'attractions': return Icons.attractions;
      case 'nights_stay': return Icons.nights_stay;
      case 'auto_fix_high': return Icons.auto_fix_high;
      case 'link': return Icons.link;
      default: return Icons.shopping_bag;
    }
  }
}
