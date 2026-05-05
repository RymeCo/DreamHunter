import 'package:flutter/material.dart';
import 'package:dreamhunter/widgets/common_ui.dart';
import 'package:dreamhunter/widgets/confirmation_dialog.dart';
import 'package:dreamhunter/widgets/economy/insufficient_funds_dialog.dart';
import 'package:dreamhunter/widgets/custom_snackbar.dart';
import 'package:dreamhunter/services/economy/shop_manager.dart';
import 'package:dreamhunter/services/economy/wallet_manager.dart';
import 'package:dreamhunter/models/item_model.dart';
import 'package:dreamhunter/widgets/economy/shop_item_card.dart';

class ShopDialog extends StatefulWidget {
  final WalletManager controller;

  const ShopDialog({super.key, required this.controller});

  @override
  State<ShopDialog> createState() => _ShopDialogState();
}

class _ShopDialogState extends State<ShopDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ShopManager _shopService = ShopManager.instance;

  @override
  void initState() {
    super.initState();
    // Synchronously initialize based on hardcoded items
    final categories = _shopService.getItemsByCategory().keys.toList();
    _tabController = TabController(length: categories.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _handlePurchase(Item item) async {
    final currentCoins = widget.controller.dreamCoins;

    // 1. Check item limit
    final ownedCount = _shopService.getOwnedCount(item.id);
    if (ownedCount >= item.maxLimit) {
      if (mounted) {
        showCustomSnackBar(
          context,
          'LIMIT REACHED: Cannot own more ${item.name}!',
          type: SnackBarType.warning,
        );
      }
      return;
    }

    // 2. Check affordability
    if (currentCoins < item.price) {
      if (mounted) {
        InsufficientFundsDialog.show(
          context,
          needed: item.price,
          current: currentCoins,
        );
      }
      return;
    }

    // 3. Confirm purchase
    final confirmed = await ConfirmationDialog.show(
      context,
      title: 'CONFIRM PURCHASE',
      message: 'Do you want to buy ${item.name} for ${item.price} coins?',
    );

    if (confirmed == true && mounted) {
      // 4. Update UI only (Hardcoded path)
      _shopService.purchaseItemLocally(item.id);
      await widget.controller.updateBalance(coinsDelta: -item.price);

      if (mounted) {
        showCustomSnackBar(
          context,
          'PURCHASED: ${item.name} is now yours!',
          type: SnackBarType.success,
        );
        setState(() {}); // Refresh list
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StandardGlassPage(
      title: 'DREAM SHOP',
      isCentered: true,
      isFullScreen: true,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          TabBar(
            controller: _tabController,
            indicatorColor: Colors.amberAccent,
            isScrollable: false,
            labelColor: Colors.amberAccent,
            unselectedLabelColor: Colors.white.withValues(alpha: 0.38),
            labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
            unselectedLabelStyle: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontSize: 14),
            tabs: _shopService
                .getItemsByCategory()
                .keys
                .map((cat) => Tab(text: cat.toUpperCase()))
                .toList(),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: _shopService.getItemsByCategory().entries.map((entry) {
                if (entry.value.isEmpty) {
                  return _buildEmptyState(entry.key);
                }
                return _buildItemList(entry.value);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String category) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            category == 'Gear' ? Icons.handyman_rounded : Icons.bolt_rounded,
            size: 64,
            color: Colors.white.withValues(alpha: 0.05),
          ),
          const SizedBox(height: 16),
          Text(
            'NO ${category.toUpperCase()} AVAILABLE',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white24,
              letterSpacing: 2,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Check back after the next update!',
            style: TextStyle(color: Colors.white12, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildItemList(List<Item> items) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final ownedCount = _shopService.getOwnedCount(item.id);
        final isOwned = ownedCount > 0;
        final isLimitReached = ownedCount >= item.maxLimit;

        return ShopItemCard(
          item: item,
          isOwned: isOwned,
          isLimitReached: isLimitReached,
          ownedCount: ownedCount,
          onPurchase: () => _handlePurchase(item),
        );
      },
    );
  }
}
