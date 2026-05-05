import 'package:flutter/material.dart';
import 'package:dreamhunter/widgets/liquid_glass_dialog.dart';
import 'package:dreamhunter/widgets/common_ui.dart';
import 'package:dreamhunter/widgets/glass_button.dart';
import 'package:dreamhunter/services/economy/wallet_manager.dart';
import 'package:dreamhunter/widgets/custom_snackbar.dart';

class PurchaseDialogContent extends StatelessWidget {
  final VoidCallback onBackTap;

  const PurchaseDialogContent({super.key, required this.onBackTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: LiquidGlassDialog(
        width: 350,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const GameDialogHeader(
              title: 'Hell Stones',
              titleColor: Colors.redAccent,
            ),
            const SizedBox(height: 24),
            const Icon(
              Icons.diamond_rounded,
              color: Colors.redAccent,
              size: 80,
            ),
            const SizedBox(height: 16),
            const Text(
              'Purchase premium stones to unlock exclusive characters and items!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 32),
            GlassButton(
              onTap: onBackTap,
              label: 'BACK TO GAME',
              color: Colors.redAccent.withValues(alpha: 0.2),
              borderColor: Colors.redAccent.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            const Text(
              '(In-game purchases coming soon)',
              style: TextStyle(color: Colors.white24, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

class ExchangeDialogContent extends StatefulWidget {
  final VoidCallback onBackTap;
  final WalletManager controller;

  const ExchangeDialogContent({
    super.key,
    required this.onBackTap,
    required this.controller,
  });

  @override
  State<ExchangeDialogContent> createState() => _ExchangeDialogContentState();
}

class _ExchangeDialogContentState extends State<ExchangeDialogContent> {
  int _amountToExchange = 1;

  void _increment() {
    if (_amountToExchange < widget.controller.hellStones) {
      setState(() => _amountToExchange++);
    }
  }

  void _decrement() {
    if (_amountToExchange > 1) {
      setState(() => _amountToExchange--);
    }
  }

  void _setMax() {
    setState(() => _amountToExchange = widget.controller.hellStones);
  }

  Future<void> _performExchange() async {
    final success = await widget.controller.exchangeHellStones(
      _amountToExchange,
    );
    if (mounted) {
      if (success) {
        showCustomSnackBar(
          context,
          'EXCHANGED: +${_amountToExchange * 100} Coins received!',
          type: SnackBarType.success,
        );
        setState(() => _amountToExchange = 1);
      } else {
        showCustomSnackBar(
          context,
          'ERROR: Insufficient Hell Stones.',
          type: SnackBarType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: LiquidGlassDialog(
        width: 350,
        padding: const EdgeInsets.all(24),
        child: ListenableBuilder(
          listenable: widget.controller,
          builder: (context, child) {
            final canExchange =
                widget.controller.hellStones >= _amountToExchange &&
                _amountToExchange > 0;

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const GameDialogHeader(
                  title: 'Exchange',
                  titleColor: Colors.amberAccent,
                ),
                const SizedBox(height: 16),
                const Icon(
                  Icons.toll_rounded,
                  color: Colors.amberAccent,
                  size: 60,
                ),
                const SizedBox(height: 12),
                Text(
                  '1 Hell Stone = 100 Dream Coins',
                  style: TextStyle(
                    color: Colors.amberAccent.withValues(alpha: 0.8),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),

                // Live Preview of Resulting Balances
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildBalancePreview(
                        'Resulting Stones',
                        widget.controller.hellStones,
                        widget.controller.hellStones - _amountToExchange,
                        Colors.redAccent,
                      ),
                      const Icon(
                        Icons.swap_horiz_rounded,
                        color: Colors.white10,
                        size: 24,
                      ),
                      _buildBalancePreview(
                        'Resulting Coins',
                        widget.controller.dreamCoins,
                        widget.controller.dreamCoins +
                            (_amountToExchange * 100),
                        Colors.amberAccent,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Amount Selector
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildAdjustButton(Icons.remove, _decrement),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: 40,
                        child: Text(
                          '$_amountToExchange',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      _buildAdjustButton(Icons.add, _increment),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: _setMax,
                        child: const Text(
                          'MAX',
                          style: TextStyle(
                            color: Colors.amberAccent,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                if (widget.controller.isLoading)
                  const CircularProgressIndicator(color: Colors.amberAccent)
                else
                  Column(
                    children: [
                      GlassButton(
                        onTap: canExchange ? _performExchange : null,
                        label: 'EXCHANGE NOW',
                        color: (canExchange ? Colors.amberAccent : Colors.grey)
                            .withValues(alpha: 0.2),
                        borderColor:
                            (canExchange ? Colors.amberAccent : Colors.grey)
                                .withValues(alpha: 0.4),
                      ),
                      const SizedBox(height: 12),
                      GlassButton(
                        onTap: widget.onBackTap,
                        label: 'BACK',
                        color: Colors.white.withValues(alpha: 0.05),
                        borderColor: Colors.white.withValues(alpha: 0.1),
                      ),
                    ],
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildBalancePreview(
    String label,
    int current,
    int result,
    Color color,
  ) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white38, fontSize: 10),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$current',
              style: const TextStyle(
                color: Colors.white24,
                fontSize: 12,
                decoration: TextDecoration.lineThrough,
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Colors.white12,
              size: 14,
            ),
            Text(
              '$result',
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAdjustButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}
