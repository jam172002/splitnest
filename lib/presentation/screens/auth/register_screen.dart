import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../data/auth_repo.dart';
import '../../widgets/busy_button.dart';
import '../../widgets/app_scaffold.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _busy = false;
  String? _err;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (_email.text.isEmpty || _pass.text.isEmpty) {
      setState(() => _err = "Please enter both email and password");
      return;
    }

    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      await context.read<AuthRepo>().register(_email.text.trim(), _pass.text.trim());
      if (mounted) context.go('/app/groups');
    } catch (e) {
      setState(() => _err = "Registration failed. Please check your details.");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppScaffold(
      title: '', // Keep app bar clean for auth screens
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- Header Section ---
              Icon(
                Icons.person_add_rounded,
                size: 80,
                color: colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Join SplitNest',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Start splitting expenses with ease.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 48),

              // --- Form Fields ---
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Email Address',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _pass,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock_outline_rounded),
                ),
                onSubmitted: (_) => _register(),
              ),
              const SizedBox(height: 24),

              // --- Error Display ---
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
                  text: 'Create Account'
              ),
              const SizedBox(height: 16),

              // --- Back to Login ---
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Already have an account?",
                    style: theme.textTheme.bodyMedium,
                  ),
                  TextButton(
                    onPressed: () => context.go('/login'),
                    child: const Text('Sign In'),
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