import 'package:dreamhunter/services/user_service.dart';
import 'package:dreamhunter/services/backend_service.dart';
import 'package:dreamhunter/services/offline_cache.dart';
import 'package:dreamhunter/widgets/shop_dialog.dart';
import 'package:dreamhunter/widgets/custom_snackbar.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:dreamhunter/services/chat_service.dart';
import 'package:dreamhunter/widgets/clickable_image.dart';
import 'package:dreamhunter/widgets/login_dialog.dart';
import 'package:dreamhunter/widgets/register_dialog.dart';
import 'package:dreamhunter/widgets/profile_dialog.dart';
import 'package:dreamhunter/widgets/chat_dialog.dart';
import 'package:dreamhunter/widgets/liquid_glass_dialog.dart';

enum AuthDialogType { login, register, profile }

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late StreamSubscription<User?> _authStateSubscription;
  Timer? _syncTimer;
  bool _isLoggedIn = false;
  bool _isBackendReady = false;
  AuthDialogType _currentDialogType = AuthDialogType.login;
  final UserService _userService = UserService();
  final BackendService _backendService = BackendService();

  @override
  void initState() {
    super.initState();
    _isLoggedIn = FirebaseAuth.instance.currentUser != null;
    _authStateSubscription = FirebaseAuth.instance.authStateChanges().listen((
      user,
    ) {
      if (mounted) {
        setState(() {
          _isLoggedIn = user != null;
        });
        if (_isLoggedIn) {
          _startSyncTimer();
        } else {
          _stopSyncTimer();
        }
      }
    });

    _pingBackend();
    if (_isLoggedIn) _startSyncTimer();
  }

  void _startSyncTimer() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      _reconcileEconomyWithBackend();
    });
    // Also sync immediately on start
    _reconcileEconomyWithBackend();
  }

  void _stopSyncTimer() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  Future<void> _reconcileEconomyWithBackend() async {
    if (!_isLoggedIn || !_isBackendReady) return;

    try {
      final transactions = await OfflineCache.getTransactionQueue();
      if (transactions.isEmpty) return;

      final List<String> sentIds = transactions.map((t) => t.id).toList();

      final result = await _backendService.reconcileEconomy(
        transactions.map((t) => t.toJson()).toList()
      );
      
      if (result != null && result['status'] == 'success') {
        await OfflineCache.clearTransactionQueue(ids: sentIds);
        // Update local balance from server to be safe
        await OfflineCache.saveCurrency(
          result['dreamCoins'] as int,
          result['hellStones'] as int,
        );
      }
    } catch (e) {
      debugPrint('Reconciliation failed: $e');
    }
  }

  Future<void> _pingBackend() async {
    try {
      final response = await http
          .get(Uri.parse('https://dreamhunter-api.onrender.com/'))
          .timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) {
        if (mounted) {
          setState(() => _isBackendReady = true);
          if (_isLoggedIn) _startSyncTimer();
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isBackendReady = false);
    }
  }

  @override
  void dispose() {
    _authStateSubscription.cancel();
    _stopSyncTimer();
    super.dispose();
  }

  void _showDropdownMenu() {
    showGeneralDialog(
      context: context,
      barrierLabel: "DropdownMenu",
      barrierDismissible: true,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Stack(
          children: [
            Positioned(
              top: 100,
              right: 20,
              child: FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: animation,
                  alignment: Alignment.topRight,
                  child: LiquidGlassDialog(
                    width: 200,
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildMenuButton(
                          icon: _isLoggedIn ? Icons.person : Icons.login,
                          label: _isLoggedIn ? 'Profile' : 'Login',
                          onTap: () {
                            Navigator.pop(context);
                            _showAuthDialog();
                          },
                        ),
                        const Divider(color: Colors.white24),
                        _buildMenuButton(
                          icon: Icons.settings,
                          label: 'Settings',
                          onTap: () {
                            Navigator.pop(context);
                            showCustomSnackBar(context, 'Settings coming soon!');
                          },
                        ),
                        const Divider(color: Colors.white24),
                        _buildMenuButton(
                          icon: Icons.exit_to_app,
                          label: 'Exit',
                          onTap: () {
                            if (Platform.isAndroid || Platform.isIOS) {
                              SystemNavigator.pop();
                            } else {
                              exit(0);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMenuButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 24),
              const SizedBox(width: 12),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAuthDialog() {
    setState(() {
      _currentDialogType = _isLoggedIn
          ? AuthDialogType.profile
          : AuthDialogType.login;
    });

    showGeneralDialog(
      context: context,
      barrierLabel: "AuthDialog",
      barrierDismissible: true,
      barrierColor: const Color.fromRGBO(0, 0, 0, 0.5),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Widget dialogContent;
            const double dialogWidth = 350;
            const double dialogHeight = 600;
            const double logoHeight = 375;
            const double logoOverlap = 150;

            switch (_currentDialogType) {
              case AuthDialogType.login:
                dialogContent = LoginDialog(
                  onRegisterRequested: () {
                    setDialogState(() {
                      _currentDialogType = AuthDialogType.register;
                    });
                  },
                  onLoginSuccess: () {
                    setDialogState(() {
                      _isLoggedIn = true;
                      _currentDialogType = AuthDialogType.profile;
                      showCustomSnackBar(
                        context,
                        'Login successful!',
                        type: SnackBarType.success,
                      );
                    });
                  },
                );
                break;
              case AuthDialogType.register:
                dialogContent = RegisterDialog(
                  onLoginRequested: () {
                    setDialogState(() {
                      _currentDialogType = AuthDialogType.login;
                    });
                  },
                  onRegisterSuccess: () {
                    setDialogState(() {
                      _currentDialogType = AuthDialogType.login;
                      showCustomSnackBar(
                        context,
                        'Successfully registered account. Please log in.',
                        type: SnackBarType.success,
                      );
                    });
                  },
                );
                break;
              case AuthDialogType.profile:
                dialogContent = ProfileDialog(
                  onLogoutRequested: () {
                    setDialogState(() {
                      _isLoggedIn = false;
                      _currentDialogType = AuthDialogType.login;
                    });
                  },
                );
                break;
            }

            String logoPath = '';
            if (_currentDialogType == AuthDialogType.login) {
              logoPath = 'assets/images/auth/login_logo.png';
            } else if (_currentDialogType == AuthDialogType.register) {
              logoPath = 'assets/images/auth/register_logo.png';
            }

            final double dialogX =
                (MediaQuery.of(context).size.width - dialogWidth) / 2;
            final double dialogY =
                (MediaQuery.of(context).size.height - dialogHeight) / 2 + 100;

            final double logoX = dialogX + (dialogWidth - logoHeight) / 2;
            final double logoY = dialogY - logoOverlap;

            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: dialogX,
                  top: dialogY,
                  child: LiquidGlassDialog(
                    width: dialogWidth,
                    height: dialogHeight,
                    padding: const EdgeInsets.fromLTRB(
                      20,
                      logoOverlap + 10,
                      20,
                      20,
                    ),
                    child: dialogContent,
                  ),
                ),
                if (logoPath.isNotEmpty)
                  Positioned(
                    left: logoX,
                    top: logoY,
                    child: IgnorePointer(
                      child: Image.asset(
                        logoPath,
                        width: logoHeight,
                        height: logoHeight,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          child: FadeTransition(opacity: animation, child: child),
        );
      },
    );
  }

  void _showPurchaseDialog() {
    showGeneralDialog(
      context: context,
      barrierLabel: "PurchaseDialog",
      barrierDismissible: true,
      barrierColor: const Color.fromRGBO(0, 0, 0, 0.5),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Center(
          child: LiquidGlassDialog(
            width: 350,
            height: 400,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.diamond_rounded, color: Colors.redAccent, size: 80),
                const SizedBox(height: 24),
                const Text(
                  'HELL STONES',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 16),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    'Purchase premium stones to unlock exclusive characters and items!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ),
                const SizedBox(height: 40),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent.withValues(alpha: 0.8),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('BACK TO GAME', style: TextStyle(fontWeight: FontWeight.bold)),
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
      },
    );
  }

  void _convertCurrency() async {
    final Map<String, int>? currency = await OfflineCache.getCurrency();
    final int currentHell = currency?['hellStones'] ?? 0;
    
    if (currentHell < 1) {
      if (mounted) {
        showCustomSnackBar(context, 'Insufficient Hell Stones.', type: SnackBarType.error);
      }
      return;
    }

    // 1 Stone -> 100 Coins
    await OfflineCache.addTransaction(
      type: 'CONVERSION',
      dreamDelta: 100,
      hellDelta: -1,
    );

    if (mounted) {
      Navigator.pop(context);
      showCustomSnackBar(context, 'Successfully converted 1 Hell Stone!', type: SnackBarType.success);
    }
  }

  void _showCoinExchangeDialog() {
    showGeneralDialog(
      context: context,
      barrierLabel: "CoinExchangeDialog",
      barrierDismissible: true,
      barrierColor: const Color.fromRGBO(0, 0, 0, 0.5),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Center(
          child: LiquidGlassDialog(
            width: 350,
            height: 400,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.toll_rounded, color: Colors.amberAccent, size: 80),
                const SizedBox(height: 24),
                const Text(
                  'COIN EXCHANGE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 16),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    'Exchange your premium Hell Stones for common Dream Coins!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ),
                const SizedBox(height: 40),
                ElevatedButton(
                  onPressed: _convertCurrency,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amberAccent.withValues(alpha: 0.8),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('EXCHANGE NOW', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 12),
                const Text(
                  '(1 Hell Stone = 100 Dream Coins)',
                  style: TextStyle(color: Colors.white24, fontSize: 10),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 100,
        leadingWidth: 200,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16.0, top: 8.0),
          child: StreamBuilder<DocumentSnapshot>(
            stream: _userService.getUserStats(),
            builder: (context, snapshot) {
              int coins = 0;
              int tokens = 0;

              if (_isLoggedIn && snapshot.hasData && snapshot.data!.exists) {
                final userData = snapshot.data!.data() as Map<String, dynamic>;
                coins = userData['dreamCoins'] ?? 0;
                tokens = userData['hellStones'] ?? 0;
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCurrencyChip(
                    icon: Icons.toll_rounded,
                    value: '$coins',
                    color: Colors.amberAccent,
                    onPlusTap: _showCoinExchangeDialog,
                  ),
                  const SizedBox(height: 4),
                  _buildCurrencyChip(
                    icon: Icons.diamond_rounded,
                    value: '$tokens',
                    color: Colors.redAccent,
                    onPlusTap: _showPurchaseDialog,
                  ),
                ],
              );
            },
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: SizedBox(
              width: 45,
              height: 45,
              child: OverflowBox(
                maxWidth: 150,
                maxHeight: 150,
                child: MakeItButton(
                  imagePath: 'assets/images/dashboard/sandwich.png',
                  width: 45,
                  height: 45,
                  onTap: _showDropdownMenu,
                  clickResponsiveness: true,
                  onHoverGlow: true,
                  isClickable: true,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Image.asset(
            'assets/images/dashboard/main_background.png',
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),
          Positioned(
            top: 160,
            left: 20,
            right: 20,
            child: StreamBuilder<DocumentSnapshot>(
              stream: ChatService().getGlobalAlert(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || !snapshot.data!.exists) return const SizedBox.shrink();
                final data = snapshot.data!.data() as Map<String, dynamic>;
                final message = data['message'] as String?;
                if (message == null || message.isEmpty) return const SizedBox.shrink();
                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withValues(alpha: 0.5),
                        blurRadius: 10,
                        spreadRadius: 2,
                      )
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.white),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          message,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Positioned(
            bottom: MediaQuery.of(context).size.height * 0.15,
            left: 0,
            right: 0,
            child: Center(
              child: Image.asset(
                'assets/images/game/environment/dorm.png',
                fit: BoxFit.contain,
                width: MediaQuery.of(context).size.width * 0.8,
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            child: Image.asset(
              'assets/images/dashboard/roulette_man.png',
              fit: BoxFit.contain,
              width: 200,
              height: 200,
            ),
          ),
          Positioned(
            bottom: 0,
            right: -1,
            child: MakeItButton(
              imagePath: 'assets/images/dashboard/shop_stall.png',
              width: 200,
              height: 200,
              onTap: () {
                showGeneralDialog(
                  context: context,
                  barrierLabel: "ShopDialog",
                  barrierDismissible: true,
                  barrierColor: const Color.fromRGBO(0, 0, 0, 0.5),
                  transitionDuration: const Duration(milliseconds: 300),
                  pageBuilder: (context, animation, secondaryAnimation) {
                    return ScaleTransition(
                      scale: CurvedAnimation(
                          parent: animation, curve: Curves.easeOutBack),
                      child: FadeTransition(
                        opacity: animation,
                        child: const ShopDialog(),
                      ),
                    );
                  },
                );
              },
              clickResponsiveness: true,
              onHoverGlow: true,
              isClickable: true,
            ),
          ),
          Positioned(
            bottom: MediaQuery.of(context).size.height * 0.19,
            left: 20,
            child: MakeItButton(
              imagePath: 'assets/images/dashboard/signage.png',
              width: 110,
              height: 110,
              onTap: () {
                if (!_isBackendReady) {
                  showCustomSnackBar(
                    context,
                    'Backend is waking up... please wait 30-60 seconds.',
                    type: SnackBarType.info,
                  );
                  _pingBackend();
                  return;
                }
                showGeneralDialog(
                  context: context,
                  barrierLabel: "ChatDialog",
                  barrierDismissible: true,
                  barrierColor: const Color.fromRGBO(0, 0, 0, 0.5),
                  transitionDuration: const Duration(milliseconds: 300),
                  pageBuilder: (context, animation, secondaryAnimation) {
                    return ScaleTransition(
                      scale: CurvedAnimation(
                          parent: animation, curve: Curves.easeOutBack),
                      child: FadeTransition(
                        opacity: animation,
                        child: const Center(child: ChatDialog()),
                      ),
                    );
                  },
                );
              },
              clickResponsiveness: true,
              onHoverGlow: true,
              isClickable: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrencyChip({
    required IconData icon,
    required String value,
    required Color color,
    VoidCallback? onPlusTap,
  }) {
    return LiquidGlassDialog(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      borderRadius: 12,
      blurSigma: 4,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
          if (onPlusTap != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onPlusTap,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.add, color: color, size: 14),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
