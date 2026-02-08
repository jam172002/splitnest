import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../data/auth_repo.dart';
import '../../../data/group_repo.dart';
import '../../../domain/models/group.dart';
import '../../../domain/models/group_member.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/busy_button.dart';
import '../../../theme/app_colors.dart';
import 'group_balances_screen.dart';

class GroupInfoScreen extends StatelessWidget {
  final String groupId;
  const GroupInfoScreen({super.key, required this.groupId});

  @override
  Widget build(BuildContext context) {
    final repo = context.read<GroupRepo>();
    final authRepo = context.read<AuthRepo>();
    final myUid = authRepo.currentUser?.uid ?? '';

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bg = AppColors.bg(isDark);
    final card = AppColors.card(isDark);
    final stroke = AppColors.stroke(isDark);
    final text = AppColors.text(isDark);
    final subText = AppColors.subText(isDark);

    return StreamBuilder<Group>(
      stream: repo.watchGroup(groupId),
      builder: (context, groupSnap) {
        if (!groupSnap.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final group = groupSnap.data!;

        return AppScaffold(
          title: 'Group info',
          backgroundColor: bg,
          leading: IconButton(
            icon: Icon(Icons.chevron_left_rounded, color: text),
            onPressed: () => context.pop(),
          ),

          floatingActionButton: FutureBuilder<String>(
            future: repo.roleOf(groupId, myUid),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data == 'admin') {
                return FloatingActionButton(
                  backgroundColor: AppColors.green,
                  foregroundColor: AppColors.white,
                  onPressed: () => _showAddMemberSheet(context, repo, isDark),
                  child: const Icon(Icons.person_add_rounded),
                );
              }
              return const SizedBox.shrink();
            },
          ),

          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: card,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: stroke),
                  ),
                  child: Row(
                    children: [
                      _Avatar(letter: group.name.isNotEmpty ? group.name[0].toUpperCase() : 'G'),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              group.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: text,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Group ID: $groupId',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: subText,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Invite code
                InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () async {
                    await Clipboard.setData(ClipboardData(text: groupId));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Invite code copied'),
                          backgroundColor: isDark ? const Color(0xFF141719) : Colors.black,
                        ),
                      );
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.inviteBg(isDark),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.green.withValues(alpha: isDark ? 0.45 : 0.30)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.qr_code_rounded, color: AppColors.green),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Invite code',
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: text,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                groupId,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: text,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.1,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.copy_rounded, size: 18, color: subText),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // Actions
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (c) => GroupBalancesScreen(groupId: groupId, groupName: group.name),
                          ),
                        ),
                        icon: const Icon(Icons.analytics_outlined),
                        label: const Text('Statistics'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.green,
                          side: BorderSide(color: AppColors.green.withValues(alpha: 0.55)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => context.pushNamed(
                          'group_settings',
                          pathParameters: {'groupId': groupId},
                        ),
                        icon: const Icon(Icons.settings_outlined),
                        label: const Text('Settings'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.green,
                          side: BorderSide(color: AppColors.green.withValues(alpha: 0.55)),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                Text(
                  'Members',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: text,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 10),

                StreamBuilder<List<GroupMember>>(
                  stream: repo.watchMembers(groupId),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) return Text('Error: ${snapshot.error}', style: TextStyle(color: text));
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                    final members = snapshot.data!;
                    if (members.isEmpty) {
                      return Text('No members found', style: theme.textTheme.bodyMedium?.copyWith(color: subText));
                    }

                    members.sort((a, b) {
                      if (a.role == 'admin' && b.role != 'admin') return -1;
                      if (a.role != 'admin' && b.role == 'admin') return 1;
                      return a.joinedAt.compareTo(b.joinedAt);
                    });

                    return FutureBuilder<String>(
                      future: repo.roleOf(groupId, myUid),
                      builder: (context, roleSnap) {
                        final myRole = roleSnap.data ?? 'member';
                        final isAdmin = myRole == 'admin';

                        return ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: members.length,
                          itemBuilder: (context, index) {
                            final m = members[index];
                            final memberIsAdmin = m.role == 'admin';

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                color: card,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: stroke),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                leading: CircleAvatar(
                                  backgroundColor: memberIsAdmin
                                      ? AppColors.green.withValues(alpha: isDark ? 0.22 : 0.14)
                                      : (isDark
                                      ? Colors.white.withValues(alpha: 0.06)
                                      : Colors.black.withValues(alpha: 0.05)),
                                  child: Text(
                                    m.initials,
                                    style: TextStyle(color: text, fontWeight: FontWeight.w900),
                                  ),
                                ),
                                title: Text(m.name, style: TextStyle(color: text, fontWeight: FontWeight.w800)),
                                subtitle: Text(
                                  'Joined ${m.joinedAt.day}/${m.joinedAt.month}/${m.joinedAt.year}',
                                  style: theme.textTheme.bodySmall?.copyWith(color: subText, fontWeight: FontWeight.w600),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _RolePill(
                                      text: m.role.toUpperCase(),
                                      isAdmin: memberIsAdmin,
                                      isDark: isDark,
                                    ),
                                    if (isAdmin && !memberIsAdmin)
                                      IconButton(
                                        icon: Icon(Icons.person_remove_outlined, color: Colors.red.shade400),
                                        onPressed: () => _confirmDelete(context, repo, groupId, m.id, m.name),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, GroupRepo repo, String groupId, String uid, String name) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Remove member?'),
        content: Text('Are you sure you want to remove $name from the group?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              await repo.removeMember(groupId, uid);
              if (context.mounted) Navigator.pop(c);
            },
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showAddMemberSheet(BuildContext context, GroupRepo repo, bool isDark) {
    final nameController = TextEditingController();
    const role = 'member';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.bg(isDark),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          bool isBusy = false;

          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Add new member', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 18),
                BusyButton(
                  busy: isBusy,
                  onPressed: () async {
                    if (nameController.text.trim().isEmpty) return;

                    setModalState(() => isBusy = true);
                    final virtualUid = DateTime.now().millisecondsSinceEpoch.toString();

                    await repo.addMember(
                      groupId: groupId,
                      name: nameController.text.trim(),
                      role: role,
                      uid: virtualUid,
                    );

                    if (context.mounted) Navigator.pop(context);
                  },
                  text: 'Add to group',
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String letter;
  const _Avatar({required this.letter});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = AppColors.green.withValues(alpha: isDark ? 0.22 : 0.14);

    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: bg,
        border: Border.all(color: AppColors.green.withValues(alpha: 0.45)),
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          color: AppColors.green,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _RolePill extends StatelessWidget {
  final String text;
  final bool isAdmin;
  final bool isDark;

  const _RolePill({
    required this.text,
    required this.isAdmin,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isAdmin
        ? AppColors.green.withValues(alpha: isDark ? 0.22 : 0.14)
        : (isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05));

    final border = isAdmin
        ? AppColors.green.withValues(alpha: 0.45)
        : (isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.10));

    final fg = isAdmin
        ? AppColors.green
        : (isDark ? Colors.white.withValues(alpha: 0.75) : Colors.black.withValues(alpha: 0.65));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}