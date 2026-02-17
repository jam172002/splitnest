import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/format.dart';
import '../../../data/auth_repo.dart';
import '../../../data/group_repo.dart';
import '../../../domain/models/expense_calculator.dart';
import '../../../domain/models/group.dart';
import '../../../domain/models/group_member.dart';
import '../../../domain/models/tx.dart';
import '../../../theme/app_colors.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/busy_button.dart';

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

        return FutureBuilder<String>(
          future: repo.roleOf(groupId, myUid),
          builder: (context, roleSnap) {
            final myRole = roleSnap.data ?? 'member';
            final isAdmin = myRole == 'admin';

            return AppScaffold(
              title: 'Group info',
              backgroundColor: bg,
              leading: IconButton(
                icon: Icon(Icons.chevron_left_rounded, color: text),
                onPressed: () => context.pop(),
              ),

              // ✅ Keep existing core: admin-only FAB
              floatingActionButton: isAdmin
                  ? FloatingActionButton(
                backgroundColor: AppColors.green,
                foregroundColor: AppColors.white,
                onPressed: () => _showAddMemberSheet(context, repo, isDark),
                child: const Icon(Icons.person_add_rounded),
              )
                  : null,

              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ================= HEADER =================
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

                              ],
                            ),
                          ),
                        ],
                      ),
                    ),


                    const SizedBox(height: 14),

                    // ================= ACTIONS (REMOVE INVITE BUTTON, APPROVAL -> SETTINGS) =================
                    Container(
                      decoration: BoxDecoration(
                        color: card,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: stroke),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _ActionTile(
                              icon: Icons.search_rounded,
                              label: 'Search',
                              onTap: () => context.push('/group/$groupId/search'),
                            ),
                          ),
                          Container(width: 1, height: 58, color: stroke.withValues(alpha: 0.6)),
                          Expanded(
                            child: _ActionTile(
                              icon: Icons.verified_user_outlined,
                              label: 'Approvals',
                              onTap: () => context.pushNamed(
                                'group_settings',
                                pathParameters: {'groupId': groupId},
                              ),
                            ),
                          ),
                          Container(width: 1, height: 58, color: stroke.withValues(alpha: 0.6)),
                          Expanded(
                            child: _ActionTile(
                              icon: Icons.qr_code_rounded,
                              label: 'Invite',
                              onTap: () => _showInviteSheet(context, groupId),

                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // ================= MEMBERS + BALANCES =================
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
                      builder: (context, memSnap) {
                        if (memSnap.hasError) {
                          return Text('Error: ${memSnap.error}', style: TextStyle(color: text));
                        }
                        if (!memSnap.hasData) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        final members = memSnap.data!;
                        if (members.isEmpty) {
                          return Text('No members found', style: theme.textTheme.bodyMedium?.copyWith(color: subText));
                        }

                        return StreamBuilder<List<GroupTx>>(
                          stream: repo.watchTx(groupId),
                          builder: (context, txSnap) {
                            if (!txSnap.hasData) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 18),
                                child: Center(child: CircularProgressIndicator()),
                              );
                            }

                            final txs = txSnap.data!;
                            final netMap = <String, double>{};

                            for (final m in members) {
                              final summary = ExpenseCalculator.calculateMemberSummary(txs, m.id);
                              netMap[m.id] = summary.netBalance;
                            }

                            final sorted = [...members]..sort((a, b) {
                              if (a.isAdmin && !b.isAdmin) return -1;
                              if (!a.isAdmin && b.isAdmin) return 1;

                              final na = netMap[a.id] ?? 0.0;
                              final nb = netMap[b.id] ?? 0.0;
                              final byNet = nb.compareTo(na);
                              if (byNet != 0) return byNet;

                              return a.joinedAt.compareTo(b.joinedAt);
                            });

                            return Container(
                              decoration: BoxDecoration(
                                color: card,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: stroke),
                              ),
                              child: ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: sorted.length,
                                separatorBuilder: (_, __) => Divider(height: 1, color: stroke.withValues(alpha: 0.7)),
                                itemBuilder: (context, index) {
                                  final m = sorted[index];
                                  final net = netMap[m.id] ?? 0.0;

                                  final isCredit = net >= 0;
                                  final amountColor = isCredit ? AppColors.green : Colors.red.shade400;
                                  final label = net == 0 ? 'Settled' : (isCredit ? 'Credited' : 'Owes');

                                  return ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    leading: CircleAvatar(
                                      backgroundColor: amountColor.withValues(alpha: isDark ? 0.18 : 0.12),
                                      child: Text(
                                        m.initials,
                                        style: TextStyle(color: amountColor, fontWeight: FontWeight.w900),
                                      ),
                                    ),
                                    title: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            m.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(color: text, fontWeight: FontWeight.w900),
                                          ),
                                        ),
                                        Text(
                                          m.roleDisplay,
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: subText,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                                    subtitle: Text(
                                      '$label • Joined ${m.joinedAt.day}/${m.joinedAt.month}/${m.joinedAt.year}',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: amountColor.withValues(alpha: 0.95),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          Fmt.money(net.abs()),
                                          style: theme.textTheme.titleMedium?.copyWith(
                                            color: amountColor,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        if (isAdmin && !m.isAdmin)
                                          IconButton(
                                            icon: Icon(Icons.person_remove_outlined, color: Colors.red.shade400),
                                            onPressed: () => _confirmDelete(context, repo, groupId, m.id, m.name),
                                          ),
                                      ],
                                    ),
                                  );
                                },
                              ),
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
                Text(
                  'Add new member',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
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

  // ✅ Bottom sheet uses QR style copied from settings screen + copy invite code from this file
  void _showInviteSheet(BuildContext context, String groupId) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Group Invite QR',
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your friend can scan this code to join the group instantly.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // QR block (same style as settings)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              child: QrImageView(
                data: groupId,
                version: QrVersions.auto,
                size: 220.0,
                eyeStyle: QrEyeStyle(
                  eyeShape: QrEyeShape.circle,
                  color: colorScheme.primary,
                ),
                dataModuleStyle: QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.circle,
                  color: colorScheme.primary,
                ),
              ),
            ),

            const SizedBox(height: 18),

            // Group ID row + copy (copied behavior from this file)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Invite code: $groupId',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Copy invite code',
                    icon: const Icon(Icons.copy_rounded),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: groupId));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Invite code copied'),
                            backgroundColor: Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFF141719)
                                : Colors.black,
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final sub = isDark ? Colors.white.withValues(alpha: 0.72) : Colors.black.withValues(alpha: 0.62);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.green),
            const SizedBox(height: 6),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: sub,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
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