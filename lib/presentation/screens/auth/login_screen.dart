import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../data/auth_repo.dart';
import '../../../data/notifications_repo.dart';
import '../../widgets/busy_button.dart';
import '../../widgets/app_scaffold.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
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

  Future<void> _login() async {
    if (_email.text.isEmpty || _pass.text.isEmpty) {
      setState(() => _err = "Please fill in all fields");
      return;
    }

    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      await context.read<AuthRepo>().login(_email.text.trim(), _pass.text.trim());
      final uid = context.read<AuthRepo>().currentUser!.uid;
      await context.read<NotificationsRepo>().initAndSaveToken(uid);
      if (mounted) context.go('/app/groups');
    } catch (e) {
      // Friendly error mapping
      setState(() => _err = "Invalid email or password");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppScaffold(
      // We'll leave title empty or minimal for a modern login look
      title: '',
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- Brand Section ---
              Icon(
                Icons.home_work_rounded, // A "Nest" themed icon
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

              // --- Form Section ---
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
                onSubmitted: (_) => _login(),
                decoration: const InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock_outline_rounded),
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
                  onPressed: _login,
                  text: 'Sign In'
              ),

              const SizedBox(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Don't have an account?",
                    style: theme.textTheme.bodyMedium,
                  ),
                  TextButton(
                    onPressed: () => context.go('/register'),
                    child: const Text('Create one'),
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