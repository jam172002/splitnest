import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../data/auth_repo.dart';
import '../../../data/group_repo.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/busy_button.dart';

class JoinGroupScreen extends StatefulWidget {
  const JoinGroupScreen({super.key});

  @override
  State<JoinGroupScreen> createState() => _JoinGroupScreenState();
}

class _JoinGroupScreenState extends State<JoinGroupScreen> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _err;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final code = _code.text.trim();
    if (code.isEmpty) {
      setState(() => _err = "Please enter an invite code");
      return;
    }

    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      final auth = context.read<AuthRepo>();
      final u = auth.currentUser!;
      await context.read<GroupRepo>().joinGroup(
        groupId: code,
        uid: u.uid,
        email: u.email ?? '',
      );
      if (mounted) context.go('/group/$code');
    } catch (e) {
      setState(() => _err = "Invalid code or group not found");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppScaffold(
      title: 'Join Group',
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Header Section ---
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withOpacity(0.4),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.key_rounded,
                size: 64,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "Have an invite code?",
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Enter the group ID shared by your friend to start splitting expenses together.",
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 40),

            // --- Input Section ---
            TextField(
              controller: _code,
              autofocus: true,
              style: theme.textTheme.titleMedium?.copyWith(
                letterSpacing: 1.5,
                fontWeight: FontWeight.bold,
              ),
              decoration: InputDecoration(
                labelText: 'Group ID / Invite Code',
                hintText: 'e.g. kJH32k...',
                prefixIcon: const Icon(Icons.qr_code_scanner_rounded),
                helperText: 'The code is case-sensitive',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.paste_rounded),
                  onPressed: () {
                    // You could add clipboard paste logic here
                  },
                ),
              ),
            ),

            const SizedBox(height: 32),

            if (_err != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: colorScheme.error, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _err!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            BusyButton(
              busy: _busy,
              onPressed: _join,
              text: 'Join Group',
            ),
          ],
        ),
      ),
    );
  }
}