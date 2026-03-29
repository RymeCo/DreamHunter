import 'package:dreamhunter/services/auth_service.dart';
import 'package:dreamhunter/services/auth_ui_helper.dart';
import 'package:dreamhunter/widgets/custom_snackbar.dart';
import 'package:dreamhunter/widgets/liquid_glass_dialog.dart';
import 'package:flutter/material.dart';

class RegisterDialog extends StatefulWidget {
  final VoidCallback onLoginRequested;
  final VoidCallback onRegisterSuccess;

  const RegisterDialog({
    super.key,
    required this.onLoginRequested,
    required this.onRegisterSuccess,
  });

  @override
  State<RegisterDialog> createState() => _RegisterDialogState();
}

class _RegisterDialogState extends State<RegisterDialog> {
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  void _register() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });
      // Show initial feedback
      showCustomSnackBar(
        context,
        'Creating account... Please wait as your data is loading and becoming live.',
        type: SnackBarType.info,
      );

      try {
        await _authService.register(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          displayName: _displayNameController.text.trim(),
        );
      } catch (e) {
        debugPrint('Registration error (ignored in UI-only mode): $e');
      }

      if (mounted) {
        _displayNameController.clear();
        _emailController.clear();
        _passwordController.clear();
        _confirmPasswordController.clear();

        setState(() {
          _isLoading = false;
        });
        widget.onRegisterSuccess();
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
                    controller: _displayNameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: AuthUIHelper.inputDecoration('Display Name'),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Enter display name';
                      }
                      if (value.length < 3) {
                        return 'At least 3 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 15),
                  TextFormField(
                    controller: _emailController,
                    style: const TextStyle(color: Colors.white),
                    decoration: AuthUIHelper.inputDecoration('Email'),
                    validator: AuthUIHelper.validateEmail,
                  ),
                  const SizedBox(height: 15),
                  TextFormField(
                    controller: _passwordController,
                    style: const TextStyle(color: Colors.white),
                    obscureText: true,
                    decoration: AuthUIHelper.inputDecoration('Password'),
                    validator: AuthUIHelper.validatePassword,
                  ),
                  const SizedBox(height: 15),
                  TextFormField(
                    controller: _confirmPasswordController,
                    style: const TextStyle(color: Colors.white),
                    obscureText: true,
                    decoration: AuthUIHelper.inputDecoration(
                      'Confirm Password',
                    ),
                    validator: (value) {
                      if (value != _passwordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 25),
                  AuthUIHelper.primaryButton(
                    label: 'Register',
                    onPressed: _register,
                    isLoading: _isLoading,
                  ),
                  TextButton(
                    onPressed: widget.onLoginRequested,
                    child: const Text(
                      'Already have an account? Login',
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
              'assets/images/auth/register_logo.png',
              fit: BoxFit.contain,
            ),
          ),
        ),
      ],
    );
  }
}
