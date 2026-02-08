import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/format.dart';
import '../../../data/auth_repo.dart';
import '../../../data/personal_repo.dart';
import '../../../domain/models/personal_tx.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/empty_hint.dart';

// Uses only: green / white / black via your app theme.
// The screen uses Theme colors (primary = AppColors.green).
class PersonalHomeScreen extends StatefulWidget {
  const PersonalHomeScreen({super.key});

  @override
  State<PersonalHomeScreen> createState() => _PersonalHomeScreenState();
}

class _PersonalHomeScreenState extends State<PersonalHomeScreen> {
  bool _hideAmounts = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final uid = context.read<AuthRepo>().currentUser!.uid;

    return AppScaffold(
      title: 'Personal Ledger',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/app/personal/add'),
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
      child: StreamBuilder<List<PersonalTx>>(
        stream: context.read<PersonalRepo>().watchPersonal(uid),
        builder: (context, snap) {
          final items = (snap.data ?? []).toList();

          if (items.isEmpty) {
            return const EmptyHint('No personal entries yet.');
          }

          // ---- Sort newest first
          items.sort((a, b) => b.at.compareTo(a.at));

          // ---- Banking totals
          double totalIncome = 0;
          double totalExpense = 0;

          // Loans principal
          final Map<String, PersonalTx> loanPrincipals = {};
          // Payments sum by loan id
          final Map<String, double> paidByLoan = {};

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
                final loanId = t.loanId ?? t.id;
                loanPrincipals[loanId] = t;
                break;

              case PersonalTxType.loanPayment:
                final id = t.targetLoanId;
                if (id != null) {
                  paidByLoan[id] = (paidByLoan[id] ?? 0) + t.amount;
                }
                break;
            }
          }

          // ---- Compute outstanding loans
          // Payable = you took loan and still owe
          // Receivable = you gave loan and still have to receive
          double payableOutstanding = 0;
          double receivableOutstanding = 0;

          final payableLoans = <_LoanRow>[];
          final receivableLoans = <_LoanRow>[];

          for (final e in loanPrincipals.entries) {
            final loanId = e.key;
            final principal = e.value;
            final paid = paidByLoan[loanId] ?? 0;
            final remaining = (principal.amount - paid);
            if (remaining <= 0.00001) continue;

            if (principal.type == PersonalTxType.loanTaken) {
              payableOutstanding += remaining;
              payableLoans.add(_LoanRow(
                loanId: loanId,
                title: principal.title,
                counterparty: principal.counterparty,
                remaining: remaining,
              ));
            } else {
              receivableOutstanding += remaining;
              receivableLoans.add(_LoanRow(
                loanId: loanId,
                title: principal.title,
                counterparty: principal.counterparty,
                remaining: remaining,
              ));
            }
          }

          // Balance (simple cashflow view)
          final balance = totalIncome - totalExpense;

          // ---- Date stats (today/week/month) for expenses + incomes (optional)
          final now = DateTime.now();
          final weekStart = now.subtract(Duration(days: now.weekday - 1));

          double todayNet = 0, weekNet = 0, monthNet = 0;
          for (final t in items) {
            final signed = _signedAmount(t, loanPrincipals);
            if (DateUtils.isSameDay(t.at, now)) todayNet += signed;
            if (t.at.isAfter(weekStart.subtract(const Duration(seconds: 1)))) weekNet += signed;
            if (t.at.year == now.year && t.at.month == now.month) monthNet += signed;
          }

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _BankHeader(
                  hide: _hideAmounts,
                  onToggleHide: () => setState(() => _hideAmounts = !_hideAmounts),
                  balance: balance,
                  income: totalIncome,
                  expense: totalExpense,
                  payable: payableOutstanding,
                  receivable: receivableOutstanding,
                  monthNet: monthNet,
                  todayNet: todayNet,
                  weekNet: weekNet,
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
                        hide: _hideAmounts,
                        rows: payableLoans,
                        emptyText: 'No payable loans',
                        onPay: (loanId) => context.push('/app/personal/add?payLoan=$loanId'),
                      ),
                      const SizedBox(height: 12),
                      _LoansCard(
                        title: 'Loans to Receive',
                        subtitle: 'You will get back',
                        hide: _hideAmounts,
                        rows: receivableLoans,
                        emptyText: 'No receivable loans',
                        onPay: (loanId) => context.push('/app/personal/add?receiveLoan=$loanId'),
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
                      return Card(
                        elevation: 0,
                        color: cs.surface,
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                          side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.35)),
                        ),
                        child: ListTile(
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
                          trailing: _MoneyText(
                            hide: _hideAmounts,
                            value: info.moneyText,
                            isPositive: info.isPositive,
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
          );
        },
      ),
    );
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
  final bool hide;
  final VoidCallback onToggleHide;

  final double balance;
  final double income;
  final double expense;

  final double payable;
  final double receivable;

  final double monthNet;
  final double todayNet;
  final double weekNet;

  const _BankHeader({
    required this.hide,
    required this.onToggleHide,
    required this.balance,
    required this.income,
    required this.expense,
    required this.payable,
    required this.receivable,
    required this.monthNet,
    required this.todayNet,
    required this.weekNet,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
        color: cs.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Balance row
          Row(
            children: [
              Text(
                'Available Balance',
                style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              IconButton(
                onPressed: onToggleHide,
                icon: Icon(hide ? Icons.visibility_off_rounded : Icons.visibility_rounded),
              ),
            ],
          ),
          const SizedBox(height: 6),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              hide ? '*****' : Fmt.money(balance),
              key: ValueKey(hide),
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
                color: cs.primary,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Income / Expense
          Row(
            children: [
              Expanded(
                child: _StatPill(
                  label: 'Income',
                  value: hide ? '*****' : Fmt.money(income),
                  icon: Icons.north_east_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatPill(
                  label: 'Expenses',
                  value: hide ? '*****' : Fmt.money(expense),
                  icon: Icons.south_west_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Loans quick totals
          Row(
            children: [
              Expanded(
                child: _StatPill(
                  label: 'To Pay',
                  value: hide ? '*****' : Fmt.money(payable),
                  icon: Icons.payments_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatPill(
                  label: 'To Receive',
                  value: hide ? '*****' : Fmt.money(receivable),
                  icon: Icons.savings_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Mini net stats (banking style)
          Row(
            children: [
              Expanded(child: _MiniNet(label: 'Today net', value: todayNet, hide: hide)),
              const SizedBox(width: 10),
              Expanded(child: _MiniNet(label: 'Week net', value: weekNet, hide: hide)),
              const SizedBox(width: 10),
              Expanded(child: _MiniNet(label: 'Month net', value: monthNet, hide: hide)),
            ],
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
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

  const _StatPill({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
        color: cs.surface,
      ),
      child: Row(
        children: [
          Icon(icon, color: cs.primary),
          const SizedBox(width: 10),
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

class _LoanRow {
  final String loanId;
  final String title;
  final String? counterparty;
  final double remaining;

  _LoanRow({
    required this.loanId,
    required this.title,
    required this.remaining,
    required this.counterparty,
  });
}

class _LoansCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool hide;
  final List<_LoanRow> rows;
  final String emptyText;
  final void Function(String loanId) onPay;

  const _LoansCard({
    required this.title,
    required this.subtitle,
    required this.hide,
    required this.rows,
    required this.emptyText,
    required this.onPay,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
        color: cs.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
            ...rows.take(4).map((r) {
              final name = (r.counterparty == null || r.counterparty!.trim().isEmpty)
                  ? r.title
                  : '${r.title} • ${r.counterparty}';
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => onPay(r.loanId),
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
                          child: Text(
                            name,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          hide ? '*****' : Fmt.money(r.remaining),
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
      ),
    );
  }
}