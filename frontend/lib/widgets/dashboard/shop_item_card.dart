import 'package:flutter/material.dart';
import '../../models/shop_item.dart';

class ShopItemCard extends StatelessWidget {
  final ShopItem item;
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
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isLimitReached 
            ? Colors.orangeAccent.withValues(alpha: 0.3) 
            : (isOwned ? Colors.greenAccent.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.1)),
        ),
        boxShadow: isLimitReached ? [
          BoxShadow(
            color: Colors.orangeAccent.withValues(alpha: 0.1),
            blurRadius: 10,
            spreadRadius: 1,
          )
        ] : (isOwned ? [
          BoxShadow(
            color: Colors.greenAccent.withValues(alpha: 0.1),
            blurRadius: 10,
            spreadRadius: 1,
          )
        ] : []),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Item Image with subtle glow
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _getTypeColor(item.type).withValues(alpha: 0.2),
                      blurRadius: 15,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
              Image.asset(
                item.image,
                width: 60,
                height: 60,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => 
                  const Icon(Icons.broken_image, color: Colors.white24, size: 60),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Name
          Text(
            item.name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white, 
              fontWeight: FontWeight.bold, 
              fontSize: 14,
            ),
          ),
          
          const SizedBox(height: 4),
          
          // Description
          Text(
            item.description,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white54, fontSize: 10),
          ),
          
          const Spacer(),
          
          // Price or Status
          if (isLimitReached)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orangeAccent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.block, color: Colors.orangeAccent, size: 14),
                  SizedBox(width: 4),
                  Text(
                    'LIMIT REACHED',
                    style: TextStyle(
                      color: Colors.orangeAccent, 
                      fontWeight: FontWeight.bold, 
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            )
          else
            Column(
              children: [
                if (item.maxLimit > 1)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4.0),
                    child: Text(
                      'Owned: $ownedCount/${item.maxLimit}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.toll_rounded, color: Colors.amberAccent, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '${item.price}',
                      style: const TextStyle(
                        color: Colors.amberAccent, 
                        fontWeight: FontWeight.w900, 
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: onPurchase,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent.withValues(alpha: 0.3),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 32),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                    side: BorderSide(color: Colors.blueAccent.withValues(alpha: 0.5)),
                  ),
                  child: const Text(
                    'BUY', 
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Color _getTypeColor(ShopItemType type) {
    switch (type) {
      case ShopItemType.gear:
        return Colors.blueAccent;
      case ShopItemType.boost:
        return Colors.orangeAccent;
      case ShopItemType.relic:
        return Colors.purpleAccent;
    }
  }
}
