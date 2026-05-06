import 'package:firebase_auth/firebase_auth.dart';
import 'package:dreamhunter/services/identity/auth_manager.dart';
import 'package:dreamhunter/services/identity/profile_manager.dart';
import 'package:dreamhunter/widgets/custom_snackbar.dart';
import 'package:dreamhunter/widgets/liquid_glass_dialog.dart';
import 'package:dreamhunter/widgets/identity/verification_notice_dialog.dart';
import 'package:dreamhunter/services/core/audio_manager.dart';
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
  final AuthManager _authService = AuthManager();
  bool _isLoading = false;

  void _register() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      showCustomSnackBar(
        context,
        'Forging your identity... Please wait.',
        type: SnackBarType.info,
      );

      try {
        await _authService.register(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          displayName: _displayNameController.text.trim(),
        );

        // Send verification email immediately
        await _authService.sendEmailVerification();

        if (mounted) {
          // Sync with live backend to create initial Firestore profile
          await ProfileManager.instance.syncWithBackend();

          setState(() => _isLoading = false);

          // Show verification notice before finalizing
          if (mounted) {
            await showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => VerificationNoticeDialog(
                email: _emailController.text.trim(),
                onContinue: () => Navigator.pop(context),
              ),
            );
          }

          if (mounted) widget.onRegisterSuccess();
        }
      } on FirebaseAuthException catch (e) {
        String message = 'Registration failed.';
        if (e.code == 'weak-password') {
          message = 'The password provided is too weak.';
        } else if (e.code == 'email-already-in-use') {
          message = 'An account already exists for that email.';
        } else if (e.code == 'invalid-email') {
          message = 'The email address is badly formatted.';
        }

        if (mounted) {
          showCustomSnackBar(context, message, type: SnackBarType.error);
          setState(() => _isLoading = false);
        }
      } catch (e) {
        if (mounted) {
          showCustomSnackBar(
            context,
            'An unexpected error occurred.',
            type: SnackBarType.error,
          );
          setState(() => _isLoading = false);
        }
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
                    decoration: const InputDecoration(
                      labelText: 'Display Name',
                    ),
                    validator: (v) =>
                        (v == null || v.length < 3) ? 'Min 3 characters' : null,
                  ),
                  const SizedBox(height: 15),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(labelText: 'Email'),
                    validator: (v) => (v == null || !v.contains('@'))
                        ? 'Enter a valid email'
                        : null,
                  ),
                  const SizedBox(height: 15),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Password'),
                    validator: (v) =>
                        (v == null || v.length < 6) ? 'Min 6 characters' : null,
                  ),
                  const SizedBox(height: 15),
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Confirm Password',
                    ),
                    validator: (v) => (v != _passwordController.text)
                        ? 'Passwords do not match'
                        : null,
                  ),
                  const SizedBox(height: 25),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _register,
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'REGISTER',
                              style: Theme.of(
                                context,
                              ).textTheme.labelLarge?.copyWith(fontSize: 18),
                            ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      AudioManager().playClick();
                      widget.onLoginRequested();
                    },
                    child: Text(
                      'Already have an account? Login',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: -180,
          child: IgnorePointer(
            child: Container(
              width: 360,
              height: 360,
              decoration: const BoxDecoration(shape: BoxShape.circle),
              child: Image.asset(
                'assets/images/dashboard/auth/register_logo.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
