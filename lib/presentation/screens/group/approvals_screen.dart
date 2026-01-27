import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/format.dart';
import '../../../data/auth_repo.dart';
import '../../../data/group_repo.dart';
import '../../../domain/models/group.dart';
import '../../../domain/models/group_member.dart';
import '../../../domain/models/tx.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/empty_hint.dart';

class ApprovalsScreen extends StatelessWidget {
  final String groupId;
  const ApprovalsScreen({super.key, required this.groupId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final repo = context.read<GroupRepo>();
    final myUid = context.read<AuthRepo>().currentUser!.uid;

    return StreamBuilder<Group>(
      stream: repo.watchGroup(groupId),
      builder: (context, groupSnap) {
        final group = groupSnap.data;
        if (group == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

        return FutureBuilder<String>(
          future: repo.roleOf(groupId, myUid),
          builder: (context, roleSnap) {
            final isAdmin = (roleSnap.data ?? 'member') == 'admin';

            return AppScaffold(
              title: 'Pending Approvals',
              child: StreamBuilder<List<GroupMember>>(
                stream: repo.watchMembers(groupId),
                builder: (context, memSnap) {
                  final members = memSnap.data ?? [];
                  final memberMap = {for (final m in members) m.id: m};

                  return StreamBuilder<List<GroupTx>>(
                    stream: repo.watchPending(groupId),
                    builder: (context, snap) {
                      final pending = snap.data ?? [];
                      if (pending.isEmpty) {
                        return const EmptyHint('All clear!\nNo transactions pending approval.');
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: pending.length,
                        itemBuilder: (context, i) {
                          final t = pending[i];
                          final payer = memberMap[t.paidBy ?? ''];
                          final endorsed = t.endorsedBy.contains(myUid);
                          final iAmParticipant = t.participants.contains(myUid);

                          final canEndorse = group.approvalMode == 'admin_only'
                              ? isAdmin
                              : (iAmParticipant || isAdmin);

                          return Card(
                            elevation: 0,
                            color: colorScheme.surfaceContainerLow,
                            margin: const EdgeInsets.only(bottom: 16),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // --- Header Row ---
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: colorScheme.secondaryContainer,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          t.category.toUpperCase(),
                                          style: theme.textTheme.labelSmall?.copyWith(
                                            color: colorScheme.onSecondaryContainer,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        Fmt.money(t.amount),
                                        style: theme.textTheme.titleLarge?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: colorScheme.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),

                                  // --- Details Section ---
                                  Text(
                                    (t.description ?? '').isNotEmpty ? t.description! : 'No description provided',
                                    style: theme.textTheme.bodyLarge,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Paid by ${payer?.name ?? "Unknown"} • ${Fmt.date(t.at)}',
                                    style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.outline),
                                  ),
                                  const Divider(height: 32),

                                  // --- Endorsement Status ---
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Endorsed by ${t.endorsedBy.length} member(s)',
                                          style: theme.textTheme.bodySmall,
                                        ),
                                      ),
                                      if (isAdmin)
                                        TextButton(
                                          onPressed: () => repo.rejectExpense(groupId: groupId, txId: t.id),
                                          style: TextButton.styleFrom(foregroundColor: colorScheme.error),
                                          child: const Text('Reject'),
                                        ),
                                      const SizedBox(width: 8),
                                      FilledButton.tonal(
                                        onPressed: (!canEndorse || endorsed)
                                            ? null
                                            : () => repo.endorseExpense(
                                          groupId: groupId,
                                          txId: t.id,
                                          uid: myUid,
                                          group: group,
                                          isAdmin: isAdmin,
                                        ),
                                        child: Text(
                                          endorsed ? 'Approved' : (group.approvalMode == 'admin_only' ? 'Approve' : 'Endorse'),
                                        ),
                                      ),
                                    ],
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
            );
          },
        );
      },
    );
  }
}