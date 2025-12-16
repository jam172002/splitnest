import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../../data/auth_repo.dart';
import '../../widgets/app_scaffold.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthRepo>();
    final u = auth.currentUser;

    return AppScaffold(
      title: 'Profile',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Email: ${u?.email ?? '-'}'),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () async {
              await context.read<AuthRepo>().logout();
              if (context.mounted) context.go('/login');
            },
            child: const Text('Sign out'),
          ),
          const SizedBox(height: 16),
          Text(
            'MVP Notes:\n'
                '- Approvals: any endorsement approves.\n'
                '- Group invite code = Group ID.\n'
                '- FCM notifications can be added via Cloud Functions later.',
            style: TextStyle(color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }
}
