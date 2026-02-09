import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:splitnest/theme/app_colors.dart';

import '../../../core/format.dart';
import '../../../data/auth_repo.dart';
import '../../../data/group_repo.dart';
import '../../../data/notifications_repo.dart';
import '../../../domain/models/expense_calculator.dart';
import '../../../domain/models/group.dart';
import '../../../domain/models/group_member.dart';
import '../../../domain/models/tx.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/empty_hint.dart';
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
    final notificationsRepo = context.read<NotificationsRepo>();

    return StreamBuilder<Group>(
      stream: groupRepo.watchGroup(groupId),
      builder: (context, groupSnap) {
        if (!groupSnap.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final group = groupSnap.data!;

        final theme = Theme.of(context);
        final cs = theme.colorScheme;

        return AppScaffold(
          title: group.name,

          // ✅ WhatsApp-like clickable title
          titleWidget: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => context.push('/group/$groupId/info'),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    group.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.2,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(width: 6),
                  //Icon(Icons.chevron_right_rounded, size: 18, color: cs.onSurface.withValues(alpha: 0.55)),
                ],
              ),
            ),
          ),

          automaticallyImplyLeading: false,
          leading: IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            tooltip: 'Back',
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/');
              }
            },
          ),

          // ✅ No Members/Stats/Settings here anymore
          actions: const [],

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

                  if (txs.isNotEmpty) {
                    notificationsRepo.markExpenseAsSeen(groupId, txs.first.id, myUid);
                  }

                  return _DashboardBody(
                    groupId: groupId,
                    myUid: myUid,
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
    final cs = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        FloatingActionButton.small(
          heroTag: 'settle',
          onPressed: () => context.pushNamed(
            'add_settlement',
            pathParameters: {'groupId': groupId},
          ),
          backgroundColor: cs.surfaceContainerHigh,
          foregroundColor: cs.onSurface,
          child: const Icon(Icons.handshake_outlined),
        ),
        const SizedBox(height: 12),
        FloatingActionButton.extended(
          heroTag: 'add_expense',
          onPressed: () => context.pushNamed(
            'add_expense',
            pathParameters: {'groupId': groupId},
          ),
          backgroundColor: AppColors.green,
          foregroundColor: Colors.black,
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
  final List<GroupMember> members;
  final Map<String, GroupMember> memberMap;
  final List<GroupTx> transactions;

  const _DashboardBody({
    required this.groupId,
    required this.myUid,
    required this.members,
    required this.memberMap,
    required this.transactions,
  });

  static const Color kBrandGreen = Color(0xFF20C84A);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final notificationsRepo = context.read<NotificationsRepo>();

    final summary = ExpenseCalculator.calculateMemberSummary(transactions, myUid);

    final now = DateTime.now();
    double totalToday = 0;
    double totalWeek = 0;
    final weekStart = now.subtract(Duration(days: now.weekday - 1));

    for (var tx in transactions) {
      if (DateUtils.isSameDay(tx.at, now)) totalToday += tx.amount;
      if (tx.at.isAfter(weekStart)) totalWeek += tx.amount;
    }

    return FutureBuilder<bool>(
      future: transactions.isEmpty
          ? Future.value(false)
          : notificationsRepo.hasUnseenExpenses(groupId, transactions.first.id, myUid),
      builder: (context, snapshot) {
        final hasUnseen = snapshot.data ?? false;

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasUnseen)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: kBrandGreen.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.notifications_active_rounded, color: kBrandGreen, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'New expense added in this group',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: cs.onSurface,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close_rounded, color: cs.onSurface.withValues(alpha: 0.7), size: 18),
                        onPressed: () {
                          if (transactions.isNotEmpty) {
                            notificationsRepo.markExpenseAsSeen(groupId, transactions.first.id, myUid);
                          }
                        },
                      ),
                    ],
                  ),
                ),

              // Net Balance Card (refined)
              _BankBalanceCard(
                net: summary.netBalance,
                paid: summary.totalPaid,
                share: summary.totalShare,
              ),

              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(child: _MetricTile(label: 'Today', value: Fmt.money(totalToday))),
                  const SizedBox(width: 10),
                  Expanded(child: _MetricTile(label: 'This week', value: Fmt.money(totalWeek))),
                ],
              ),
              const SizedBox(height: 10),


              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent activity',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => GroupTransactionHistoryScreen(groupId: groupId),
                      ),
                    ),
                    child: Text(
                      'View all',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: kBrandGreen,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              if (transactions.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 18),
                  child: Text(
                    'No expenses yet. Tap “Add Expense” to start.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: transactions.take(10).length,
                  itemBuilder: (context, i) => _activityTile(context, transactions[i]),
                ),
            ],
          ),
        );
      },
    );
  }



  Widget _activityTile(BuildContext context, GroupTx tx) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final isSettlement = tx.type == 'settlement';
    final payerName = memberMap[tx.paidBy]?.name ?? 'Unknown';

    final iconBg = isSettlement
        ? cs.tertiaryContainer.withValues(alpha: 0.35)
        : cs.primaryContainer.withValues(alpha: 0.45);

    final iconColor = isSettlement ? cs.tertiary : cs.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: iconBg,
            child: Icon(
              isSettlement ? Icons.handshake_outlined : Icons.receipt_long_outlined,
              size: 18,
              color: iconColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isSettlement ? 'Settlement' : (tx.category),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$payerName • ${Fmt.date(tx.at)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Text(
            Fmt.money(tx.amount),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: isSettlement ? cs.tertiary : cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }


}

class _BankBalanceCard extends StatelessWidget {
  final double net;
  final double paid;
  final double share;

  const _BankBalanceCard({
    required this.net,
    required this.paid,
    required this.share,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Only black/white/green (+ opacity)
    final bg = isDark ? AppColors.black : AppColors.white;
    final stroke = isDark ? Colors.white.withValues(alpha: 0.10) : Colors.black.withValues(alpha: 0.08);
    final soft = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04);
    final text = isDark ? AppColors.white : Colors.black;
    final sub = isDark ? Colors.white.withValues(alpha: 0.72) : Colors.black.withValues(alpha: 0.62);

    final positive = net >= 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: stroke),
        boxShadow: [
          // banking-app soft shadow (still black only)
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: title + status dot
          Row(
            children: [
              Text(
                'Your net balance',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: sub,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
              const Spacer(),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: AppColors.green.withValues(alpha: positive ? 1 : 0.35),
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Big amount (banking style)
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                positive ? '+' : '',
                style: theme.textTheme.headlineLarge?.copyWith(
                  color: AppColors.green,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.8,
                ),
              ),
              Text(
                Fmt.money(net.abs()),
                style: theme.textTheme.headlineLarge?.copyWith(
                  color: AppColors.green,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  positive ? 'You are in credit' : 'You owe',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: sub,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Divider line
          Container(height: 1, color: stroke),
          const SizedBox(height: 12),

          // Two metrics, banking style blocks
          Row(
            children: [
              Expanded(
                child: _MiniMetricBlock(
                  label: 'Total paid',
                  value: Fmt.money(paid),
                  softBg: soft,
                  text: text,
                  sub: sub,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniMetricBlock(
                  label: 'Your share',
                  value: Fmt.money(share),
                  softBg: soft,
                  text: text,
                  sub: sub,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniMetricBlock extends StatelessWidget {
  final String label;
  final String value;
  final Color softBg;
  final Color text;
  final Color sub;

  const _MiniMetricBlock({
    required this.label,
    required this.value,
    required this.softBg,
    required this.text,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: softBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.green.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: sub,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.15,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              color: text,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final bool isAccent;
  final VoidCallback? onTap;

  const _MetricTile({
    super.key,
    required this.label,
    required this.value,
    this.isAccent = false, //  default
    this.onTap,            //  optional
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bg = isDark ? AppColors.black : AppColors.white;
    final stroke = isDark ? Colors.white.withValues(alpha: 0.10) : Colors.black.withValues(alpha: 0.08);
    final text = isDark ? AppColors.white : Colors.black;
    final sub = isDark ? Colors.white.withValues(alpha: 0.72) : Colors.black.withValues(alpha: 0.62);

    final accentBg = isDark
        ? AppColors.green.withValues(alpha: 0.14)
        : AppColors.green.withValues(alpha: 0.10);

    final tileBg = isAccent ? accentBg : bg;
    final tileBorder = isAccent ? AppColors.green.withValues(alpha: 0.35) : stroke;

    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: tileBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tileBorder),
      ),
      child: Row(
        children: [
          // small left indicator (banking style)
          Container(
            width: 4,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.green,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 10),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: sub,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: text,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),

          if (onTap != null)
            Icon(Icons.chevron_right_rounded, color: sub, size: 20),
        ],
      ),
    );

    if (onTap == null) return content;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: content,
    );
  }
}