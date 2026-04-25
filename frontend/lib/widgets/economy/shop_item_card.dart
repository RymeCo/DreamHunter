import 'package:flutter/material.dart';
import 'package:dreamhunter/models/item_model.dart';
import 'package:dreamhunter/core/theme/app_theme.dart';

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
    final glassTheme =
        Theme.of(context).extension<GlassTheme>() ?? const GlassTheme();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: glassTheme.baseOpacity / 2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isLimitReached
              ? Colors.redAccent.withValues(alpha: glassTheme.borderAlpha * 1.5)
              : Colors.white.withValues(alpha: glassTheme.borderAlpha / 2),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // CONTENT
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // TYPE TAG
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getTypeColor(item.type).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      item.type.name.toUpperCase(),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: _getTypeColor(item.type),
                        fontSize: 8,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const Spacer(),
                  // IMAGE
                  Center(
                    child: Image.asset(
                      item.image,
                      height: 60,
                      errorBuilder: (c, e, s) {
                        return const Icon(
                          Icons.image_not_supported,
                          color: Colors.white10,
                          size: 40,
                        );
                      },
                    ),
                  ),
                  const Spacer(),
                  // NAME
                  Text(
                    item.name,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // PRICE
                  Row(
                    children: [
                      const Icon(
                        Icons.cloud_circle,
                        color: Colors.cyanAccent,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${item.price}',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Colors.cyanAccent,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // BUTTON
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isLimitReached ? null : onPurchase,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isLimitReached
                            ? Colors.white.withValues(
                                alpha: glassTheme.baseOpacity,
                              )
                            : Colors.amberAccent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        disabledBackgroundColor: Colors.white.withValues(
                          alpha: glassTheme.baseOpacity,
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        isLimitReached ? 'MAXED' : 'BUY',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: isLimitReached ? Colors.white24 : Colors.black,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // OWNED BADGE
            if (isOwned)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Colors.amberAccent,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    'x$ownedCount',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.black,
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
          ],
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
