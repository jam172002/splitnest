import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/format.dart';
import '../../../data/auth_repo.dart';
import '../../../data/group_repo.dart';
import '../../../domain/models/group_member.dart';
import '../../../domain/models/tx.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/empty_hint.dart';

class ApprovalsScreen extends StatelessWidget {
  final String groupId;
  const ApprovalsScreen({super.key, required this.groupId});

  @override
  Widget build(BuildContext context) {
    final repo = context.read<GroupRepo>();
    final myUid = context.read<AuthRepo>().currentUser!.uid;

    return AppScaffold(
      title: 'Approvals',
      child: StreamBuilder<List<GroupMember>>(
        stream: repo.watchMembers(groupId),
        builder: (context, memSnap) {
          final members = memSnap.data ?? [];
          final memberMap = {for (final m in members) m.uid: m};

          return StreamBuilder<List<GroupTx>>(
            stream: repo.watchPending(groupId),
            builder: (context, snap) {
              final pending = snap.data ?? [];
              if (pending.isEmpty) return const EmptyHint('No pending approvals.');

              return ListView.separated(
                itemCount: pending.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final t = pending[i];
                  final payer = memberMap[t.paidBy]?.email ?? t.paidBy;
                  final endorsed = t.endorsedBy.contains(myUid);

                  return ListTile(
                    title: Text('${t.category} • ${Fmt.money(t.amount)}'),
                    subtitle: Text('Paid by $payer • ${Fmt.date(t.at)}'),
                    trailing: Wrap(
                      spacing: 8,
                      children: [
                        TextButton(
                          onPressed: () => repo.rejectExpense(groupId: groupId, txId: t.id),
                          child: const Text('Reject'),
                        ),
                        FilledButton(
                          onPressed: endorsed
                              ? null
                              : () => repo.endorseExpense(groupId: groupId, txId: t.id, uid: myUid),
                          child: Text(endorsed ? 'Endorsed' : 'Endorse'),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
