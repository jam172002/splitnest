import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/format.dart';
import '../../../data/auth_repo.dart';
import '../../../data/group_repo.dart';
import '../../../domain/models/expense_calculator.dart';
import '../../../domain/models/group.dart';
import '../../../domain/models/group_member.dart';
import '../../../domain/models/tx.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/empty_hint.dart';
import 'group_balances_screen.dart';
import 'transaction_history_screen.dart';

class GroupDashboardScreen extends StatelessWidget {
  final String groupId;
  const GroupDashboardScreen({super.key, required this.groupId});

  @override
  Widget build(BuildContext context) {
    final authRepo = context.watch<AuthRepo>();
    final myUid = authRepo.currentUser?.uid;

    if (myUid == null) return const Scaffold(body: Center(child: Text('Please log in')));

    final groupRepo = context.read<GroupRepo>();

    return StreamBuilder<Group>(
      stream: groupRepo.watchGroup(groupId),
      builder: (context, groupSnap) {
        if (!groupSnap.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        final group = groupSnap.data!;

        return AppScaffold(
          title: group.name,
          actions: [
            // --- NEW MEMBERS BUTTON ---
            IconButton(
              icon: const Icon(Icons.people_alt_outlined),
              tooltip: 'Members',
              onPressed: () => context.push('/group/$groupId/members'),
            ),
            IconButton(
                icon: const Icon(Icons.analytics_outlined),
                onPressed: () => Navigator.push(context, MaterialPageRoute(
                    builder: (c) => GroupBalancesScreen(groupId: groupId, groupName: group.name)))),
            IconButton(
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => context.pushNamed('group_settings', pathParameters: {'groupId': groupId})),
          ],
          floatingActionButton: _buildFab(context),
          child: StreamBuilder<List<GroupMember>>(
            stream: groupRepo.watchMembers(groupId),
            builder: (context, memSnap) {
              final members = memSnap.data ?? [];
              final memberMap = {for (var m in members) m.id: m};

              return StreamBuilder<List<GroupTx>>(
                stream: groupRepo.watchTx(groupId),
                builder: (context, txSnap) {
                  final txs = txSnap.data ?? [];
                  if (txs.isEmpty && members.isEmpty) return const EmptyHint('Getting things ready...');

                  return _DashboardBody(
                    groupId: groupId,
                    myUid: myUid,
                    group: group,
                    members: members,
                    memberMap: memberMap,
                    transactions: txs,
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildFab(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        FloatingActionButton.small(
          heroTag: 'settle',
          onPressed: () => context.pushNamed('add_settlement', pathParameters: {'groupId': groupId}),
          backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
          child: const Icon(Icons.handshake_outlined),
        ),
        const SizedBox(height: 12),
        FloatingActionButton.extended(
          heroTag: 'add_expense',
          onPressed: () => context.pushNamed('add_expense', pathParameters: {'groupId': groupId}),
          label: const Text('Add Expense'),
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }
}

class _DashboardBody extends StatelessWidget {
  final String groupId;
  final String myUid;
  final Group group;
  final List<GroupMember> members;
  final Map<String, GroupMember> memberMap;
  final List<GroupTx> transactions;

  const _DashboardBody({
    required this.groupId,
    required this.myUid,
    required this.group,
    required this.members,
    required this.memberMap,
    required this.transactions,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final summary = ExpenseCalculator.calculateMemberSummary(transactions, myUid);

    final now = DateTime.now();
    double totalToday = 0;
    double totalWeek = 0;
    final weekStart = now.subtract(Duration(days: now.weekday - 1));

    for (var tx in transactions) {
      if (DateUtils.isSameDay(tx.at, now)) totalToday += tx.amount;
      if (tx.at.isAfter(weekStart)) totalWeek += tx.amount;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withOpacity(0.7),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              children: [
                Text('YOUR NET BALANCE', style: theme.textTheme.labelLarge?.copyWith(letterSpacing: 1.2)),
                const SizedBox(height: 8),
                Text(
                  summary.netBalance >= 0 ? '+${Fmt.money(summary.netBalance)}' : Fmt.money(summary.netBalance),
                  style: theme.textTheme.displayMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: summary.netBalance >= 0 ? Colors.green.shade800 : colorScheme.error,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _smallStat(context, 'Total Paid', Fmt.money(summary.totalPaid)),
                    Container(width: 1, height: 24, color: colorScheme.onPrimaryContainer.withOpacity(0.2)),
                    _smallStat(context, 'Your Share', Fmt.money(summary.totalShare)),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _periodChip(context, 'Today', Fmt.money(totalToday)),
                _periodChip(context, 'This Week', Fmt.money(totalWeek)),
                _periodChip(context, 'Invite Code: $groupId', null, isInvite: true),
              ],
            ),
          ),

          const SizedBox(height: 32),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Recent Activity', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              TextButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(
                    builder: (context) => GroupTransactionHistoryScreen(groupId: groupId))),
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (transactions.isEmpty)
            const Center(child: Padding(
              padding: EdgeInsets.only(top: 20),
              child: Text('No expenses yet. Tap "Add Expense" to start!'),
            ))
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: transactions.take(10).length,
              itemBuilder: (context, i) {
                final tx = transactions[i];
                return _activityTile(context, tx);
              },
            ),
        ],
      ),
    );
  }

  Widget _smallStat(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(label, style: theme.textTheme.labelSmall),
        Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _periodChip(BuildContext context, String label, String? value, {bool isInvite = false}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isInvite ? colorScheme.secondaryContainer : colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          if (value != null) Text(value, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _activityTile(BuildContext context, GroupTx tx) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSettlement = tx.type == 'settlement';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: isSettlement ? Colors.teal.withOpacity(0.1) : colorScheme.primaryContainer,
            child: Icon(
                isSettlement ? Icons.handshake_outlined : Icons.receipt_long_outlined,
                size: 20,
                color: isSettlement ? Colors.teal : colorScheme.primary
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isSettlement ? 'Settlement' : (tx.category ?? 'Expense'), style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(Fmt.date(tx.at), style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          Text(
            Fmt.money(tx.amount),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: isSettlement ? Colors.teal : null,
            ),
          ),
        ],
      ),
    );
  }
}