import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'liquid_glass_dialog.dart';
import '../services/offline_cache.dart';
import 'custom_snackbar.dart';

class RouletteDialog extends StatefulWidget {
  const RouletteDialog({super.key});

  @override
  State<RouletteDialog> createState() => _RouletteDialogState();
}

class _RouletteDialogState extends State<RouletteDialog> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Animation<double>? _animation;
  
  static const List<Map<String, dynamic>> _defaultRewards = [
    {
      'name': '10 DC',
      'type': 'currency',
      'amount': 10,
      'weight': 50,
      'color': '0xCC9C27B0' // Deep Purple
    },
    {
      'name': '50 DC',
      'type': 'currency',
      'amount': 50,
      'weight': 20,
      'color': '0xCC00BCD4' // Cyan
    },
    {
      'name': 'LUCK',
      'type': 'currency',
      'amount': 0,
      'weight': 25,
      'color': '0xCCFFD740' // Amber
    },
    {
      'name': '100 DC',
      'type': 'currency',
      'amount': 100,
      'weight': 5,
      'color': '0xCCFF4081' // Pink
    },
  ];

  List<Map<String, dynamic>> _rewards = _defaultRewards;
  Map<String, dynamic>? _config;
  int _freeSpins = 0;
  int _dreamCoins = 0;
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
    try {
      // 1. Load basic currency from offline cache immediately
      final Map<String, dynamic> currency = await OfflineCache.getCurrency();
      if (mounted) {
        setState(() {
          _dreamCoins = currency['dreamCoins'] ?? 0;
          _freeSpins = currency['freeSpins'] ?? 0;
        });
      }

      // 2. Try to fetch dynamic config from Firestore if online
      try {
        final configDoc = await FirebaseFirestore.instance
            .collection('metadata')
            .doc('roulette_config')
            .get()
            .timeout(const Duration(seconds: 3));
        
        if (configDoc.exists) {
          final data = configDoc.data() as Map<String, dynamic>;
          await OfflineCache.saveMetadata('roulette_config', data);
          if (mounted) {
            setState(() {
              _config = data;
              _rewards = List<Map<String, dynamic>>.from(data['rewards'] ?? _defaultRewards);
            });
          }
        }
      } catch (e) {
        // Fallback to local cache of previous online config
        final cachedConfig = await OfflineCache.getMetadata('roulette_config');
        if (mounted && cachedConfig != null) {
          setState(() {
            _config = cachedConfig;
            _rewards = List<Map<String, dynamic>>.from(cachedConfig['rewards'] ?? _defaultRewards);
          });
        }
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _spin(bool isPaid) async {
    if (_isSpinning || _rewards.isEmpty) {
      return;
    }
    
    final int cost = (_config?['spinBuyPrice'] as num?)?.toInt() ?? 50;
    if (!isPaid && _freeSpins <= 0) {
      showCustomSnackBar(context, 'No free spins left!', type: SnackBarType.info);
      return;
    }
    if (isPaid && _dreamCoins < cost) {
      showCustomSnackBar(context, 'Insufficient Dream Coins!', type: SnackBarType.info);
      return;
    }

    setState(() {
      _isSpinning = true;
      _winningReward = null;
    });

    // Determine winner based on weights
    final int totalWeight = _rewards.fold<int>(0, (total, item) => total + (item['weight'] as int));
    if (totalWeight <= 0) {
      setState(() => _isSpinning = false);
      return;
    }
    
    final randomValue = math.Random().nextInt(totalWeight);
    
    int cumulativeWeight = 0;
    int winnerIndex = 0;
    for (int i = 0; i < _rewards.length; i++) {
      cumulativeWeight += _rewards[i]['weight'] as int;
      if (randomValue < cumulativeWeight) {
        winnerIndex = i;
        break;
      }
    }

    _winningReward = _rewards[winnerIndex];

    // Record cost transaction IMMEDIATELY and update UI state
    // We await this to ensure persistence before animation
    if (isPaid) {
      await OfflineCache.addTransaction(
        type: 'BUY_SPIN',
        dreamDelta: -cost,
      );
    } else {
      await OfflineCache.addTransaction(
        type: 'ROULETTE_SPIN',
        freeSpinDelta: -1,
      );
    }

    if (!mounted) return;

    setState(() {
      if (isPaid) {
        _dreamCoins -= cost;
      } else {
        _freeSpins -= 1;
      }
    });

    // Animation logic
    // Each segment width in radians
    const double fullCircle = 2 * math.pi;
    final double segmentWidth = fullCircle / _rewards.length;

    // We want the winnerIndex to be at top (math.pi * 1.5)
    // CustomPainter starts at 3 o'clock (0 rad)
    // Adjust target to land winnerIndex center at the top pointer.

    final double targetRotation =
        (8 * fullCircle) + (fullCircle - (winnerIndex * segmentWidth));

    if (mounted) {
      setState(() {
        _animation =
            Tween<double>(begin: _currentRotation % fullCircle, end: targetRotation)
                .animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
        );
      });
    }

    _controller.reset();
    await _controller.forward();

    if (!mounted) {
      return;
    }

    // Award prize
    final rewardType = _winningReward!['type'];
    final rewardAmount = (_winningReward!['amount'] as num?)?.toInt() ?? 0;

    if (rewardType == 'currency') {
      await OfflineCache.addTransaction(
        type: 'EARN',
        dreamDelta: rewardAmount,
      );
    } else {
      await OfflineCache.addTransaction(
        type: 'ROULETTE_REWARD',
        itemId: _winningReward!['itemId'],
      );
    }

    if (mounted) {
      setState(() {
        _isSpinning = false;
        _currentRotation = targetRotation;
        if (rewardType == 'currency') {
          _dreamCoins += rewardAmount;
        }
      });
    }

    if (mounted) {
      final rewardColor = Color(int.parse(_winningReward!['color'].replaceFirst('0x', ''), radix: 16));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'YOU WON: ${_winningReward!['name']}!',
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          backgroundColor: rewardColor.withValues(alpha: 0.8),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Center(
      child: LiquidGlassDialog(
        width: 350,
        height: 600,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'ROULETTE',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Colors.amberAccent,
                    letterSpacing: 2,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white38),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
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
                '$_freeSpins / ${_config?['maxFreeSpins'] ?? 10} SPINS',
                style: const TextStyle(
                  color: Colors.amberAccent,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  letterSpacing: 1,
                ),
              ),
            ),
            const SizedBox(height: 48),
            
            // The Wheel
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  // Outer Glow
                  Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.05),
                          blurRadius: 40,
                          spreadRadius: 5,
                        )
                      ],
                    ),
                  ),
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      double rotation = _currentRotation;
                      if (_isSpinning && _animation != null) {
                        rotation = _animation!.value;
                      }
                      return Transform.rotate(
                        angle: rotation,
                        child: CustomPaint(
                          size: const Size(280, 280),
                          painter: RouletteWheelPainter(rewards: _rewards),
                        ),
                      );
                    },
                  ),
                  // Pointer Arrow (Modern Glassy style)
                  Positioned(
                    top: -25,
                    child: Column(
                      children: [
                        const Icon(Icons.arrow_drop_down_rounded, 
                          color: Colors.redAccent, 
                          size: 50,
                          shadows: [
                            Shadow(color: Colors.redAccent, blurRadius: 15),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Center Pin (Dream Star)
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E3A),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.amberAccent.withValues(alpha: 0.3),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(Icons.star_rounded, color: Colors.amberAccent, size: 24),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Actions
            Column(
              children: [
                if (_freeSpins > 0)
                  _buildActionButton(
                    label: 'FREE SPIN',
                    onTap: () => _spin(false),
                    isEnabled: !_isSpinning,
                    color: Colors.greenAccent,
                    icon: Icons.refresh_rounded,
                  )
                else
                  _buildActionButton(
                    label: 'WATCH AD (+1 SPIN)',
                    onTap: () {
                      showCustomSnackBar(context, 'Ads coming soon! Placeholder +1 granted.',
                          type: SnackBarType.info);
                      // Placeholder logic: Grant +1 spin for now
                      setState(() {
                        _freeSpins += 1;
                      });
                      OfflineCache.addTransaction(
                        type: 'WATCH_AD_REWARD',
                        freeSpinDelta: 1,
                      );
                    },
                    isEnabled: !_isSpinning,
                    color: Colors.blueAccent,
                    icon: Icons.play_circle_outline,
                  ),
                const SizedBox(height: 12),
                _buildActionButton(
                  label: 'BUY SPIN (${(_config?['spinBuyPrice'] ?? 50)} DC)',
                  onTap: () => _spin(true),
                  isEnabled: !_isSpinning &&
                      _dreamCoins >=
                          ((_config?['spinBuyPrice'] as num?)?.toInt() ?? 50),
                  color: Colors.amberAccent,
                  icon: Icons.shopping_cart_rounded,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required VoidCallback onTap,
    required bool isEnabled,
    required Color color,
    required IconData icon,
  }) {
    return InkWell(
      onTap: isEnabled ? onTap : null,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: isEnabled ? color.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: isEnabled ? color.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.05),
            width: 1.5,
          ),
          boxShadow: isEnabled ? [
            BoxShadow(
              color: color.withValues(alpha: 0.1),
              blurRadius: 15,
              spreadRadius: 0,
            )
          ] : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isEnabled ? color : Colors.white.withValues(alpha: 0.1), size: 22),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: isEnabled ? color : Colors.white.withValues(alpha: 0.1),
                fontWeight: FontWeight.w900,
                fontSize: 15,
                letterSpacing: 1.5,
                shadows: isEnabled ? [
                  Shadow(color: color.withValues(alpha: 0.5), blurRadius: 10),
                ] : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RouletteWheelPainter extends CustomPainter {
  final List<Map<String, dynamic>> rewards;

  RouletteWheelPainter({required this.rewards});

  @override
  void paint(Canvas canvas, Size size) {
    if (rewards.isEmpty) {
      return;
    }
    
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    
    final sweepAngle = (2 * math.pi) / rewards.length;
    
    for (int i = 0; i < rewards.length; i++) {
      final baseColor = Color(int.parse(rewards[i]['color'].replaceFirst('0x', ''), radix: 16));
      
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            baseColor.withValues(alpha: 0.8),
            baseColor.withValues(alpha: 0.4),
          ],
        ).createShader(rect)
        ..style = PaintingStyle.fill;
      
      // Offset startAngle so first segment center aligns with pointer when rotation is 0
      final startAngle = (i * sweepAngle) - (math.pi / 2) - (sweepAngle / 2);
      canvas.drawArc(rect, startAngle, sweepAngle, true, paint);
      
      // Draw inner segment glow
      final glowPaint = Paint()
        ..color = baseColor.withValues(alpha: 0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.inner, 10)
        ..style = PaintingStyle.fill;
      canvas.drawArc(rect, startAngle, sweepAngle, true, glowPaint);

      // Draw border
      final borderPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      canvas.drawArc(rect, startAngle, sweepAngle, true, borderPaint);

      // Draw reward name
      final textAngle = startAngle + sweepAngle / 2;
      final textOffset = Offset(
        center.dx + (radius * 0.65) * math.cos(textAngle),
        center.dy + (radius * 0.65) * math.sin(textAngle),
      );

      final textSpan = TextSpan(
        text: rewards[i]['name'].toString().toUpperCase(),
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.9),
          fontSize: rewards.length > 8 ? 8 : 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 1,
          shadows: [
            Shadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 4),
          ],
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      );
      textPainter.layout();
      
      canvas.save();
      canvas.translate(textOffset.dx, textOffset.dy);
      canvas.rotate(textAngle + math.pi / 2);
      textPainter.paint(canvas, Offset(-textPainter.width / 2, -textPainter.height / 2));
      canvas.restore();
    }

    // Glassy shine overlay
    final shinePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.15),
          Colors.white.withValues(alpha: 0.0),
          Colors.white.withValues(alpha: 0.05),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(rect)
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(center, radius, shinePaint);

    // Inner shadow ring
    final innerShadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20;
    canvas.drawCircle(center, radius - 10, innerShadowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
