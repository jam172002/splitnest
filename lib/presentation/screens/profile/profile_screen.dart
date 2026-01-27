import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../../data/auth_repo.dart';
import '../../widgets/app_scaffold.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final auth = context.watch<AuthRepo>();
    final u = auth.currentUser;

    return AppScaffold(
      title: 'Profile',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // --- User Header Section ---
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: colorScheme.primaryContainer,
                    child: Icon(Icons.person_outline, size: 50, color: colorScheme.primary),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    u?.email ?? 'User Account',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text('Member since 2026', style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // --- App Information Card ---
            _buildSectionHeader(context, 'About SplitNest'),
            Card(
              elevation: 0,
              color: colorScheme.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.5)),
              ),
              child: Column(
                children: [
                  _infoTile(
                      context,
                      Icons.verified_outlined,
                      'Approval Logic',
                      'Any endorsement approves an entry.'
                  ),
                  const Divider(indent: 56, endIndent: 16),
                  _infoTile(
                      context,
                      Icons.vpn_key_outlined,
                      'Invite System',
                      'Your Group ID serves as the invite code.'
                  ),
                  const Divider(indent: 56, endIndent: 16),
                  _infoTile(
                      context,
                      Icons.notifications_active_outlined,
                      'Notifications',
                      'FCM support coming in future updates.'
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // --- Actions Section ---
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  // Show a confirmation dialog for a better UX
                  final confirm = await _showLogoutDialog(context);
                  if (confirm == true) {
                    await context.read<AuthRepo>().logout();
                    if (context.mounted) context.go('/login');
                  }
                },
                icon: const Icon(Icons.logout),
                label: const Text('Sign Out'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colorScheme.error,
                  side: BorderSide(color: colorScheme.error),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text('Version 1.0.0 (MVP)', style: theme.textTheme.labelSmall),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title.toUpperCase(),
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }

  Widget _infoTile(BuildContext context, IconData icon, String title, String subtitle) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.secondary),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle),
    );
  }

  Future<bool?> _showLogoutDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out?'),
        content: const Text('Are you sure you want to log out of SplitNest?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Sign Out', style: TextStyle(color: Theme.of(context).colorScheme.error))
          ),
        ],
      ),
    );
  }
}