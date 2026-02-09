import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/format.dart';
import '../../../data/group_repo.dart';
import '../../../domain/models/group_member.dart';
import '../../../domain/models/tx.dart';
import '../../widgets/app_scaffold.dart';

class MemberTransactionDetailScreen extends StatelessWidget {
  final String groupId;
  final GroupMember member;

  const MemberTransactionDetailScreen({
    super.key,
    required this.groupId,
    required this.member,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final groupRepo = context.read<GroupRepo>();

    return AppScaffold(
      title: member.name,
      actions: [
        if (member.role == 'admin')
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Badge(
              label: const Text('ADMIN'),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              backgroundColor: colorScheme.tertiary,
            ),
          )
      ],
      child: FutureBuilder<List<GroupTx>>(
        future: _fetchMemberTransactions(groupRepo, groupId, member.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final txs = snapshot.data ?? [];

          // --- Calculate Summary for Header ---
          // Using member.id ensures math works even if names are duplicates
          double totalPaid = 0;
          double totalCost = 0;
          for (var t in txs) {
            if (t.paidBy == member.id) totalPaid += t.amount;
            if (t.participants.contains(member.id)) {
              totalCost += t.amount / (t.participants.isEmpty ? 1 : t.participants.length);
            }
          }

          return CustomScrollView(
            slivers: [
              // --- Member Summary Header ---
              SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerLow,
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildSummaryStat(context, 'Total Paid', Fmt.money(totalPaid), Colors.green),
                      Container(width: 1, height: 40, color: colorScheme.outlineVariant),
                      _buildSummaryStat(context, 'Total Cost', Fmt.money(totalCost), colorScheme.error),
                    ],
                  ),
                ),
              ),

              if (txs.isEmpty)
                const SliverFillRemaining(
                  child: Center(child: Text('No activity recorded yet.')),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                          (context, index) {
                        final tx = txs[index];
                        final isPaidBy = tx.paidBy == member.id;
                        final isParticipant = tx.participants.contains(member.id);
                        final share = tx.amount / (tx.participants.isEmpty ? 1 : tx.participants.length);

                        return Card(
                          elevation: 0,
                          color: colorScheme.surface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                          ),
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isPaidBy ? Colors.green.withValues(alpha: 0.1) : colorScheme.surfaceContainerHighest,
                              child: Icon(
                                isPaidBy ? Icons.upload_rounded : Icons.download_rounded,
                                color: isPaidBy ? Colors.green : colorScheme.onSurfaceVariant,
                                size: 20,
                              ),
                            ),
                            title: Text(tx.category.toUpperCase(),
                                style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.primary)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(tx.description ?? 'Generic Expense', style: theme.textTheme.bodyLarge),
                                Text(Fmt.date(tx.at), style: theme.textTheme.bodySmall),
                              ],
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (isPaidBy)
                                  Text('+${Fmt.money(tx.amount)}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                                if (isParticipant)
                                  Text('-${Fmt.money(share)}', style: TextStyle(color: colorScheme.error, fontSize: 12)),
                              ],
                            ),
                          ),
                        );
                      },
                      childCount: txs.length,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryStat(BuildContext context, String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: color,
        )),
      ],
    );
  }

  Future<List<GroupTx>> _fetchMemberTransactions(GroupRepo repo, String groupId, String memberId) async {
    // These methods in GroupRepo must use Firestore filters to find transactions
    // where 'paidBy' == memberId or 'participants' array contains memberId
    final paid = await repo.getExpensesPaidByMember(groupId, memberId);
    final participated = await repo.getExpensesParticipatedByMember(groupId, memberId);

    // Using a Set to avoid duplicates if a member paid for something they also participated in
    final allTx = <GroupTx>{...paid, ...participated}.toList();

    // Sort by date (newest first)
    allTx.sort((a, b) => b.at.compareTo(a.at));
    return allTx;
  }
}