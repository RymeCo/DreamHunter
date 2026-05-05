import 'package:firebase_auth/firebase_auth.dart';
import 'package:dreamhunter/services/identity/auth_manager.dart';
import 'package:dreamhunter/services/identity/profile_manager.dart';
import 'package:dreamhunter/widgets/custom_snackbar.dart';
import 'package:dreamhunter/widgets/liquid_glass_dialog.dart';
import 'package:dreamhunter/services/core/audio_manager.dart';
import 'package:dreamhunter/widgets/identity/save_resolution_dialog.dart';
import 'package:dreamhunter/services/core/storage_engine.dart';
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
  final AuthManager _authService = AuthManager();
  bool _isLoading = false;

  void _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      showCustomSnackBar(
        context,
        'Logging in... Synchronizing your dream data.',
        type: SnackBarType.info,
      );

      try {
        final cred = await _authService.signIn(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );

        if (mounted) {
          // Sync with live backend first to get current cloud state
          await ProfileManager.instance.syncWithBackend();

          // After sync, if guest data exists, check if we need conflict resolution
          if (StorageEngine.instance.hasGuestData()) {
            if (mounted) {
              await SaveResolutionDialog.showIfNeeded(context, cred.user!.uid);
            }
          }

          setState(() => _isLoading = false);
          widget.onLoginSuccess();
        }
      } on FirebaseAuthException catch (e) {
        String message = 'Authentication failed.';
        if (e.code == 'user-not-found') {
          message = 'No user found for that email.';
        } else if (e.code == 'wrong-password') {
          message = 'Wrong password provided.';
        } else if (e.code == 'invalid-email') {
          message = 'The email address is badly formatted.';
        } else if (e.code == 'user-disabled') {
          message = 'This user account has been disabled.';
        }

        if (mounted) {
          showCustomSnackBar(context, message, type: SnackBarType.error);
          setState(() => _isLoading = false);
        }
      } catch (e) {
        debugPrint('Auth error: $e');
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
                    controller: _emailController,
                    decoration: const InputDecoration(labelText: 'Email'),
                    validator: (v) =>
                        (v == null || v.isEmpty || !v.contains('@'))
                        ? 'Enter a valid email'
                        : null,
                    enabled: !_isLoading,
                  ),
                  const SizedBox(height: 15),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Password'),
                    validator: (v) =>
                        (v == null || v.length < 6) ? 'Min 6 characters' : null,
                    enabled: !_isLoading,
                  ),
                  const SizedBox(height: 25),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _login,
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
                              'LOGIN',
                              style: Theme.of(
                                context,
                              ).textTheme.labelLarge?.copyWith(fontSize: 18),
                            ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      AudioManager().playClick();
                      widget.onRegisterRequested();
                    },
                    child: Text(
                      "Don't have an account? Register",
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
                'assets/images/dashboard/auth/login_logo.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
