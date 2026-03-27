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

  const RouletteDialog({
    super.key,
    this.onSpinCompleted,
    required this.controller,
  });

  @override
  State<RouletteDialog> createState() => _RouletteDialogState();
}

class _RouletteDialogState extends State<RouletteDialog> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Animation<double>? _animation;
  
  static const List<Map<String, dynamic>> _hardcodedRewards = [
    {
      'name': '10 DC',
      'type': 'currency',
      'amount': 10,
      'weight': 100, // Common
      'color': '0xCC9C27B0' // Deep Purple
    },
    {
      'name': '25 DC',
      'type': 'currency',
      'amount': 25,
      'weight': 50, // Uncommon
      'color': '0xCC2196F3' // Blue
    },
    {
      'name': '50 DC',
      'type': 'currency',
      'amount': 50,
      'weight': 20, // Rare
      'color': '0xCC00BCD4' // Cyan
    },
    {
      'name': '100 DC',
      'type': 'currency',
      'amount': 100,
      'weight': 10, // Epic
      'color': '0xCCFFD740' // Amber
    },
    {
      'name': '250 DC',
      'type': 'currency',
      'amount': 250,
      'weight': 5, // Legendary
      'color': '0xCCFF4081' // Pink
    },
    {
      'name': '500 DC',
      'type': 'currency',
      'amount': 500,
      'weight': 2, // Jackpot
      'color': '0xCCFF5252' // Red Accent
    },
  ];

  int _freeSpins = 0;
  bool _isLoading = true;
  bool _isSpinning = false;
  double _currentRotation = 0;
  Map<String, dynamic>? _winningReward;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
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
    }
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

    setState(() {
      _isSpinning = true;
      _winningReward = null;
    });

    // Determine winner based on weights
    final int totalWeight = _hardcodedRewards.fold<int>(0, (total, item) => total + (item['weight'] as int));
    final randomValue = math.Random().nextInt(totalWeight);
    
    int cumulativeWeight = 0;
    int winnerIndex = 0;
    for (int i = 0; i < _hardcodedRewards.length; i++) {
      cumulativeWeight += _hardcodedRewards[i]['weight'] as int;
      if (randomValue < cumulativeWeight) {
        winnerIndex = i;
        break;
      }
    }

    _winningReward = _hardcodedRewards[winnerIndex];

    // Animation logic
    const double fullCircle = 2 * math.pi;
    final double segmentWidth = fullCircle / _hardcodedRewards.length;
    // Pointer is at the TOP ( -pi/2 ).
    // We want segment `winnerIndex` to be at -pi/2.
    // Segment i starts at `rotation + i * segmentWidth`.
    // Middle of segment i is at `rotation + i * segmentWidth + segmentWidth / 2`.
    // So: `rotation + (winnerIndex + 0.5) * segmentWidth = -pi/2`.
    // `rotation = -pi/2 - (winnerIndex + 0.5) * segmentWidth`.
    final double baseRotation = -math.pi / 2 - (winnerIndex + 0.5) * segmentWidth;
    final double targetRotation = _currentRotation + (10 * fullCircle) + (baseRotation - (_currentRotation % fullCircle));

    _animation = Tween<double>(begin: _currentRotation, end: targetRotation).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    setState(() {
      _isSpinning = true;
    });

    if (isPaid) {
      // For now, subtract immediately for feedback
    } else {
      await RouletteService.consumeFreeSpin();
      if (mounted) {
        setState(() {
          _freeSpins -= 1;
        });
      }
    }

    _controller.reset();
    await _controller.forward();

    if (!mounted) return;

    final rewardAmount = (_winningReward!['amount'] as num).toInt();
    
    setState(() {
      _isSpinning = false;
      _currentRotation = targetRotation;
    });

    // Update global currency via controller
    if (isPaid) {
      // We deduct cost and add reward
      await widget.controller.updateCurrency(
        newCoins: widget.controller.dreamCoins - cost + rewardAmount,
      );
    } else {
      await widget.controller.updateCurrency(
        newCoins: widget.controller.dreamCoins + rewardAmount,
      );
    }

    if (mounted) {
      showCustomSnackBar(
        context,
        'YOU WON: ${_winningReward!['name']}!',
        type: SnackBarType.success,
      );
      widget.onSpinCompleted?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Center(
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
                          rewards: _hardcodedRewards,
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
                        showCustomSnackBar(context, 'Watching ad... +1 Spin granted!', type: SnackBarType.info);
                        final state = await RouletteService.getAndSyncState();
                        final newState = RouletteState(
                          freeSpins: state.freeSpins + 1,
                          lastRefillDate: state.lastRefillDate,
                        );
                        await RouletteService.saveState(newState);
                        if (mounted) {
                          setState(() => _freeSpins = newState.freeSpins);
                        }
                      },
                      isClickable: !_isSpinning,
                      glowColor: Colors.blueAccent,
                      width: double.infinity,
                      height: 50,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.play_circle_outline, color: Colors.blueAccent, size: 20),
                          SizedBox(width: 8),
                          Text('WATCH AD (+1 FREE SPIN)', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.w900, fontSize: 14)),
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
    );
  }
}

class RouletteWheelPainter extends CustomPainter {
  final List<Map<String, dynamic>> rewards;
  final double rotation;
  RouletteWheelPainter({required this.rewards, required this.rotation});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final sweepAngle = (2 * math.pi) / rewards.length;
    
    // 1. Draw Arcs (Wheel background)
    for (int i = 0; i < rewards.length; i++) {
      final baseColor = Color(int.parse(rewards[i]['color'].replaceFirst('0x', ''), radix: 16));
      final paint = Paint()..shader = RadialGradient(
        colors: [baseColor.withValues(alpha: 0.9), baseColor.withValues(alpha: 0.5)]
      ).createShader(rect);
      
      canvas.drawArc(rect, rotation + i * sweepAngle, sweepAngle, true, paint);
    }

    // 2. Draw Text (Radial Base-to-Center)
    for (int i = 0; i < rewards.length; i++) {
      canvas.save();
      
      // Move to center and rotate to the middle of the current segment
      canvas.translate(center.dx, center.dy);
      final segmentRotation = rotation + (i * sweepAngle) + (sweepAngle / 2);
      canvas.rotate(segmentRotation);

      final tp = TextPainter(
        text: TextSpan(
          text: rewards[i]['name'],
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
            shadows: [Shadow(color: Colors.black87, blurRadius: 4, offset: Offset(1, 1))],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      // Position text radially - 75% of the way out
      final xOffset = radius * 0.72;
      canvas.translate(xOffset, 0);
      
      // Rotate 90 degrees to align text base with the radius (perpendicular)
      canvas.rotate(math.pi / 2);

      // Paint centered
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(RouletteWheelPainter oldDelegate) => oldDelegate.rotation != rotation;
}
