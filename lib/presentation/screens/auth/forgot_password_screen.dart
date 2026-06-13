import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../data/auth_repo.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/busy_button.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _email = TextEditingController();
  bool _busy = false;
  String? _error;
  String? _sentToEmail;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _sendResetLink() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Enter your email address');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    final authRepo = context.read<AuthRepo>();

    try {
      await authRepo.sendPasswordResetEmail(email);
      if (!mounted) return;
      setState(() => _sentToEmail = email);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = switch (e.code) {
          'invalid-email' => 'Enter a valid email address',
          'too-many-requests' =>
            'Too many attempts. Please wait a moment and try again.',
          'network-request-failed' =>
            'Check your internet connection and try again.',
          _ => 'Unable to send the reset link. Please try again.',
        };
      });
    } catch (_) {
      if (mounted) {
        setState(
            () => _error = 'Unable to send the reset link. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return AppScaffold(
      title: '',
      automaticallyImplyLeading: false,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: _sentToEmail == null
              ? _buildResetForm(theme, colors)
              : _buildSuccessMessage(theme, colors),
        ),
      ),
    );
  }

  Widget _buildResetForm(ThemeData theme, ColorScheme colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.lock_reset_rounded, size: 72, color: colors.primary),
        const SizedBox(height: 20),
        Text(
          'Forgot password?',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Enter the email address linked to your account. We will send you a link to reset your password.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 32),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.email],
          onSubmitted: (_) => _sendResetLink(),
          decoration: const InputDecoration(
            labelText: 'Email Address',
            prefixIcon: Icon(Icons.email_outlined),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 14),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.error, fontSize: 13),
          ),
        ],
        const SizedBox(height: 24),
        BusyButton(
          busy: _busy,
          onPressed: _sendResetLink,
          text: 'Send Reset Link',
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: _busy ? null : () => context.go('/login'),
          icon: const Icon(Icons.arrow_back_rounded),
          label: const Text('Back to sign in'),
        ),
      ],
    );
  }

  Widget _buildSuccessMessage(ThemeData theme, ColorScheme colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.mark_email_read_outlined, size: 76, color: colors.primary),
        const SizedBox(height: 20),
        Text(
          'Reset link sent',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'We sent a password reset link to',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _sentToEmail!,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Open the link in your email to choose a new password. If you do not see it, check your spam folder.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 28),
        FilledButton(
          onPressed: () => context.go('/login'),
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Text('Back to Sign In'),
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () {
            setState(() {
              _sentToEmail = null;
              _error = null;
            });
          },
          child: const Text('Use a different email'),
        ),
      ],
    );
  }
}
