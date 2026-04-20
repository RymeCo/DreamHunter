import 'package:flutter/material.dart';
import 'package:dreamhunter/widgets/identity/login_dialog.dart';
import 'package:dreamhunter/widgets/identity/register_dialog.dart';
import 'package:dreamhunter/widgets/identity/profile_dialog.dart';
import 'package:dreamhunter/widgets/custom_snackbar.dart';

enum AuthDialogType { login, register, profile }

/// A stateful manager for the authentication flow, switching between Login, Register, and Profile views.
class AuthFlowDialog extends StatefulWidget {
  final bool initialIsLoggedIn;
  final Function(bool) onAuthStateChanged;

  const AuthFlowDialog({
    super.key,
    required this.initialIsLoggedIn,
    required this.onAuthStateChanged,
  });

  @override
  State<AuthFlowDialog> createState() => _AuthFlowDialogState();
}

class _AuthFlowDialogState extends State<AuthFlowDialog> {
  late AuthDialogType _currentType;
  late bool _isLoggedIn;

  @override
  void initState() {
    super.initState();
    _isLoggedIn = widget.initialIsLoggedIn;
    _currentType = _isLoggedIn ? AuthDialogType.profile : AuthDialogType.login;
  }

  @override
  Widget build(BuildContext context) {
    Widget content;
    const double width = 350;
    const double height = 600;

    switch (_currentType) {
      case AuthDialogType.login:
        content = LoginDialog(
          onRegisterRequested: () => setState(() => _currentType = AuthDialogType.register),
          onLoginSuccess: () {
            setState(() {
              _isLoggedIn = true;
              _currentType = AuthDialogType.profile;
            });
            widget.onAuthStateChanged(true);
            showCustomSnackBar(context, 'Welcome back!', type: SnackBarType.success);
          },
        );
        break;
      case AuthDialogType.register:
        content = RegisterDialog(
          onLoginRequested: () => setState(() => _currentType = AuthDialogType.login),
          onRegisterSuccess: () {
            setState(() => _currentType = AuthDialogType.login);
            showCustomSnackBar(context, 'Account created! Please log in.', type: SnackBarType.success);
          },
        );
        break;
      case AuthDialogType.profile:
        content = ProfileDialog(
          onLogoutRequested: () {
            setState(() {
              _isLoggedIn = false;
              _currentType = AuthDialogType.login;
            });
            widget.onAuthStateChanged(false);
          },
        );
        break;
    }

    return Center(
      child: Transform.translate(
        offset: const Offset(0, 100), // Original UI offset
        child: SizedBox(
          width: width,
          height: height,
          child: content,
        ),
      ),
    );
  }
}
