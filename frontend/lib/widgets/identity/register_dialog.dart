import 'package:dreamhunter/services/identity/auth_manager.dart';
import 'package:dreamhunter/services/identity/profile_manager.dart';
import 'package:dreamhunter/widgets/custom_snackbar.dart';
import 'package:dreamhunter/widgets/liquid_glass_dialog.dart';
import 'package:dreamhunter/services/core/audio_manager.dart';
import 'package:dreamhunter/widgets/identity/save_resolution_dialog.dart';
import 'package:dreamhunter/services/core/storage_engine.dart';
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
        final cred = await _authService.register(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          displayName: _displayNameController.text.trim(),
        );

        if (mounted) {
          // Resolve save conflict before finishing
          if (StorageEngine.instance.hasGuestData()) {
            await StorageEngine.instance.setPendingConflict(true);
          }
          if (mounted) {
            await SaveResolutionDialog.showIfNeeded(context, cred.user!.uid);
          }

          // Sync with live backend to create initial Firestore profile
          await ProfileManager.instance.syncWithBackend();

          setState(() => _isLoading = false);
          widget.onRegisterSuccess();
        }
      } catch (e) {
        debugPrint('Registration error: $e');
        if (mounted) setState(() => _isLoading = false);
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
      ],
    );
  }
}
