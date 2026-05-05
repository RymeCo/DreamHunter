import 'package:flutter/material.dart';
import 'package:dreamhunter/models/item_model.dart';

class ShopItemCard extends StatelessWidget {
  final Item item;
  final bool isOwned;
  final bool isLimitReached;
  final int ownedCount;
  final VoidCallback onPurchase;

  const ShopItemCard({
    super.key,
    required this.item,
    required this.isOwned,
    required this.isLimitReached,
    required this.ownedCount,
    required this.onPurchase,
  });

  @override
  Widget build(BuildContext context) {
    final glowColor = _getTypeColor(item.type);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isLimitReached
              ? Colors.redAccent.withValues(alpha: 0.3)
              : glowColor.withValues(alpha: 0.3),
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
                    child: Image.asset(
                      item.image,
                      fit: BoxFit.contain,
                      errorBuilder: (c, e, s) => const Icon(
                        Icons.image_not_supported,
                        color: Colors.white10,
                        size: 32,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Name & Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: glowColor.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                item.type.name.toUpperCase(),
                                style: TextStyle(
                                  color: glowColor,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isLimitReached
                                  ? 'MAX LIMIT REACHED'
                                  : 'OWNED: $ownedCount / ${item.maxLimit}',
                              style: TextStyle(
                                color: isLimitReached
                                    ? Colors.redAccent
                                    : Colors.white38,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
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
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 4.0,
              ),
              child: Text(
                item.description,
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  height: 1.4,
                ),
              ),
            ),

            // Bottom Section: Purchase Action
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  // Costs
                  Expanded(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.toll_rounded,
                          color: Colors.amberAccent,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          "${item.price}",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Buy Button
                  _buildBuyButton(
                    isLimitReached: isLimitReached,
                    glowColor: glowColor,
                    onTap: onPurchase,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBuyButton({
    required bool isLimitReached,
    required Color glowColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: isLimitReached ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isLimitReached
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.amberAccent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: !isLimitReached
              ? [
                  BoxShadow(
                    color: Colors.amberAccent.withValues(alpha: 0.4),
                    blurRadius: 12,
                    spreadRadius: -2,
                  ),
                ]
              : null,
        ),
        child: Text(
          isLimitReached ? "MAXED" : "BUY",
          style: TextStyle(
            color: isLimitReached ? Colors.white24 : Colors.black,
            fontWeight: FontWeight.w900,
            fontSize: 12,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }

  Color _getTypeColor(ItemType type) {
    switch (type) {
      case ItemType.gear:
        return Colors.orangeAccent;
      case ItemType.boost:
        return Colors.greenAccent;
      case ItemType.relic:
        return Colors.purpleAccent;
      case ItemType.character:
        return Colors.cyanAccent;
    }
  }
}
