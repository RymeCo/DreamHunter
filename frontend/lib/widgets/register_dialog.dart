import 'package:dreamhunter/services/auth_service.dart';
import 'package:dreamhunter/services/auth_ui_helper.dart';
import 'package:dreamhunter/widgets/custom_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  void _register() async {
    if (_formKey.currentState!.validate()) {
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
        if (mounted) {
          showCustomSnackBar(
            context,
            'Account created! Please log in.',
            type: SnackBarType.success,
          );
        }
        widget.onRegisterSuccess();
      } on FirebaseAuthException catch (e) {
        if (!mounted) return;
        String message;
        switch (e.code) {
          case 'email-already-in-use':
            message = 'This email is already in use.';
            break;
          case 'display-name-taken':
            message = 'This display name is already taken.';
            break;
          case 'weak-password':
            message = 'Password is too weak.';
            break;
          default:
            message = e.message ?? 'An error occurred during registration.';
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
                decoration: AuthUIHelper.inputDecoration('Confirm Password'),
                validator: (value) {
                  if (value != _passwordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 25),
              ElevatedButton(
                onPressed: _register,
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
                child: const Text('Register',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              TextButton(
                onPressed: widget.onLoginRequested,
                child: const Text('Already have an account? Login',
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
