import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/format.dart';
import '../../../data/auth_repo.dart';
import '../../../data/group_repo.dart';
import '../../../domain/models/bill.dart';
import '../../../domain/models/group.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/empty_hint.dart';

class BillsScreen extends StatelessWidget {
  final String groupId;
  const BillsScreen({super.key, required this.groupId});

  @override
  Widget build(BuildContext context) {
    final repo = context.read<GroupRepo>();
    final uid = context.read<AuthRepo>().currentUser!.uid;

    return StreamBuilder<Group>(
      stream: repo.watchGroup(groupId),
      builder: (context, gSnap) {
        if (!gSnap.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        final group = gSnap.data!;
        final theme = Theme.of(context);
        final cs = theme.colorScheme;

        if (group.type != 'business') {
          return const AppScaffold(
            title: 'Bills',
            child: EmptyHint('Bills are only available in business groups.'),
          );
        }

        return AppScaffold(
          title: 'Bills',
          actions: [
            IconButton(
              tooltip: 'Add Bill',
              icon: const Icon(Icons.add),
              onPressed: () => context.push('/group/$groupId/bills/add'),
            ),
          ],
          child: Column(
            children: [
              // top action bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () async {
                          final now = DateTime.now();
                          final isAdmin = (await repo.roleOf(groupId, uid)) == 'admin';
                          await repo.generateBillsForMonth(
                            groupId: groupId,
                            group: group,
                            year: now.year,
                            month: now.month,
                            createdBy: uid,
                            isAdmin: isAdmin,
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Bills generated for this month')),
                          );
                        },
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Generate this month'),
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: StreamBuilder<List<BillTemplate>>(
                  stream: repo.watchBills(groupId),
                  builder: (context, snap) {
                    final bills = snap.data ?? [];
                    if (bills.isEmpty) {
                      return const EmptyHint('No bills yet. Tap + to add your first bill.');
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 18),
                      itemCount: bills.length,
                      itemBuilder: (context, i) {
                        final b = bills[i];
                        return Card(
                          elevation: 0,
                          color: cs.surface,
                          margin: const EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                            side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.35)),
                          ),
                          child: ListTile(
                            onTap: () => context.push('/group/$groupId/bills/edit?bill=${b.id}'),
                            leading: CircleAvatar(
                              backgroundColor: cs.primary.withValues(alpha: 0.12),
                              child: Icon(Icons.receipt_long_rounded, color: cs.primary),
                            ),
                            title: Text(
                              b.title,
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                            subtitle: Text(
                              'Due: ${b.dueDay} • Members: ${b.participants.length}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Text(
                              Fmt.money(b.amount),
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}