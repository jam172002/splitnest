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
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 110),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ================= WHATSAPP-LIKE HEADER =================
                    Container(
                      decoration: BoxDecoration(
                        color: card,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: stroke),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                        child: Column(
                          children: [


                            // big centered avatar
                            Container(
                              width: 104,
                              height: 104,
                              decoration: BoxDecoration(
                                color: AppColors.green.withValues(alpha: isDark ? 0.18 : 0.12),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.green.withValues(alpha: 0.35),
                                  width: 1.2,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.groups_rounded,
                                size: 46,
                                color: AppColors.green,
                              ),
                            ),

                            const SizedBox(height: 12),

                            Text(
                              group.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                color: text,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.2,
                              ),
                              textAlign: TextAlign.center,
                            ),

                            const SizedBox(height: 6),

                            // "Group • X members"
                            StreamBuilder<List<GroupMember>>(
                              stream: repo.watchMembers(groupId),
                              builder: (context, memCountSnap) {
                                final count = memCountSnap.data?.length ?? 0;
                                return Text(
                                  'Group • $count members',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: subText,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  textAlign: TextAlign.center,
                                );
                              },
                            ),

                            const SizedBox(height: 14),

                            // WhatsApp-like quick actions row: Audio / Video / Add / Search
                            Container(
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.04)
                                    : Colors.black.withValues(alpha: 0.03),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: stroke.withValues(alpha: 0.9)),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _QuickActionTile(
                                      icon: Icons.verified_user_outlined,
                                      label: 'Approval',
                                      onTap: () => context.pushNamed( 'group_settings', pathParameters: {'groupId': groupId}, ),
                                    ),
                                  ),

                                  _VLine(color: stroke),
                                  Expanded(
                                    child: _QuickActionTile(
                                      icon: Icons.person_add_alt_1_rounded,
                                      label: 'Add',
                                      onTap:() => _showInviteSheet(context, groupId),
                                    ),
                                  ),
                                  _VLine(color: stroke),
                                  Expanded(
                                    child: _QuickActionTile(
                                      icon: Icons.search_rounded,
                                      label: 'Search',
                                      onTap: () => context.push('/group/$groupId/search'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

// ================= Combined Expenses (FIXED) =================
                    StreamBuilder<List<GroupTx>>(
                      stream: repo.watchTx(groupId),
                      builder: (context, txSnap) {
                        if (!txSnap.hasData) {
                          return _SectionCard(
                            isDark: isDark,
                            bg: card,
                            stroke: stroke,
                            child: const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(child: CircularProgressIndicator()),
                            ),
                          );
                        }

                        final txs = txSnap.data!;

                        // ✅ Total approved expenses
                        final approvedExpenses = txs.where((t) {
                          final isApproved = t.status == TxStatus.approved;
                          final isExpense = (t.type == 'expense'); // keep your existing logic
                          return isApproved && isExpense;
                        }).toList();

                        final totalExpense = approvedExpenses.fold<double>(
                          0.0,
                              (sum, t) => sum + t.amount,
                        );

                        // ✅ Optional quick chips (top 3 categories preview)
                        final Map<String, double> byCategory = {};
                        for (final t in approvedExpenses) {
                          final cat = (t.category == null || (t.category ?? '').trim().isEmpty)
                              ? 'Uncategorized'
                              : t.category!.trim();
                          byCategory[cat] = (byCategory[cat] ?? 0) + t.amount;
                        }

                        final topCats = byCategory.entries.toList()
                          ..sort((a, b) => b.value.compareTo(a.value));
                        final previewCats = topCats.take(3).toList();

                        return _SectionCard(
                          isDark: isDark,
                          bg: card,
                          stroke: stroke,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () => context.push('/group/$groupId/combined'),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Header row
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Combined Expenses',
                                          style: theme.textTheme.titleSmall?.copyWith(
                                            color: text,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        Fmt.money(totalExpense),
                                        style: theme.textTheme.titleMedium?.copyWith(
                                          color: AppColors.green,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Icon(Icons.chevron_right_rounded, color: subText),
                                    ],
                                  ),

                                  const SizedBox(height: 10),

                                  // Preview chips (optional but nice)
                                  if (previewCats.isEmpty)
                                    Text(
                                      'No approved expenses yet',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: subText,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    )
                                  else
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        for (final e in previewCats)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isDark
                                                  ? Colors.white.withValues(alpha: 0.05)
                                                  : Colors.black.withValues(alpha: 0.04),
                                              borderRadius: BorderRadius.circular(999),
                                              border: Border.all(
                                                color: stroke.withValues(alpha: 0.9),
                                              ),
                                            ),
                                            child: Text(
                                              '${e.key} • ${Fmt.money(e.value)}',
                                              style: theme.textTheme.bodySmall?.copyWith(
                                                color: subText,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 10),



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
                          return Text(
                            'No members found',
                            style: theme.textTheme.bodyMedium?.copyWith(color: subText),
                          );
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
                                separatorBuilder: (_, __) =>
                                    Divider(height: 1, color: stroke.withValues(alpha: 0.7)),
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
                                            icon: Icon(Icons.person_remove_outlined,
                                                color: Colors.red.shade400),
                                            onPressed: () =>
                                                _confirmDelete(context, repo, groupId, m.id, m.name),
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

// ================= UI HELPERS (WHATSAPP-LIKE) =================

class _VLine extends StatelessWidget {
  final Color color;
  const _VLine({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 46,
      color: color.withValues(alpha: 0.7),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final sub = isDark ? Colors.white.withValues(alpha: 0.74) : Colors.black.withValues(alpha: 0.64);

    return InkWell(
      onTap: onTap,
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
    );
  }
}

class _SectionCard extends StatelessWidget {
  final bool isDark;
  final Color bg;
  final Color stroke;
  final Widget child;

  const _SectionCard({
    required this.isDark,
    required this.bg,
    required this.stroke,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: stroke),
      ),
      child: child,
    );
  }
}

