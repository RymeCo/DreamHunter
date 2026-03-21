import 'package:dreamhunter/services/auth_service.dart';
import 'package:dreamhunter/services/auth_ui_helper.dart';
import 'package:dreamhunter/widgets/custom_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  void _login() async {
    if (_formKey.currentState!.validate()) {
      try {
        await _authService.signIn(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );
        if (mounted) {
          showCustomSnackBar(context, 'Successfully logged in. Welcome back!',
              type: SnackBarType.success);
        }
        widget.onLoginSuccess();
      } on FirebaseAuthException catch (e) {
        if (!mounted) return;
        String message;
        switch (e.code) {
          case 'user-not-found':
            message = 'No account found with this email.';
            break;
          case 'wrong-password':
            message = 'Incorrect password.';
            break;
          case 'too-many-requests':
            message = 'Too many attempts. Try again later.';
            break;
          default:
            message = e.message ?? 'An error occurred during login.';
        }
        showCustomSnackBar(context, message, type: SnackBarType.error);
      } catch (e) {
        if (!mounted) return;
        showCustomSnackBar(context, 'Unexpected error: $e',
            type: SnackBarType.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
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
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _passwordController,
                style: const TextStyle(color: Colors.white),
                obscureText: true,
                decoration: AuthUIHelper.inputDecoration('Password'),
                validator: AuthUIHelper.validatePassword,
              ),
              const SizedBox(height: 25),
              ElevatedButton(
                onPressed: _login,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromRGBO(255, 255, 255, 0.3),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 40, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: const BorderSide(
                        color: Color.fromRGBO(255, 255, 255, 0.5)),
                  ),
                ),
                child: const Text('Login',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              TextButton(
                onPressed: widget.onRegisterRequested,
                child: const Text("Don't have an account? Register",
                    style:
                        TextStyle(color: Color.fromRGBO(255, 255, 255, 0.8))),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
