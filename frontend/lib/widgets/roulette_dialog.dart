import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'liquid_glass_dialog.dart';
import 'game_widgets.dart';
import 'clickable_image.dart';
import 'custom_snackbar.dart';
import 'insufficient_funds_dialog.dart';
import '../services/roulette_service.dart';
import '../services/dashboard_controller.dart';

class RouletteDialog extends StatefulWidget {
  final VoidCallback? onSpinCompleted;
  final DashboardController controller;
  final BuildContext? parentContext;

  const RouletteDialog({
    super.key,
    this.onSpinCompleted,
    required this.controller,
    this.parentContext,
  });

  @override
  State<RouletteDialog> createState() => _RouletteDialogState();
}

class _RouletteDialogState extends State<RouletteDialog> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Animation<double>? _animation;
  
  int _freeSpins = 0;
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
    _loadData();
  }

  Future<void> _loadData() async {
    final state = await RouletteService.getAndSyncState();
    if (mounted) {
      setState(() {
        _freeSpins = state.freeSpins;
        _isLoading = false;
      });

      // Session Recovery: If we were spinning, resume it!
      if (state.isSpinning && state.targetRotation != null) {
        _resumeSpin(state.targetRotation!);
      }
    }
  }

  void _resumeSpin(double targetRotation) async {
    // 1. Recover the winning reward from pending
    final state = await RouletteService.getAndSyncState();
    if (state.pendingReward == null || state.spinStartTime == null) {
      await RouletteService.setSpinning(false);
      return;
    }

    final reward = state.pendingReward!;
    final startTime = DateTime.parse(state.spinStartTime!);
    final now = DateTime.now();
    final elapsed = now.difference(startTime);
    const totalDuration = Duration(seconds: 5);

    // If already finished, just finalize
    if (elapsed >= totalDuration) {
      _finalizeSpin(targetRotation, reward);
      return;
    }

    final remainingDuration = totalDuration - elapsed;
    
    // 2. Setup a shortened "finishing" animation
    setState(() {
      _isSpinning = true;
    });

    // Calculate roughly where the wheel should be now
    final double progress = elapsed.inMilliseconds / totalDuration.inMilliseconds;
    _currentRotation = _currentRotation + (targetRotation - _currentRotation) * progress;

    _animation = Tween<double>(begin: _currentRotation, end: targetRotation).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _controller.duration = remainingDuration;
    _controller.reset();
    await _controller.forward();

    _finalizeSpin(targetRotation, reward);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _showInsufficientFundsDialog() {
    InsufficientFundsDialog.show(
      context,
      needed: 50,
      current: widget.controller.dreamCoins,
      onGoToExchange: () {
        Navigator.pop(context); // Close Roulette
        showCustomSnackBar(
          context, 
          'Switched to Exchange Module!', 
          type: SnackBarType.info
        );
      },
    );
  }

  void _spin(bool isPaid) async {
    if (_isSpinning) return;
    
    const int cost = 50;
    if (!isPaid && _freeSpins <= 0) {
      showCustomSnackBar(context, 'No free spins left!', type: SnackBarType.info);
      return;
    }
    
    if (isPaid && widget.controller.dreamCoins < cost) {
      _showInsufficientFundsDialog();
      return;
    }

    // 1. Determine winner
    final int totalWeight = RouletteService.rewards.fold<int>(0, (total, item) => total + (item['weight'] as int));
    final randomValue = math.Random().nextInt(totalWeight);
    
    int cumulativeWeight = 0;
    int winnerIndex = 0;
    for (int i = 0; i < RouletteService.rewards.length; i++) {
      cumulativeWeight += RouletteService.rewards[i]['weight'] as int;
      if (randomValue < cumulativeWeight) {
        winnerIndex = i;
        break;
      }
    }

    final winningReward = RouletteService.rewards[winnerIndex];

    // 2. DEDUCT COST & SET STATE
    if (isPaid) {
      await widget.controller.updateCurrency(
        newCoins: widget.controller.dreamCoins - cost,
      );
    } else {
      await RouletteService.consumeFreeSpin();
    }
    
    // Store for session recovery
    const double fullCircle = 2 * math.pi;
    final double segmentWidth = fullCircle / RouletteService.rewards.length;
    final double baseRotation = -math.pi / 2 - (winnerIndex + 0.5) * segmentWidth;
    final double targetRotation = _currentRotation + (10 * fullCircle) + (baseRotation - (_currentRotation % fullCircle));

    await RouletteService.setPendingReward({
      'amount': winningReward['amount'],
      'name': winningReward['name'],
    });
    await RouletteService.setSpinning(true, targetRotation: targetRotation);

    if (!mounted) return;

    setState(() {
      _isSpinning = true;
      if (!isPaid) _freeSpins -= 1;
    });

    // 3. Animate
    _animation = Tween<double>(begin: _currentRotation, end: targetRotation).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _controller.duration = const Duration(seconds: 5);
    _controller.reset();
    await _controller.forward();

    _finalizeSpin(targetRotation, winningReward);
  }

  void _finalizeSpin(double targetRotation, Map<String, dynamic> reward) async {
    // 4. FINISH: Grant reward and clear pending
    final rewardAmount = (reward['amount'] as num).toInt();
    await widget.controller.updateCurrency(
      newCoins: widget.controller.dreamCoins + rewardAmount,
    );
    await RouletteService.clearPendingReward();
    await RouletteService.setSpinning(false);

    if (!mounted) {
      if (widget.parentContext != null && widget.parentContext!.mounted) {
        showCustomSnackBar(
          widget.parentContext!,
          'YOU WON: ${reward['name']}!',
          type: SnackBarType.success,
        );
      }
      widget.onSpinCompleted?.call();
      return;
    }

    setState(() {
      _isSpinning = false;
      _currentRotation = targetRotation;
    });

    showCustomSnackBar(
      context,
      'YOU WON: ${reward['name']}!',
      type: SnackBarType.success,
    );
    widget.onSpinCompleted?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return PopScope(
      canPop: true, // Allow closing while spinning (reward is already safe)
      child: Center(
        child: LiquidGlassDialog(
        width: 380,
        height: 650,
        child: Column(
          children: [
            const GameDialogHeader(title: 'ROULETTE'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.amberAccent.withValues(alpha: 0.1),
                    blurRadius: 10,
                    spreadRadius: 1,
                  )
                ],
              ),
              child: Text(
                '$_freeSpins / ${RouletteService.maxFreeSpins} SPINS',
                style: const TextStyle(
                  color: Colors.amberAccent,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  letterSpacing: 1,
                ),
              ),
            ),
            const SizedBox(height: 30),
            
            // The Wheel
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      double rotation = _isSpinning ? _animation!.value : _currentRotation;
                      return CustomPaint(
                        size: const Size(300, 300),
                        painter: RouletteWheelPainter(
                          rewards: RouletteService.rewards,
                          rotation: rotation,
                        ),
                      );
                    },
                  ),
                  // Pointer Arrow
                  Positioned(
                    top: -20,
                    child: const Icon(Icons.arrow_drop_down_rounded, color: Colors.redAccent, size: 50),
                  ),
                  // Center Pin
                  Container(
                    width: 40, height: 40,
                    decoration: const BoxDecoration(color: Color(0xFF1E1E3A), shape: BoxShape.circle),
                    child: const Center(child: Icon(Icons.star_rounded, color: Colors.amberAccent, size: 24)),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 30),
            
            // Actions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  if (_freeSpins > 0)
                    GlassButton(
                      onTap: () => _spin(false),
                      isClickable: !_isSpinning,
                      glowColor: Colors.greenAccent,
                      width: double.infinity,
                      height: 50,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.refresh_rounded, color: Colors.greenAccent, size: 20),
                          SizedBox(width: 8),
                          Text('FREE SPIN', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.w900, fontSize: 14)),
                        ],
                      ),
                    )
                  else
                    GlassButton(
                      onTap: () async {
                        if (_isRefilling) return;
                        _isRefilling = true;
                        
                        showCustomSnackBar(context, 'Watching ad... +1 Spin granted!', type: SnackBarType.info);
                        
                        // Simulate ad delay
                        await Future.delayed(const Duration(seconds: 1));
                        
                        final state = await RouletteService.getAndSyncState();
                        final newState = RouletteState(
                          freeSpins: state.freeSpins + 1,
                          lastRefillDate: state.lastRefillDate,
                          pendingReward: state.pendingReward,
                          isSpinning: state.isSpinning,
                          targetRotation: state.targetRotation,
                          spinStartTime: state.spinStartTime,
                        );
                        await RouletteService.saveState(newState);
                        
                        if (mounted) {
                          setState(() {
                            _freeSpins = newState.freeSpins;
                            _isRefilling = false;
                          });
                        }
                      },
                      isClickable: !_isSpinning && !_isRefilling,
                      glowColor: Colors.blueAccent,
                      width: double.infinity,
                      height: 50,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _isRefilling 
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blueAccent))
                            : const Icon(Icons.play_circle_outline, color: Colors.blueAccent, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            _isRefilling ? 'LOADING...' : 'WATCH AD (+1 FREE SPIN)', 
                            style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.w900, fontSize: 14)
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  GlassButton(
                    onTap: () => _spin(true),
                    isClickable: !_isSpinning,
                    glowColor: Colors.amberAccent,
                    width: double.infinity,
                    height: 50,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shopping_cart_rounded, color: Colors.amberAccent, size: 20),
                        SizedBox(width: 8),
                        Text('BUY SINGLE SPIN (50 DC)', style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.w900, fontSize: 14)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
      ),
    );
  }
}
