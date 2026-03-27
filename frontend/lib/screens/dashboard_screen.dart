import 'package:dreamhunter/services/connectivity_service.dart';
import 'package:dreamhunter/services/dashboard_controller.dart';
import 'package:dreamhunter/services/roulette_service.dart';
import 'package:dreamhunter/widgets/dashboard/currency_display.dart';
import 'package:dreamhunter/widgets/dashboard/action_menu.dart';
import 'package:dreamhunter/widgets/dashboard/exchange_module.dart';
import 'package:dreamhunter/widgets/shop_dialog.dart';
import 'package:dreamhunter/widgets/custom_snackbar.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dreamhunter/widgets/login_dialog.dart';
import 'package:dreamhunter/widgets/register_dialog.dart';
import 'package:dreamhunter/widgets/profile_dialog.dart';
import 'package:dreamhunter/widgets/chat_dialog.dart';
import 'package:dreamhunter/widgets/leaderboard_dialog.dart';
import 'package:dreamhunter/widgets/daily_tasks_dialog.dart';
import 'package:dreamhunter/widgets/roulette_dialog.dart';
import 'package:dreamhunter/widgets/settings_dialog.dart';
import 'package:dreamhunter/widgets/clickable_image.dart';

enum AuthDialogType { login, register, profile }

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late StreamSubscription<User?> _authStateSubscription;
  final DashboardController _controller = DashboardController();
  bool _isLoggedIn = false;
  AuthDialogType _currentDialogType = AuthDialogType.login;

  @override
  void initState() {
    super.initState();
    ConnectivityService().initialize();
    _controller.initialize();
    _checkPendingRouletteRewards();
    _isLoggedIn = FirebaseAuth.instance.currentUser != null;
    _authStateSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (mounted) {
        setState(() => _isLoggedIn = user != null);
      }
    });
  }

  Future<void> _checkPendingRouletteRewards() async {
    // Wait for the controller to be initialized properly
    await Future.delayed(const Duration(seconds: 1));
    
    final state = await RouletteService.getAndSyncState();
    
    // Only auto-claim if it's NOT spinning. 
    // If it IS spinning, the RouletteDialog will handle the resumption.
    if (state.pendingReward != null && !state.isSpinning) {
      final reward = state.pendingReward!;
      final amount = (reward['amount'] as num).toInt();
      final name = reward['name'] as String;

      await _controller.updateCurrency(
        newCoins: _controller.dreamCoins + amount,
      );
      await RouletteService.clearPendingReward();

      if (mounted) {
        showCustomSnackBar(
          context,
          'You received $name from your last spin!',
          type: SnackBarType.success,
        );
      }
    }
  }

  @override
  void dispose() {
    _authStateSubscription.cancel();
    super.dispose();
  }

  Future<void> _showGameDialog(Widget dialog) async {
    await showGeneralDialog(
      context: context,
      barrierLabel: "GameDialog",
      barrierDismissible: true,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          child: FadeTransition(opacity: animation, child: dialog),
        );
      },
    );
    _controller.refreshCurrency();
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
                  child: DashboardActionMenu(
                    onDailyTasksTap: () {
                      Navigator.pop(context);
                      _showGameDialog(const DailyTasksDialog());
                    },
                    onLeaderboardTap: () {
                      Navigator.pop(context);
                      _showGameDialog(const LeaderboardDialog());
                    },
                    onSettingsTap: () {
                      Navigator.pop(context);
                      _showGameDialog(SettingsDialog(
                        onLoginRequested: () {
                          Navigator.pop(context);
                          _showAuthDialog();
                        },
                      ));
                    },
                    onExitTap: () {
                      if (Platform.isAndroid || Platform.isIOS) {
                        SystemNavigator.pop();
                      } else {
                        exit(0);
                      }
                    },
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showAuthDialog() {
    setState(() {
      _currentDialogType = _isLoggedIn ? AuthDialogType.profile : AuthDialogType.login;
    });

    showGeneralDialog(
      context: context,
      barrierLabel: "AuthDialog",
      barrierDismissible: true,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Widget dialogContent;
            const double dialogWidth = 350;
            const double dialogHeight = 600;

            switch (_currentDialogType) {
              case AuthDialogType.login:
                dialogContent = LoginDialog(
                  onRegisterRequested: () => setDialogState(() => _currentDialogType = AuthDialogType.register),
                  onLoginSuccess: () {
                    setDialogState(() {
                      _isLoggedIn = true;
                      _currentDialogType = AuthDialogType.profile;
                    });
                    showCustomSnackBar(context, 'Welcome back!', type: SnackBarType.success);
                  },
                );
                break;
              case AuthDialogType.register:
                dialogContent = RegisterDialog(
                  onLoginRequested: () => setDialogState(() => _currentDialogType = AuthDialogType.login),
                  onRegisterSuccess: () {
                    setDialogState(() => _currentDialogType = AuthDialogType.login);
                    showCustomSnackBar(context, 'Account created! Please log in.', type: SnackBarType.success);
                  },
                );
                break;
              case AuthDialogType.profile:
                dialogContent = ProfileDialog(
                  onLogoutRequested: () => setDialogState(() {
                    _isLoggedIn = false;
                    _currentDialogType = AuthDialogType.login;
                  }),
                );
                break;
            }

            final double dialogX = (MediaQuery.of(context).size.width - dialogWidth) / 2;
            final double dialogY = (MediaQuery.of(context).size.height - dialogHeight) / 2 + 100;

            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: dialogX,
                  top: dialogY,
                  child: SizedBox(
                    width: dialogWidth,
                    height: dialogHeight,
                    child: dialogContent,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        toolbarHeight: 100,
        leadingWidth: 300,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16.0, top: 8.0),
          child: CurrencyDisplay(
            controller: _controller,
            onProfileTap: _showAuthDialog,
            onExchangeTap: () => _showGameDialog(ExchangeDialogContent(
              onBackTap: () => Navigator.pop(context),
              controller: _controller,
            )),
            onPurchaseTap: () => _showGameDialog(PurchaseDialogContent(onBackTap: () => Navigator.pop(context))),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: GlassButton(
              imagePath: 'assets/images/dashboard/sandwich.png',
              width: 45,
              height: 45,
              onTap: _showDropdownMenu,
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(child: Image.asset('assets/images/dashboard/main_background.png', fit: BoxFit.cover)),
          Positioned(
            bottom: MediaQuery.of(context).size.height * 0.15,
            left: 0,
            right: 0,
            child: Center(
              child: Image.asset('assets/images/game/environment/dorm.png', fit: BoxFit.contain, width: MediaQuery.of(context).size.width * 0.85),
            ),
          ),
          Positioned(
            bottom: -20,
            left: -20,
            child: GlassButton(
              imagePath: 'assets/images/dashboard/roulette_man.png',
              width: 220,
              height: 220,
              onTap: () => _showGameDialog(RouletteDialog(
              controller: _controller,
              parentContext: context,
              onSpinCompleted: () => _controller.refreshCurrency(),
            )),
            ),
          ),
          Positioned(
            bottom: -20,
            right: -20,
            child: GlassButton(
              imagePath: 'assets/images/dashboard/shop_stall.png',
              width: 220,
              height: 220,
              onTap: () => _showGameDialog(const ShopDialog()),
            ),
          ),
          Positioned(
            bottom: MediaQuery.of(context).size.height * 0.19,
            left: 20,
            child: GlassButton(
              imagePath: 'assets/images/dashboard/signage.png',
              width: 120,
              height: 120,
              onTap: () => _showGameDialog(const Center(child: ChatDialog())),
            ),
          ),
        ],
      ),
    );
  }
}
