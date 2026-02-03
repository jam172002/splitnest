import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../data/auth_repo.dart';
import '../../../data/notifications_repo.dart';
import '../../widgets/busy_button.dart';
import '../../widgets/app_scaffold.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _name = TextEditingController();    // ← NEW
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _busy = false;
  String? _err;

  @override
  void dispose() {
    _name.dispose();    // ← NEW
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (_name.text.trim().isEmpty || _email.text.trim().isEmpty || _pass.text.trim().isEmpty) {
      setState(() => _err = "Please fill in all fields");
      return;
    }

    setState(() {
      _busy = true;
      _err = null;
    });

    try {
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _email.text.trim(),
        password: _pass.text.trim(),
      );

      // Save name to Firebase Auth display name
      await credential.user?.updateDisplayName(_name.text.trim());

      // Save to Firestore users collection
      await FirebaseFirestore.instance.collection('users').doc(credential.user!.uid).set({
        'name': _name.text.trim(),
        'email': _email.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Your existing notification setup
      final uid = credential.user!.uid;
      await context.read<NotificationsRepo>().initAndSaveToken(uid);

      if (mounted) context.go('/');
    } catch (e) {
      setState(() => _err = "Registration failed: ${e.toString().split(']').last}");
    } finally {
      if (mounted) setState(() => _busy = false);
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
                obscureText: true,
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