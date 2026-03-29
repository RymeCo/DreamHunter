import 'package:dreamhunter/services/auth_service.dart';
import 'package:dreamhunter/services/auth_ui_helper.dart';
import 'package:dreamhunter/widgets/custom_snackbar.dart';
import 'package:dreamhunter/widgets/liquid_glass_dialog.dart';
import 'package:flutter/material.dart';

class LoginDialog extends StatefulWidget {
  final VoidCallback onRegisterRequested;
  final VoidCallback onLoginSuccess;

  const LoginDialog({
    super.key,
    required this.onRegisterRequested,
    required this.onLoginSuccess,
  });

  @override
  State<LoginDialog> createState() => _LoginDialogState();
}

class _LoginDialogState extends State<LoginDialog> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  void _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      // Show initial feedback
      showCustomSnackBar(
        context,
        'Logging in... Please wait as your data is loading and becoming live.',
        type: SnackBarType.info,
      );

      try {
        await _authService.signIn(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );
      } catch (e) {
        debugPrint('Auth error (ignored in UI-only mode): $e');
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        widget.onLoginSuccess();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        LiquidGlassDialog(
          padding: const EdgeInsets.fromLTRB(24, 80, 24, 24),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _emailController,
                    style: const TextStyle(color: Colors.white),
                    decoration: AuthUIHelper.inputDecoration('Email'),
                    validator: AuthUIHelper.validateEmail,
                    enabled: !_isLoading,
                  ),
                  const SizedBox(height: 15),
                  TextFormField(
                    controller: _passwordController,
                    style: const TextStyle(color: Colors.white),
                    obscureText: true,
                    decoration: AuthUIHelper.inputDecoration('Password'),
                    validator: AuthUIHelper.validatePassword,
                    enabled: !_isLoading,
                  ),
                  const SizedBox(height: 25),
                  AuthUIHelper.primaryButton(
                    label: 'Login',
                    onPressed: _login,
                    isLoading: _isLoading,
                  ),
                  TextButton(
                    onPressed: widget.onRegisterRequested,
                    child: const Text(
                      "Don't have an account? Register",
                      style: TextStyle(
                        color: Color.fromRGBO(255, 255, 255, 0.8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: -180,
          child: Container(
            width: 360,
            height: 360,
            decoration: const BoxDecoration(shape: BoxShape.circle),
            child: Image.asset(
              'assets/images/auth/login_logo.png',
              fit: BoxFit.contain,
            ),
          ),
        ),
      ],
    );
  }
}
