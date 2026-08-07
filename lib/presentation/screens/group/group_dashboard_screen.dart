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
import '../../widgets/period_selector.dart';

class GroupDashboardScreen extends StatelessWidget {
  final String groupId;
  const GroupDashboardScreen({super.key, required this.groupId});

  @override
  Widget build(BuildContext context) {
    final authRepo = context.watch<AuthRepo>();
    final myUid = authRepo.currentUser?.uid;
    if (myUid == null)
      return const Scaffold(body: Center(child: Text('Please log in')));

    final groupRepo = context.read<GroupRepo>();
    final notificationsRepo = context.read<NotificationsRepo>();

    return StreamBuilder<Group>(
      stream: groupRepo.watchGroup(groupId),
      builder: (context, groupSnap) {
        if (!groupSnap.hasData) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        final group = groupSnap.data!;

        final theme = Theme.of(context);
        final cs = theme.colorScheme;

        return AppScaffold(
          title: group.name,

          // WhatsApp-like clickable title
          titleWidget: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => context.push('/group/$groupId/info'),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
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
                  Text(
                    'Click to see details',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      decoration: TextDecoration.underline,
                      decorationColor: cs.onSurfaceVariant,
                    ),
                  ),
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
          actions: [
            StreamBuilder(
              stream: notificationsRepo.watchNotifications(
                myUid,
                groupId: groupId,
              ),
              builder: (context, snapshot) {
                final items = snapshot.data ?? const [];
                final unread = items.where((item) => !item.isRead).length;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      tooltip: 'Group notifications',
                      onPressed: () =>
                          context.push('/group/$groupId/notifications'),
                      icon: const Icon(Icons.notifications_outlined),
                    ),
                    if (unread > 0)
                      Positioned(
                        right: 5,
                        top: 5,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: cs.error,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            unread > 9 ? '9+' : '$unread',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: cs.onError,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],

          floatingActionButton: _buildFab(context, group),

          child: StreamBuilder<List<GroupMember>>(
            stream: groupRepo.watchMembers(groupId),
            builder: (context, memSnap) {
              final members = memSnap.data ?? [];
              final memberMap = {for (var m in members) m.id: m};

              return StreamBuilder<List<GroupTx>>(
                stream: groupRepo.watchTx(groupId),
                builder: (context, txSnap) {
                  final txs = txSnap.data ?? [];
                  if (txs.isEmpty && members.isEmpty)
                    return const EmptyHint('Getting things ready...');

                  if (txs.isNotEmpty) {
                    notificationsRepo.markExpenseAsSeen(
                        groupId, txs.first.id, myUid);
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

  Widget _buildFab(BuildContext context, Group group) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // ✅ Bills button only for business group
        if (group.type == 'business') ...[
          FloatingActionButton.small(
            heroTag: 'bills',
            onPressed: () => context.push('/group/$groupId/bills'),
            backgroundColor: cs.surfaceContainerHigh,
            foregroundColor: cs.onSurface,
            child: const Icon(Icons.receipt_long_outlined),
          ),
          const SizedBox(height: 12),
        ],

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

class _DashboardBody extends StatefulWidget {
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

  @override
  State<_DashboardBody> createState() => _DashboardBodyState();
}

class _DashboardBodyState extends State<_DashboardBody> {
  static const Color kBrandGreen = Color(0xFF20C84A);

  PeriodType _period = PeriodType.month;
  String _periodLabel = 'This Month';
  DateRange? _range;

  @override
  Widget build(BuildContext context) {
    final groupId = widget.groupId;
    final myUid = widget.myUid;
    final members = widget.members;
    final memberMap = widget.memberMap;
    final transactions = widget.transactions;

    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final notificationsRepo = context.read<NotificationsRepo>();

    final summary =
        ExpenseCalculator.calculateMemberSummary(transactions, myUid);
    final disputedShare =
        ExpenseCalculator.calculateDisputedShare(transactions, myUid);
    final netByMember = ExpenseCalculator.calculateNetByMember(
      txs: transactions,
      memberUids: members.map((member) => member.id).toList(),
    );
    final settlements = ExpenseCalculator.calculateSettlements(netByMember)
        .where(
            (transfer) => transfer.fromUid == myUid || transfer.toUid == myUid)
        .toList();

    final periodRange = _range ?? rangeForPeriod(_period);
    double periodTotal = 0;
    for (var tx in transactions) {
      if (tx.status != TxStatus.approved) continue;
      if (periodRange.contains(tx.at)) periodTotal += tx.amount;
    }

    return FutureBuilder<bool>(
      future: transactions.isEmpty
          ? Future.value(false)
          : notificationsRepo.hasUnseenExpenses(
              groupId, transactions.first.id, myUid),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(16),
                    border:
                        Border.all(color: kBrandGreen.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.notifications_active_rounded,
                          color: kBrandGreen, size: 18),
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
                        icon: Icon(Icons.close_rounded,
                            color: cs.onSurface.withValues(alpha: 0.7),
                            size: 18),
                        onPressed: () {
                          if (transactions.isNotEmpty) {
                            notificationsRepo.markExpenseAsSeen(
                                groupId, transactions.first.id, myUid);
                          }
                        },
                      ),
                    ],
                  ),
                ),

              // Net Balance Card (refined)
              _BankBalanceCard(
                net: netByMember[myUid] ?? summary.netBalance,
                paid: summary.totalPaid,
                share: summary.totalShare,
                disputed: disputedShare,
                settlements: settlements,
                memberMap: memberMap,
                myUid: myUid,
              ),

              const SizedBox(height: 14),

              Row(
                children: [
                  PeriodSelector(
                    initial: _period,
                    onChanged: (r) => setState(() => _range = r),
                    onTypeChanged: (t) => setState(() => _period = t),
                    onLabelChanged: (l) => setState(() => _periodLabel = l),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _MetricTile(
                label: _periodLabel,
                value: Fmt.money(periodTotal),
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
                    onPressed: () => context.pushNamed(
                      'group_transactions',
                      pathParameters: {'groupId': groupId},
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
                  itemBuilder: (context, i) =>
                      _activityTile(context, transactions[i]),
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

    final title = (tx.category == null || tx.category!.trim().isEmpty)
        ? (tx.type == 'settlement' ? 'Settlement' : 'Expense')
        : tx.category!.trim();

    final total = tx.amount;
    final participantsCount = tx.participants.length;
    final dateText = Fmt.date(tx.at);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.push('/group/${widget.groupId}/tx/${tx.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: cs.outlineVariant.withValues(alpha: 0.35),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ================= TITLE + TOTAL =================
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                Text(
                  Fmt.money(total),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: AppColors.green,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // ================= PAYERS MULTI ROW =================
            if (tx.payers.isNotEmpty) ...[
              Text(
                'Paid by',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 6),
              ...tx.payers.map((payer) {
                final payerName = widget.memberMap[payer.uid]?.name ?? 'Unknown';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          payerName,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface,
                          ),
                        ),
                      ),
                      Text(
                        Fmt.money(payer.amount),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.green,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],

            const SizedBox(height: 10),

            // ================= PARTICIPANTS + DATE =================
            Row(
              children: [
                Text(
                  '$participantsCount participant${participantsCount == 1 ? '' : 's'}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '• $dateText',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.chevron_right_rounded,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                  size: 20,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BankBalanceCard extends StatelessWidget {
  final double net;
  final double paid;
  final double share;
  final double disputed;
  final List<BalanceTransfer> settlements;
  final Map<String, GroupMember> memberMap;
  final String myUid;

  const _BankBalanceCard({
    required this.net,
    required this.paid,
    required this.share,
    required this.disputed,
    required this.settlements,
    required this.memberMap,
    required this.myUid,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Only black/white/green (+ opacity)
    final bg = isDark ? AppColors.black : AppColors.white;
    final stroke = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.black.withValues(alpha: 0.08);
    final soft = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.04);
    final text = isDark ? AppColors.white : Colors.black;
    final sub = isDark
        ? Colors.white.withValues(alpha: 0.72)
        : Colors.black.withValues(alpha: 0.62);

    final positive = net >= 0;
    final balanceColor = positive ? AppColors.green : Colors.red;

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
                  color: balanceColor,
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
                  color: balanceColor,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.8,
                ),
              ),
              Text(
                Fmt.money(net.abs()),
                style: theme.textTheme.headlineLarge?.copyWith(
                  color: balanceColor,
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
          if (disputed > 0) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.orange.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.report_problem_outlined,
                    color: Colors.orange,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Disputed',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: text,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    Fmt.money(disputed),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.orange,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (settlements.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...settlements.map((transfer) {
              final isPayment = transfer.fromUid == myUid;
              final otherUid = isPayment ? transfer.toUid : transfer.fromUid;
              final otherName =
                  memberMap[otherUid]?.displayName ?? 'Unknown member';

              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Icon(
                      isPayment
                          ? Icons.arrow_outward_rounded
                          : Icons.arrow_downward_rounded,
                      size: 18,
                      color: isPayment ? Colors.red : AppColors.green,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isPayment
                            ? 'Pay $otherName'
                            : 'Receive from $otherName',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: text,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      Fmt.money(transfer.amount),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isPayment ? Colors.red : AppColors.green,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
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
    this.onTap, //  optional
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bg = isDark ? AppColors.black : AppColors.white;
    final stroke = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.black.withValues(alpha: 0.08);
    final text = isDark ? AppColors.white : Colors.black;
    final sub = isDark
        ? Colors.white.withValues(alpha: 0.72)
        : Colors.black.withValues(alpha: 0.62);

    final accentBg = isDark
        ? AppColors.green.withValues(alpha: 0.14)
        : AppColors.green.withValues(alpha: 0.10);

    final tileBg = isAccent ? accentBg : bg;
    final tileBorder =
        isAccent ? AppColors.green.withValues(alpha: 0.35) : stroke;

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
