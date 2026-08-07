import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/format.dart';
import '../../../data/auth_repo.dart';
import '../../../data/chat_repo.dart';
import '../../../data/group_repo.dart';
import '../../../data/personal_repo.dart';
import '../../../domain/models/debt_aggregator.dart';
import '../../../domain/models/personal_tx.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/empty_hint.dart';
import '../../widgets/period_selector.dart';

// Uses only: green / white / black via your app theme.
// The screen uses Theme colors (primary = AppColors.green).
class PersonalHomeScreen extends StatefulWidget {
  const PersonalHomeScreen({super.key});

  @override
  State<PersonalHomeScreen> createState() => _PersonalHomeScreenState();
}

class _PersonalHomeScreenState extends State<PersonalHomeScreen> {
  // --- Hide/Show: each item has its own toggle (default hidden) ---
  bool _hideBalance = true;
  bool _hideIncome = true;
  bool _hideExpense = true;
  bool _hideToPay = true;
  bool _hideToReceive = true;

  // Net-for-period shares one toggle; period is selectable (Week/Month),
  // defaulting to the current month.
  bool _hideNets = true;
  PeriodType _homePeriod = PeriodType.month;
  String _homePeriodLabel = 'This Month';
  DateRange? _homeRange;

  // Each transaction has its own hide toggle (default hidden)
  final Map<String, bool> _txHidden = {}; // txId -> hidden?

  Timer? _autoHideTimer;

  // Group + friend-loan balances, aggregated alongside the personal ledger.
  // Loaded on-demand (not a live stream) since it fans out across every
  // group and friend the user has — see DebtAggregator for the merge logic.
  Future<List<DebtEntry>>? _externalDebtsFuture;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshExternalDebts());
  }

  void _refreshExternalDebts() {
    final uid = context.read<AuthRepo>().currentUser?.uid;
    if (uid == null) return;
    setState(() {
      _externalDebtsFuture = _loadExternalDebts(
        uid,
        context.read<GroupRepo>(),
        context.read<ChatRepo>(),
      );
    });
  }

  Future<List<DebtEntry>> _loadExternalDebts(
    String uid,
    GroupRepo groupRepo,
    ChatRepo chatRepo,
  ) async {
    // Groups: sum each group's net balance for this user.
    final groups = await groupRepo.watchMyGroups(uid).first;
    final netByGroup = <String, double>{};
    final groupNames = <String, String>{};
    for (final g in groups) {
      final balances = await groupRepo.calculateMemberBalances(g.id);
      final mine = balances[uid] ?? 0.0;
      if (mine.abs() > 0.005) {
        netByGroup[g.id] = mine;
        groupNames[g.id] = g.name;
      }
    }

    // Friends: sum each friend's P2P chat-loan balance.
    final friendsSnap = await chatRepo.watchFriends(uid).first;
    final balanceByFriend = <String, double>{};
    final friendNames = <String, String>{};
    for (final doc in friendsSnap.docs) {
      final friendUid = doc.id;
      final chatId = chatRepo.chatIdFor(uid, friendUid);
      final loanSnap = await chatRepo.watchLoanTransactions(chatId).first;
      final balance = chatRepo.loanBalanceFor(loanSnap.docs, uid);
      if (balance.abs() > 0.005) {
        balanceByFriend[friendUid] = balance;
        final userDoc = await chatRepo.watchUser(friendUid).first;
        friendNames[friendUid] = (userDoc.data()?['name'] as String?) ?? 'Friend';
      }
    }

    return [
      ...DebtAggregator.fromGroupBalances(netByGroup: netByGroup, groupNames: groupNames),
      ...DebtAggregator.fromFriendLoans(balanceByFriendUid: balanceByFriend, friendNames: friendNames),
    ];
  }

  bool _isTxHidden(String id) => _txHidden[id] ?? true;

  void _revealFor5s({
    required VoidCallback setVisible,
    required VoidCallback setHidden,
  }) {
    _autoHideTimer?.cancel();
    setState(setVisible);
    _autoHideTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted) return;
      setState(setHidden);
    });
  }

  void _toggleHeaderHidden(bool current, void Function(bool v) set) {
    if (current) {
      _revealFor5s(
        setVisible: () => set(false),
        setHidden: () => set(true),
      );
    } else {
      setState(() => set(true));
    }
  }

  void _toggleTxHidden(String id) {
    final current = _isTxHidden(id);
    if (current) {
      _revealFor5s(
        setVisible: () => _txHidden[id] = false,
        setHidden: () => _txHidden[id] = true,
      );
    } else {
      setState(() => _txHidden[id] = true);
    }
  }

  @override
  void dispose() {
    _autoHideTimer?.cancel();
    super.dispose();
  }

  // Optional hard reset on tab switch / navigation away (keeps everything hidden)
  @override
  void deactivate() {
    _hideBalance = true;
    _hideIncome = true;
    _hideExpense = true;
    _hideToPay = true;
    _hideToReceive = true;
    _hideNets = true;
    _txHidden.clear();
    _autoHideTimer?.cancel();
    super.deactivate();
  }

  Future<void> _showTxActions(
      BuildContext context, {
        required String uid,
        required PersonalTx tx,
      }) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final cs = theme.colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.outlineVariant.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: Icon(_isTxHidden(tx.id) ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                  title: Text(_isTxHidden(tx.id) ? 'Show amount (5s)' : 'Hide amount'),
                  onTap: () {
                    Navigator.pop(ctx, 'toggle');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.edit_rounded),
                  title: const Text('Edit'),
                  onTap: () {
                    Navigator.pop(ctx, 'edit');
                  },
                ),
                ListTile(
                  leading: Icon(Icons.delete_outline_rounded, color: cs.error),
                  title: Text('Delete', style: TextStyle(color: cs.error)),
                  onTap: () {
                    Navigator.pop(ctx, 'delete');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || action == null) return;

    if (action == 'toggle') {
      _toggleTxHidden(tx.id);
      return;
    }

    if (action == 'edit') {
      // NOTE: Route must exist in your router/app.
      // You can implement this screen later, but this keeps this file changes minimal.
      context.push('/app/personal/add?edit=${tx.id}');
      return;
    }

    if (action == 'delete') {
      final note = await _askDeleteNote(context);
      if (note == null) return;

      await context.read<PersonalRepo>().softDeletePersonal(
        uid: uid,
        tx: tx,
        deleteNote: note,
      );
      return;
    }
  }

  Future<String?> _askDeleteNote(BuildContext context) async {
    final ctrl = TextEditingController();
    try {
      return showDialog<String>(
        context: context,
        builder: (ctx) {
          final theme = Theme.of(ctx);
          final cs = theme.colorScheme;

          return AlertDialog(
            title: const Text('Delete Transaction'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('This will move the transaction to Deleted list with a note.'),
                const SizedBox(height: 12),
                TextField(
                  controller: ctrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Delete note',
                    hintText: 'e.g. Wrong amount / duplicate',
                    prefixIcon: Icon(Icons.note_alt_outlined),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, null),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: cs.error),
                onPressed: () {
                  final v = ctrl.text.trim();
                  if (v.isEmpty) return;
                  Navigator.pop(ctx, v);
                },
                child: const Text('Delete'),
              ),
            ],
          );
        },
      );
    } finally {
      ctrl.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final uid = context.read<AuthRepo>().currentUser!.uid;

    return AppScaffold(
      title: 'Personal Ledger',
      actions: [
        IconButton(
          tooltip: 'Analytics',
          icon: const Icon(Icons.bar_chart_rounded),
          onPressed: () => context.push('/app/personal/analytics'),
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/app/personal/add'),
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
      child: StreamBuilder<List<PersonalTx>>(
        stream: context.read<PersonalRepo>().watchPersonal(uid),
        builder: (context, snap) {
          final items = (snap.data ?? []).toList();

          // ---- Sort newest first
          items.sort((a, b) => b.at.compareTo(a.at));

          // ---- Banking totals
          double totalIncome = 0;
          double totalExpense = 0;

          // Loans principal (still needed for the recent-activity signed amounts below)
          final Map<String, PersonalTx> loanPrincipals = {};

          for (final t in items) {
            switch (t.type) {
              case PersonalTxType.income:
                totalIncome += t.amount;
                break;
              case PersonalTxType.expense:
                totalExpense += t.amount;
                break;

              case PersonalTxType.loanGiven:
              case PersonalTxType.loanTaken:
                loanPrincipals[t.loanId ?? t.id] = t;
                break;

              case PersonalTxType.loanPayment:
                break;
            }
          }

          // Balance (simple cashflow view)
          final balance = totalIncome - totalExpense;

          // ---- Net for the selected period (Week/Month, any period — defaults to current month)
          final homeRange = _homeRange ?? rangeForPeriod(_homePeriod);
          double periodNet = 0;
          for (final t in items) {
            if (homeRange.contains(t.at)) {
              periodNet += _signedAmount(t, loanPrincipals);
            }
          }

          return FutureBuilder<List<DebtEntry>>(
            future: _externalDebtsFuture,
            builder: (context, extSnap) {
              // ---- Unify personal loans + group balances + friend chat loans
              final personalEntries = DebtAggregator.fromPersonalLoans(items);
              final allEntries = <DebtEntry>[...personalEntries, ...(extSnap.data ?? const <DebtEntry>[])];
              final totals = DebtAggregator.summarize(allEntries);
              final payableOutstanding = totals.payable;
              final receivableOutstanding = totals.receivable;
              final payableLoans = totals.entries.where((e) => e.isPayable).toList();
              final receivableLoans = totals.entries.where((e) => e.isReceivable).toList();

              if (items.isEmpty && allEntries.isEmpty) {
                return const EmptyHint('No personal entries yet.');
              }

              return RefreshIndicator(
                onRefresh: () async => _refreshExternalDebts(),
                child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _BankHeader(
                  hideBalance: _hideBalance,
                  hideIncome: _hideIncome,
                  hideExpense: _hideExpense,
                  hideToPay: _hideToPay,
                  hideToReceive: _hideToReceive,
                  hideNets: _hideNets,

                  onToggleBalance: () => _toggleHeaderHidden(_hideBalance, (v) => _hideBalance = v),
                  onToggleIncome: () => _toggleHeaderHidden(_hideIncome, (v) => _hideIncome = v),
                  onToggleExpense: () => _toggleHeaderHidden(_hideExpense, (v) => _hideExpense = v),
                  onToggleToPay: () => _toggleHeaderHidden(_hideToPay, (v) => _hideToPay = v),
                  onToggleToReceive: () => _toggleHeaderHidden(_hideToReceive, (v) => _hideToReceive = v),
                  onToggleNets: () => _toggleHeaderHidden(_hideNets, (v) => _hideNets = v),

                  balance: balance,
                  income: totalIncome,
                  expense: totalExpense,
                  payable: payableOutstanding,
                  receivable: receivableOutstanding,
                  periodNet: periodNet,
                  homePeriod: _homePeriod,
                  periodLabel: _homePeriodLabel,
                  onHomePeriodChanged: (p) => setState(() => _homePeriod = p),
                  onHomePeriodLabelChanged: (l) => setState(() => _homePeriodLabel = l),
                  onHomeRangeChanged: (r) => setState(() => _homeRange = r),
                ),
              ),

              // Loans section
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    'Loans',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
              ),

              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    children: [
                      _LoansCard(
                        title: 'Loans to Pay',
                        subtitle: 'You owe',
                        hide: _hideToPay, // independent
                        rows: payableLoans,
                        emptyText: 'No payable loans',
                        onTap: (e) => _openDebtEntry(context, e, isPayCard: true),
                      ),
                      const SizedBox(height: 12),
                      _LoansCard(
                        title: 'Loans to Receive',
                        subtitle: 'You will get back',
                        hide: _hideToReceive, // independent
                        rows: receivableLoans,
                        emptyText: 'No receivable loans',
                        onTap: (e) => _openDebtEntry(context, e, isPayCard: false),
                      ),
                    ],
                  ),
                ),
              ),

              // Recent
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    'Recent Activity',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
              ),

              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (context, i) {
                      final t = items[i];

                      final info = _txUiInfo(context, t, loanPrincipals);

                      final hideTx = _isTxHidden(t.id);

                      return Card(
                        elevation: 0,
                        color: cs.surface,
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                          side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.35)),
                        ),
                        child: ListTile(
                          onTap: () => _showTxActions(context, uid: uid, tx: t),
                          leading: CircleAvatar(
                            backgroundColor: cs.primary.withValues(alpha: 0.12),
                            child: Icon(info.icon, color: cs.primary),
                          ),
                          title: Text(
                            info.title,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${info.subtitle}  •  ${Fmt.date(t.at)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: hideTx ? 'Show (5s)' : 'Hide',
                                onPressed: () => _toggleTxHidden(t.id),
                                icon: Icon(hideTx ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                              ),
                              _MoneyText(
                                hide: hideTx,
                                value: info.moneyText,
                                isPositive: info.isPositive,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    childCount: items.length,
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 90)),
            ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _openDebtEntry(BuildContext context, DebtEntry e, {required bool isPayCard}) {
    switch (e.source) {
      case DebtSource.personal:
        final param = isPayCard ? 'payLoan' : 'receiveLoan';
        context.push('/app/personal/add?$param=${e.loanId}');
        break;
      case DebtSource.group:
        context.push('/group/${e.groupId}');
        break;
      case DebtSource.friend:
        context.push('/chat/${e.friendUid}');
        break;
    }
  }

  // Treat loan payments:
  // - paying a taken loan = expense
  // - receiving back a given loan = income
  double _signedAmount(PersonalTx t, Map<String, PersonalTx> loanPrincipals) {
    switch (t.type) {
      case PersonalTxType.income:
        return t.amount;
      case PersonalTxType.expense:
        return -t.amount;

      case PersonalTxType.loanGiven:
      // giving loan: cash out
        return -t.amount;

      case PersonalTxType.loanTaken:
      // taking loan: cash in
        return t.amount;

      case PersonalTxType.loanPayment:
        final target = t.targetLoanId;
        final principal = target == null ? null : loanPrincipals[target];
        if (principal == null) return -t.amount; // safe default
        if (principal.type == PersonalTxType.loanTaken) return -t.amount; // you paid
        return t.amount; // you received
    }
  }

  _TxUi _txUiInfo(BuildContext context, PersonalTx t, Map<String, PersonalTx> loanPrincipals) {
    String subtitle = '';
    IconData icon = Icons.receipt_long_outlined;
    bool positive = false;
    String title = t.title;

    switch (t.type) {
      case PersonalTxType.expense:
        subtitle = 'Expense';
        icon = Icons.south_west_rounded;
        positive = false;
        break;
      case PersonalTxType.income:
        subtitle = 'Income';
        icon = Icons.north_east_rounded;
        positive = true;
        break;
      case PersonalTxType.loanGiven:
        subtitle = 'Loan given${t.counterparty == null ? '' : ' • ${t.counterparty}'}';
        icon = Icons.call_made_rounded;
        positive = false;
        break;
      case PersonalTxType.loanTaken:
        subtitle = 'Loan taken${t.counterparty == null ? '' : ' • ${t.counterparty}'}';
        icon = Icons.call_received_rounded;
        positive = true;
        break;
      case PersonalTxType.loanPayment:
        final principal = t.targetLoanId == null ? null : loanPrincipals[t.targetLoanId!];
        final isPaying = principal?.type == PersonalTxType.loanTaken;
        subtitle = isPaying ? 'Loan payment' : 'Loan received';
        icon = isPaying ? Icons.payments_rounded : Icons.savings_rounded;
        positive = !isPaying;
        break;
    }

    final moneyText = (positive ? '+ ' : '- ') + Fmt.money(t.amount);
    return _TxUi(title: title, subtitle: subtitle, icon: icon, isPositive: positive, moneyText: moneyText);
  }
}

class _TxUi {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isPositive;
  final String moneyText;

  _TxUi({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isPositive,
    required this.moneyText,
  });
}

class _BankHeader extends StatelessWidget {
  final bool hideBalance;
  final bool hideIncome;
  final bool hideExpense;
  final bool hideToPay;
  final bool hideToReceive;
  final bool hideNets;

  final VoidCallback onToggleBalance;
  final VoidCallback onToggleIncome;
  final VoidCallback onToggleExpense;
  final VoidCallback onToggleToPay;
  final VoidCallback onToggleToReceive;
  final VoidCallback onToggleNets;

  final double balance;
  final double income;
  final double expense;

  final double payable;
  final double receivable;

  final double periodNet;
  final PeriodType homePeriod;
  final String periodLabel;
  final ValueChanged<PeriodType> onHomePeriodChanged;
  final ValueChanged<String> onHomePeriodLabelChanged;
  final ValueChanged<DateRange> onHomeRangeChanged;

  const _BankHeader({
    required this.hideBalance,
    required this.hideIncome,
    required this.hideExpense,
    required this.hideToPay,
    required this.hideToReceive,
    required this.hideNets,
    required this.onToggleBalance,
    required this.onToggleIncome,
    required this.onToggleExpense,
    required this.onToggleToPay,
    required this.onToggleToReceive,
    required this.onToggleNets,
    required this.balance,
    required this.income,
    required this.expense,
    required this.payable,
    required this.receivable,
    required this.periodNet,
    required this.homePeriod,
    required this.periodLabel,
    required this.onHomePeriodChanged,
    required this.onHomePeriodLabelChanged,
    required this.onHomeRangeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // ✅ No big outer box: use compact spacing + separate small cards
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- Balance (compact card) ---
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.30)),
              color: cs.surface,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Available Balance',
                      style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: onToggleBalance,
                      icon: Icon(
                        hideBalance ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                        size: 20,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: Text(
                    hideBalance ? '*****' : Fmt.money(balance),
                    key: ValueKey(hideBalance),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: cs.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // --- Income / Expense (tighter spacing) ---
          Row(
            children: [
              Expanded(
                child: _StatPill(
                  label: 'Income',
                  value: hideIncome ? '*****' : Fmt.money(income),
                  icon: Icons.north_east_rounded,
                  hidden: hideIncome,
                  onToggle: onToggleIncome,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatPill(
                  label: 'Expenses',
                  value: hideExpense ? '*****' : Fmt.money(expense),
                  icon: Icons.south_west_rounded,
                  hidden: hideExpense,
                  onToggle: onToggleExpense,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // --- To Pay / To Receive (tighter spacing) ---
          Row(
            children: [
              Expanded(
                child: _StatPill(
                  label: 'To Pay',
                  value: hideToPay ? '*****' : Fmt.money(payable),
                  icon: Icons.payments_rounded,
                  hidden: hideToPay,
                  onToggle: onToggleToPay,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatPill(
                  label: 'To Receive',
                  value: hideToReceive ? '*****' : Fmt.money(receivable),
                  icon: Icons.savings_rounded,
                  hidden: hideToReceive,
                  onToggle: onToggleToReceive,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // ✅ Net for a selectable period (defaults to current month)
          Row(
            children: [
              Text(
                'Net',
                style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: onToggleNets,
                icon: Icon(
                  hideNets ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  size: 20,
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          Row(
            children: [
              PeriodSelector(
                initial: homePeriod,
                onChanged: onHomeRangeChanged,
                onTypeChanged: onHomePeriodChanged,
                onLabelChanged: onHomePeriodLabelChanged,
              ),
            ],
          ),

          const SizedBox(height: 8),

          _MiniNet(
            label: periodLabel,
            value: periodNet,
            hide: hideNets,
          ),
        ],
      ),
    );
  }
}

class _MiniNet extends StatelessWidget {
  final String label;
  final double value;
  final bool hide;

  const _MiniNet({required this.label, required this.value, required this.hide});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final positive = value >= 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), // ✅ slightly smaller
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelSmall),
          const SizedBox(height: 4),
          Text(
            hide ? '*****' : (positive ? '+ ${Fmt.money(value)}' : '- ${Fmt.money(value.abs())}'),
            style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  final bool hidden;
  final VoidCallback onToggle;

  const _StatPill({
    required this.label,
    required this.value,
    required this.icon,
    required this.hidden,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10), // ✅ tighter
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.30)),
        color: cs.surface,
      ),
      child: Row(
        children: [
          // ✅ Smaller arrow icon so amount shows properly
          Icon(icon, color: cs.primary, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.labelSmall),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onToggle,
            icon: Icon(hidden ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 18),
          ),
        ],
      ),
    );
  }
}

class _MoneyText extends StatelessWidget {
  final bool hide;
  final String value;
  final bool isPositive;

  const _MoneyText({
    required this.hide,
    required this.value,
    required this.isPositive,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: Text(
        hide ? '*****' : value,
        key: ValueKey(hide),
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w900,
          color: isPositive ? cs.primary : cs.onSurface,
        ),
      ),
    );
  }
}

class _LoansCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool hide;
  final List<DebtEntry> rows;
  final String emptyText;
  final ValueChanged<DebtEntry> onTap;

  const _LoansCard({
    required this.title,
    required this.subtitle,
    required this.hide,
    required this.rows,
    required this.emptyText,
    required this.onTap,
  });

  static String _sourceLabel(DebtEntry e) {
    switch (e.source) {
      case DebtSource.personal:
        return 'Personal';
      case DebtSource.group:
        return 'Group';
      case DebtSource.friend:
        return 'Friend';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row (no box)
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
            ),
            Text(subtitle, style: theme.textTheme.labelMedium),
          ],
        ),
        const SizedBox(height: 10),

        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(emptyText, style: theme.textTheme.bodyMedium),
          )
        else
          ...rows.take(6).map((r) {
            final amount = r.amount.abs();

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => onTap(r),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: cs.primary.withValues(alpha: 0.06),
                    border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.account_balance_wallet_rounded),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              r.label,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              _sourceLabel(r),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: cs.onSurfaceVariant,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        hide ? '*****' : Fmt.money(amount),
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.chevron_right_rounded, color: cs.primary),
                    ],
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }
}