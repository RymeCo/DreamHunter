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
    const double dialogWidth = 350;

    switch (_currentType) {
      case AuthDialogType.login:
        return Center(
          child: Transform.translate(
            offset: const Offset(0, 50),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: dialogWidth,
                maxHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              child: LoginDialog(
                onRegisterRequested: () =>
                    setState(() => _currentType = AuthDialogType.register),
                onLoginSuccess: () {
                  setState(() {
                    _isLoggedIn = true;
                    _currentType = AuthDialogType.profile;
                  });
                  widget.onAuthStateChanged(true);
                  showCustomSnackBar(
                    context,
                    'Welcome back!',
                    type: SnackBarType.success,
                  );
                },
              ),
            ),
          ),
        );
      case AuthDialogType.register:
        return Center(
          child: Transform.translate(
            offset: const Offset(0, 50),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: dialogWidth,
                maxHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              child: RegisterDialog(
                onLoginRequested: () =>
                    setState(() => _currentType = AuthDialogType.login),
                onRegisterSuccess: () {
                  setState(() {
                    _isLoggedIn = true;
                    _currentType = AuthDialogType.profile;
                  });
                  widget.onAuthStateChanged(true);
                  showCustomSnackBar(
                    context,
                    'Account created! Welcome to DreamHunter.',
                    type: SnackBarType.success,
                  );
                },
              ),
            ),
          ),
        );
      case AuthDialogType.profile:
        return ProfileDialog(
          onLogoutRequested: () {
            setState(() {
              _isLoggedIn = false;
              _currentType = AuthDialogType.login;
            });
            widget.onAuthStateChanged(false);
          },
        );
    }
  }
}
