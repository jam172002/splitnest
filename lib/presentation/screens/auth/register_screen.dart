import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../data/auth_repo.dart';
import '../../../data/notifications_repo.dart';
import '../../widgets/busy_button.dart';
import '../../widgets/app_scaffold.dart';

final _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _confirmPass = TextEditingController();
  bool _busy = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _err;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _pass.dispose();
    _confirmPass.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final name = _name.text.trim();
    final email = _email.text.trim();
    final pass = _pass.text.trim();
    final confirmPass = _confirmPass.text.trim();

    if (name.isEmpty || email.isEmpty || pass.isEmpty || confirmPass.isEmpty) {
      setState(() => _err = "Please fill in all fields");
      return;
    }
    if (!_emailRegex.hasMatch(email)) {
      setState(() => _err = "Enter a valid email address");
      return;
    }
    if (pass.length < 6) {
      setState(() => _err = "Password must be at least 6 characters");
      return;
    }
    if (pass != confirmPass) {
      setState(() => _err = "Passwords do not match");
      return;
    }

    setState(() {
      _busy = true;
      _err = null;
    });
    final authRepo = context.read<AuthRepo>();
    final notificationsRepo = context.read<NotificationsRepo>();

    try {
      await authRepo.register(name, email, pass);
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _err = switch (e.code) {
            'email-already-in-use' => 'An account already exists for that email',
            'invalid-email' => 'Enter a valid email address',
            'weak-password' => 'Choose a stronger password',
            'network-request-failed' =>
              'Check your internet connection and try again.',
            _ => 'Unable to create your account. Please try again.',
          };
          _busy = false;
        });
      }
      return;
    } catch (_) {
      if (mounted) {
        setState(() {
          _err = 'Unable to create your account. Please try again.';
          _busy = false;
        });
      }
      return;
    }

    // Registration succeeded — don't let notification setup failures look like signup failures.
    try {
      final uid = authRepo.currentUser!.uid;
      await notificationsRepo.initAndSaveToken(uid);
    } catch (_) {}

    if (mounted) {
      setState(() => _busy = false);
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppScaffold(
      title: '',
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Brand Section
              Icon(
                Icons.home_work_rounded,
                size: 80,
                color: colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'SplitNest',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                  letterSpacing: -1,
                ),
              ),
              Text(
                'Fair splitting, simple living.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 48),

              // ──── NEW NAME FIELD ────
              TextField(
                controller: _name,
                keyboardType: TextInputType.name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email Address',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _pass,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    tooltip:
                        _obscurePassword ? 'Show password' : 'Hide password',
                    onPressed: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _confirmPass,
                obscureText: _obscureConfirmPassword,
                onSubmitted: (_) => _register(),
                decoration: InputDecoration(
                  labelText: 'Confirm Password',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    tooltip: _obscureConfirmPassword
                        ? 'Show password'
                        : 'Hide password',
                    onPressed: () {
                      setState(() =>
                          _obscureConfirmPassword = !_obscureConfirmPassword);
                    },
                    icon: Icon(
                      _obscureConfirmPassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              if (_err != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    _err!,
                    style: TextStyle(color: colorScheme.error, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ),

              BusyButton(
                busy: _busy,
                onPressed: _register,
                text: 'Sign Up',
              ),

              const SizedBox(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Already have an account?",
                    style: theme.textTheme.bodyMedium,
                  ),
                  TextButton(
                    onPressed: () => context.go('/login'),
                    child: const Text('Sign in'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
