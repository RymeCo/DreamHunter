import 'package:flutter/material.dart';
import 'package:dreamhunter/widgets/liquid_glass_dialog.dart';
import 'package:dreamhunter/widgets/common_ui.dart';
import 'package:dreamhunter/widgets/glass_button.dart';
import 'package:dreamhunter/widgets/confirmation_dialog.dart';
import 'package:dreamhunter/widgets/economy/insufficient_funds_dialog.dart';
import 'package:dreamhunter/widgets/custom_snackbar.dart';
import 'package:dreamhunter/services/economy/shop_manager.dart';
import 'package:dreamhunter/services/economy/wallet_manager.dart';
import 'package:dreamhunter/data/item_registry.dart';
import 'package:dreamhunter/models/item_model.dart';
import 'package:dreamhunter/services/core/haptic_manager.dart';
import 'package:dreamhunter/widgets/game/character_portrait.dart';

class CharacterSelectionDialog extends StatefulWidget {
  const CharacterSelectionDialog({super.key});

  @override
  State<CharacterSelectionDialog> createState() => _CharacterSelectionDialogState();
}

class _CharacterSelectionDialogState extends State<CharacterSelectionDialog> {
  final ShopManager _shopManager = ShopManager.instance;
  final WalletManager _walletManager = WalletManager.instance;

  Future<void> _handlePurchase(Item character) async {
    final currentCoins = _walletManager.dreamCoins;

    if (currentCoins < character.price) {
      if (mounted) {
        InsufficientFundsDialog.show(context, needed: character.price, current: currentCoins);
      }
      return;
    }

    final confirmed = await ConfirmationDialog.show(
      context,
      title: 'UNLOCK HUNTER',
      message: 'Unlock ${character.name} for ${character.price} coins?',
    );

    if (confirmed == true && mounted) {
      final success = await _walletManager.updateBalance(coinsDelta: -character.price);
      if (success) {
        _shopManager.purchaseItemLocally(character.id);
        _shopManager.selectCharacter(character.id);
        HapticManager.instance.medium();
        if (mounted) showCustomSnackBar(context, '${character.name} Unlocked!', type: SnackBarType.success);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final characters = ItemRegistry.getByType(ItemType.character);

    return ListenableBuilder(
      listenable: Listenable.merge([_shopManager, _walletManager]),
      builder: (context, child) {
        return Center(
          child: LiquidGlassDialog(
            width: 330, // More compact
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const GameDialogHeader(
                  title: 'SELECT HUNTER',
                  isCentered: true,
                ),
                const SizedBox(height: 16),
                
                // Compact 3-Column Grid
                Flexible(
                  child: GridView.builder(
                    shrinkWrap: true,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 0.65, // Slightly taller for text
                    ),
                    itemCount: characters.length,
                    itemBuilder: (context, index) {
                      final character = characters[index];
                      final bool isOwned = _shopManager.isOwned(character.id);
                      final bool isSelected = _shopManager.selectedCharacterId == character.id;

                      return _buildCompactCharacterCard(character, isOwned, isSelected);
                    },
                  ),
                ),
                
                const SizedBox(height: 20),
                GlassButton(
                  label: 'CLOSE',
                  width: double.infinity,
                  height: 40,
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCompactCharacterCard(Item character, bool isOwned, bool isSelected) {
    return GestureDetector(
      onTap: () {
        if (isOwned) {
          if (!isSelected) {
            _shopManager.selectCharacter(character.id);
            HapticManager.instance.light();
          }
        } else {
          _handlePurchase(character);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: isSelected 
              ? Colors.cyanAccent.withValues(alpha: 0.15) 
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected 
                ? Colors.cyanAccent 
                : Colors.white.withValues(alpha: 0.1),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 8),
            CharacterPortrait(
              imagePath: character.image,
              size: 50,
              isGray: false, // User feedback: Remove graying
            ),
            const SizedBox(height: 6),
            Text(
              character.name.split(' ')[0], 
              style: TextStyle(
                color: isOwned ? Colors.white : Colors.white70,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 11,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            if (!isOwned) ...[
              Text(
                'LOCKED',
                style: TextStyle(
                  color: Colors.redAccent.withValues(alpha: 0.7),
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.cloud_circle, size: 10, color: Colors.amberAccent),
                  const SizedBox(width: 2),
                  Text(
                    '${character.price}',
                    style: const TextStyle(color: Colors.amberAccent, fontSize: 9, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ] else if (isSelected)
              const Icon(Icons.check_circle, size: 12, color: Colors.cyanAccent),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
