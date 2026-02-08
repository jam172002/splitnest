import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../data/auth_repo.dart';
import '../../../theme/theme_mode_controller.dart';
import '../../widgets/app_scaffold.dart';


class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  static const Color kBrandGreen = Color(0xFF20C84A);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final auth = context.watch<AuthRepo>();
    final u = auth.currentUser;

    final displayName = (u?.displayName?.trim().isNotEmpty ?? false)
        ? u!.displayName!.trim()
        : 'User';

    final email = u?.email?.trim() ?? '';

    return AppScaffold(
      title: 'Profile',
      actions: [
        // ✅ Dark/Light toggle button (hook to your theme controller)
        IconButton(
          tooltip: 'Toggle theme',
          onPressed: () => context.read<ThemeModeController>().toggleDarkLight(),
          icon: Icon(
            Icons.brightness_6_rounded,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.75),
          ),
        ),
        const SizedBox(width: 6),
      ],
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---- Header (name first, email second) ----
            _ProfileHeader(
              name: displayName,
              email: email,
              accent: kBrandGreen,
            ),
            const SizedBox(height: 18),

            // ---- Clickable section header (opens dialog) ----
            _SectionHeader(
              title: 'About SplitNest',
              accent: kBrandGreen,
              onTap: () => _showInfoDialog(
                context,
                title: 'About SplitNest',
                message:
                'SplitNest helps you manage groups and shared expenses in a clean, simple way.',
              ),
            ),
            const SizedBox(height: 10),

            // ---- Professional: simple text rows (left aligned) ----
            _TextActionRow(
              title: 'Approval Logic',
              accent: kBrandGreen,
              onTap: () => _showInfoDialog(
                context,
                title: 'Approval Logic',
                message:
                'Entries are approved based on your group’s endorsement/approval rules.',
              ),
            ),
            _Divider(cs: cs),
            _TextActionRow(
              title: 'Invite System',
              accent: kBrandGreen,
              onTap: () => _showInfoDialog(
                context,
                title: 'Invite System',
                message:
                'You can join a group using its Group ID (invite code) shared by the group admin.',
              ),
            ),
            _Divider(cs: cs),
            _TextActionRow(
              title: 'Notifications',
              accent: kBrandGreen,
              onTap: () => _showInfoDialog(
                context,
                title: 'Notifications',
                message:
                'Notifications inform you about important updates like invites, approvals, and settlements.',
              ),
            ),

            const SizedBox(height: 22),

            // ---- Another clickable header example ----
            _SectionHeader(
              title: 'Account',
              accent: kBrandGreen,
              onTap: () => _showInfoDialog(
                context,
                title: 'Account',
                message:
                'Manage your account preferences and security actions from here.',
              ),
            ),
            const SizedBox(height: 10),

            // ---- Sign out (text-only row, left aligned) ----
            _TextActionRow(
              title: 'Sign out',
              accent: kBrandGreen,
              isDestructive: true,
              onTap: () async {
                final confirm = await _showLogoutDialog(context);
                if (confirm == true) {
                  await context.read<AuthRepo>().logout();
                  if (context.mounted) context.go('/login');
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _showInfoDialog(
      BuildContext context, {
        required String title,
        required String message,
      }) {
    final cs = Theme.of(context).colorScheme;
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: TextStyle(color: cs.primary)),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showLogoutDialog(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('Do you want to log out of SplitNest?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: cs.primary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Sign out', style: TextStyle(color: cs.error)),
          ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final String name;
  final String email;
  final Color accent;

  const _ProfileHeader({
    required this.name,
    required this.email,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [accent, accent.withValues(alpha: 0.75)],
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.18),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : 'U',
            style: theme.textTheme.titleLarge?.copyWith(
              color: Colors.black,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.2,
                  color: cs.onSurface,
                ),
              ),
              if (email.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback onTap;
  final Color accent;

  const _SectionHeader({
    required this.title,
    required this.onTap,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(
          title,
          style: theme.textTheme.labelLarge?.copyWith(
            color: cs.onSurface.withValues(alpha: 0.85),
            fontWeight: FontWeight.w900,
            letterSpacing: 0.6,
          ),
        ),
      ),
    );
  }
}

class _TextActionRow extends StatelessWidget {
  final String title;
  final VoidCallback onTap;
  final Color accent;
  final bool isDestructive;

  const _TextActionRow({
    required this.title,
    required this.onTap,
    required this.accent,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final textColor = isDestructive
        ? cs.error
        : cs.onSurface;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            // small green dot like modern settings lists
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(left: 2, right: 12),
              decoration: BoxDecoration(
                color: isDestructive ? cs.error : accent,
                shape: BoxShape.circle,
              ),
            ),
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: cs.onSurface.withValues(alpha: 0.35),
            ),
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  final ColorScheme cs;
  const _Divider({required this.cs});

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      color: cs.outlineVariant.withValues(alpha: 0.35),
    );
  }
}