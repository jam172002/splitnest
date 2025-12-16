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
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      await context.read<AuthRepo>().register(_email.text.trim(), _pass.text.trim());
      if (mounted) context.go('/app/groups');
    } catch (e) {
      setState(() => _err = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Create account',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _email,
            decoration: const InputDecoration(labelText: 'Email'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pass,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Password'),
          ),
          const SizedBox(height: 16),
          if (_err != null)
            Text(_err!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 8),
          BusyButton(busy: _busy, onPressed: _register, text: 'Register'),
          TextButton(
            onPressed: () => context.go('/login'),
            child: const Text('Back to login'),
          ),
        ],
      ),
    );
  }
}
