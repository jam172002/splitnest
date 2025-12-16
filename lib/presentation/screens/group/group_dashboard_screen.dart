import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/format.dart';
import '../../../data/auth_repo.dart';
import '../../../data/group_repo.dart';
import '../../../domain/models/group_member.dart';
import '../../../domain/models/tx.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/empty_hint.dart';

class GroupDashboardScreen extends StatelessWidget {
  final String groupId;
  const GroupDashboardScreen({super.key, required this.groupId});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthRepo>();
    final myUid = auth.currentUser!.uid;

    final repo = context.read<GroupRepo>();

    return StreamBuilder(
      stream: repo.watchGroup(groupId),
      builder: (context, groupSnap) {
        final group = groupSnap.data;
        final title = group?.name.isNotEmpty == true ? group!.name : 'Group';

        return AppScaffold(
          title: title,
          actions: [
            IconButton(
              onPressed: () => context.push('/group/$groupId/approvals'),
              icon: const Icon(Icons.verified),
              tooltip: 'Approvals',
            ),
            IconButton(
              onPressed: () => context.push('/group/$groupId/members'),
              icon: const Icon(Icons.people_outline),
              tooltip: 'Members',
            ),
          ],
          fab: FloatingActionButton(
            onPressed: () => context.push('/group/$groupId/add'),
            child: const Icon(Icons.add),
          ),
          child: StreamBuilder<List<GroupMember>>(
            stream: repo.watchMembers(groupId),
            builder: (context, memSnap) {
              final members = memSnap.data ?? [];
              final memberMap = {for (final m in members) m.uid: m};

              return StreamBuilder<List<GroupTx>>(
                stream: repo.watchTx(groupId),
                builder: (context, txSnap) {
                  final all = txSnap.data ?? [];
                  final approved = all.where((t) => t.status == TxStatus.approved && t.type == 'expense').toList();

                  if (members.isEmpty) {
                    return const EmptyHint('Loading members...');
                  }

                  // Calculate totals (MVP: approved expenses only)
                  double totalGroup = 0;
                  final paid = <String, double>{};
                  final share = <String, double>{};

                  DateTime now = DateTime.now();
                  bool sameDay(DateTime a, DateTime b) =>
                      a.year == b.year && a.month == b.month && a.day == b.day;

                  DateTime weekStart = now.subtract(Duration(days: now.weekday - 1)); // Monday
                  bool inWeek(DateTime d) => d.isAfter(weekStart.subtract(const Duration(seconds: 1)));

                  bool sameMonth(DateTime a, DateTime b) => a.year == b.year && a.month == b.month;

                  double totalDay = 0, totalWeek = 0, totalMonth = 0;

                  for (final t in approved) {
                    totalGroup += t.amount;

                    if (sameDay(t.at, now)) totalDay += t.amount;
                    if (inWeek(t.at)) totalWeek += t.amount;
                    if (sameMonth(t.at, now)) totalMonth += t.amount;

                    paid[t.paidBy] = (paid[t.paidBy] ?? 0) + t.amount;

                    final pCount = t.participants.isEmpty ? 1 : t.participants.length;
                    final per = t.amount / pCount;
                    for (final p in t.participants) {
                      share[p] = (share[p] ?? 0) + per;
                    }
                  }

                  final myPaid = paid[myUid] ?? 0;
                  final myShare = share[myUid] ?? 0;
                  final myNet = myPaid - myShare;

                  Widget statTile(String label, String value) {
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(label, style: TextStyle(color: Colors.grey.shade700)),
                          const SizedBox(height: 6),
                          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Invite code: $groupId', style: TextStyle(color: Colors.grey.shade700)),
                      const SizedBox(height: 12),

                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          SizedBox(width: 170, child: statTile('My Paid', Fmt.money(myPaid))),
                          SizedBox(width: 170, child: statTile('My Share', Fmt.money(myShare))),
                          SizedBox(
                            width: 170,
                            child: statTile(
                              'My Net',
                              '${myNet >= 0 ? '+' : ''}${Fmt.money(myNet)}',
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          SizedBox(width: 170, child: statTile('Today Total', Fmt.money(totalDay))),
                          SizedBox(width: 170, child: statTile('This Week', Fmt.money(totalWeek))),
                          SizedBox(width: 170, child: statTile('This Month', Fmt.money(totalMonth))),
                        ],
                      ),

                      const SizedBox(height: 18),
                      Text('Recent transactions', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),

                      Expanded(
                        child: approved.isEmpty
                            ? const EmptyHint('No approved expenses yet.\nTap + to add one.')
                            : ListView.separated(
                          itemCount: approved.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final t = approved[i];
                            final payer = memberMap[t.paidBy]?.email ?? t.paidBy;
                            final pCount = t.participants.length;
                            final per = pCount == 0 ? t.amount : (t.amount / pCount);

                            return ListTile(
                              title: Text('${t.category} • ${Fmt.money(t.amount)}'),
                              subtitle: Text('Paid by $payer • ${Fmt.date(t.at)} • Split: ${Fmt.money(per)} each'),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}
