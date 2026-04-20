import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:dreamhunter/widgets/liquid_glass_dialog.dart';
import 'package:dreamhunter/widgets/common_ui.dart';
import 'package:dreamhunter/widgets/branding/app_logo.dart';
import 'package:dreamhunter/widgets/glass_button.dart';
import 'package:dreamhunter/widgets/progression/roulette_painter.dart';
import 'package:dreamhunter/widgets/custom_snackbar.dart';
import 'package:dreamhunter/widgets/economy/insufficient_funds_dialog.dart';
import 'package:dreamhunter/services/progression/daily_roulette.dart';
import 'package:dreamhunter/services/economy/wallet_manager.dart';
import 'package:dreamhunter/services/core/audio_manager.dart';

class RouletteDialog extends StatefulWidget {
  final WalletManager controller;
  final BuildContext? parentContext;

  const RouletteDialog({
    super.key,
    required this.controller,
    this.parentContext,
  });

  @override
  State<RouletteDialog> createState() => _RouletteDialogState();
}

class _RouletteDialogState extends State<RouletteDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Animation<double>? _animation;

  final DailyRoulette _rouletteService = DailyRoulette.instance;
  bool _isLoading = true;
  bool _isSpinning = false;
  bool _isRefilling = false;
  double _currentRotation = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );
    _initService();
  }

  Future<void> _initService() async {
    await _rouletteService.initialize();
    if (mounted) {
      setState(() => _isLoading = false);

      // LOGIC FIX: Refund if crashed during spin
      final state = _rouletteService.state;
      if (state.isSpinning) {
        _handleCrashedSessionRefund(state);
      }
    }
  }

  Future<void> _handleCrashedSessionRefund(RouletteState state) async {
    if (state.lastSpinWasPaid) {
      await widget.controller.updateBalance(
        coinsDelta: DailyRoulette.paidSpinCost,
      );
      if (mounted) {
        showCustomSnackBar(
          context,
          'RECOVERY: ${DailyRoulette.paidSpinCost} Coins refunded.',
          type: SnackBarType.info,
        );
      }
    } else {
      await _rouletteService.addFreeSpins(1);
      if (mounted) {
        showCustomSnackBar(
          context,
          'RECOVERY: 1 Free Spin restored.',
          type: SnackBarType.info,
        );
      }
    }
    await _rouletteService.setSpinning(false);
  }

  Future<void> _spin({bool isPaid = false}) async {
    if (_isSpinning) return;

    // Logic Fix 2: Use Centralized Cost
    const int cost = DailyRoulette.paidSpinCost;
    if (isPaid && widget.controller.dreamCoins < cost) {
      _showInsufficientFundsDialog();
      return;
    }

    final winningReward = _rouletteService.getRandomReward();
    final int winnerIndex = DailyRoulette.rewards.indexOf(winningReward);

    const double fullCircle = 2 * math.pi;
    final double segmentWidth = fullCircle / DailyRoulette.rewards.length;
    final double baseRotation =
        -math.pi / 2 - (winnerIndex + 0.5) * segmentWidth;
    final double targetRotation =
        _currentRotation +
        (10 * fullCircle) +
        (baseRotation - (_currentRotation % fullCircle));

    AudioManager().playRouletteSpin();

    setState(() {
      _isSpinning = true;
      _animation = Tween<double>(begin: _currentRotation, end: targetRotation)
          .animate(
            CurvedAnimation(parent: _controller, curve: Curves.easeOutCirc),
          );
    });

    _controller.duration = const Duration(seconds: 5);
    _controller.reset();
    unawaited(_controller.forward());

    unawaited(() async {
      if (isPaid) {
        await widget.controller.updateBalance(coinsDelta: -cost);
      } else {
        await _rouletteService.consumeFreeSpin();
      }
      await _rouletteService.setSpinning(true, isPaid: isPaid);
    }());

    await Future.delayed(const Duration(seconds: 5));
    _finalizeSpin(targetRotation, winningReward);
  }

  void _finalizeSpin(double targetRotation, Map<String, dynamic> reward) async {
    AudioManager().playReward();
    final rewardAmount = (reward['amount'] as num).toInt();

    unawaited(() async {
      await widget.controller.updateBalance(coinsDelta: rewardAmount);
      await _rouletteService.setSpinning(false);
    }());

    if (!mounted) {
      if (widget.parentContext != null && widget.parentContext!.mounted) {
        showCustomSnackBar(
          widget.parentContext!,
          'REWARD UNLOCKED: ${reward['name']}!',
          type: SnackBarType.success,
        );
      }
      return;
    }

    setState(() {
      _isSpinning = false;
      _currentRotation = targetRotation;
    });

    showCustomSnackBar(
      context,
      'REWARD UNLOCKED: ${reward['name']}!',
      type: SnackBarType.success,
    );
  }

  void _showInsufficientFundsDialog() {
    InsufficientFundsDialog.show(
      context,
      needed: DailyRoulette.paidSpinCost,
      current: widget.controller.dreamCoins,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return ListenableBuilder(
      listenable: _rouletteService,
      builder: (context, _) {
        final state = _rouletteService.state;
        return Center(
          child: LiquidGlassDialog(
            width: 400,
            height: MediaQuery.of(context).size.height * 0.85,
            padding: const EdgeInsets.all(28),
            child: Column(
              children: [
                const GameDialogHeader(title: 'LUCKY ROULETTE'),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amberAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.amberAccent.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    '${state.freeSpins} / ${DailyRoulette.maxFreeSpins} SPINS',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Colors.amberAccent,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                Expanded(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      AnimatedBuilder(
                        animation: _controller,
                        builder: (context, child) {
                          double rotation = _isSpinning
                              ? (_animation?.value ?? _currentRotation)
                              : _currentRotation;
                          return CustomPaint(
                            size: const Size(300, 300),
                            painter: RouletteWheelPainter(
                              rewards: DailyRoulette.rewards,
                              rotation: rotation,
                            ),
                          );
                        },
                      ),
                      Positioned(
                        top: -20,
                        child: const Icon(
                          Icons.arrow_drop_down_rounded,
                          color: Colors.white,
                          size: 60,
                        ),
                      ),
                      const AppLogo(size: 60),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                Row(
                  children: [
                    Expanded(
                      child: GlassButton(
                        onTap: state.freeSpins > 0
                            ? () => _spin(isPaid: false)
                            : null,
                        isClickable: !_isSpinning && state.freeSpins > 0,
                        glowColor: Colors.amberAccent,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'FREE SPIN',
                              style: Theme.of(
                                context,
                              ).textTheme.labelLarge?.copyWith(fontSize: 16),
                            ),
                            Text(
                              'DAILY REFILL',
                              style: Theme.of(
                                context,
                              ).textTheme.bodySmall?.copyWith(fontSize: 9),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: GlassButton(
                        onTap: () => _spin(isPaid: true),
                        isClickable: !_isSpinning,
                        glowColor: Colors.cyanAccent,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'PAID SPIN',
                              style: Theme.of(
                                context,
                              ).textTheme.labelLarge?.copyWith(fontSize: 16),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.toll_rounded,
                                  color: Colors.amberAccent,
                                  size: 12,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${DailyRoulette.paidSpinCost} COINS',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        fontSize: 10,
                                        color: Colors.amberAccent,
                                      ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                GlassButton(
                  onTap: () async {
                    setState(() => _isRefilling = true);
                    showCustomSnackBar(
                      context,
                      'BONUS GRANTED: +1 Free Spin!',
                      type: SnackBarType.success,
                    );
                    await Future.delayed(const Duration(seconds: 1));
                    await _rouletteService.addFreeSpins(1);
                    if (mounted) setState(() => _isRefilling = false);
                  },
                  isClickable: !_isSpinning && !_isRefilling,
                  glowColor: Colors.blueAccent,
                  width: double.infinity,
                  height: 50,
                  label: 'GET MORE SPINS (+1)',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
