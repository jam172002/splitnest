import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format.dart';
import '../../../data/auth_repo.dart';
import '../../../data/personal_repo.dart';
import '../../../domain/models/personal_tx.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/busy_button.dart';

class AddPersonalTxScreen extends StatefulWidget {
  const AddPersonalTxScreen({super.key});

  @override
  State<AddPersonalTxScreen> createState() => _AddPersonalTxScreenState();
}

class _AddPersonalTxScreenState extends State<AddPersonalTxScreen> {
  final _title = TextEditingController();
  final _amount = TextEditingController();
  final _counterparty = TextEditingController();

  bool _busy = false;
  String? _err;

  PersonalTxType _type = PersonalTxType.expense;

  // For loan payment
  String? _targetLoanId;

  final List<String> _quickExpense = ['Groceries', 'Food', 'Transport', 'Rent', 'Medicine'];
  final List<String> _quickIncome = ['Salary', 'Freelance', 'Refund', 'Bonus'];

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    _counterparty.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _err = null;
    });

    try {
      final amt = double.tryParse(_amount.text.trim());
      if (amt == null || amt <= 0) throw Exception('Enter valid amount');

      final title = _title.text.trim();
      if (title.isEmpty) throw Exception('Enter title');

      // Loan payments require a selected loan
      if (_type == PersonalTxType.loanPayment && (_targetLoanId == null || _targetLoanId!.isEmpty)) {
        throw Exception('Select a loan first');
      }

      final uid = context.read<AuthRepo>().currentUser!.uid;

      await context.read<PersonalRepo>().addPersonal(
        uid: uid,
        amount: amt,
        title: title,
        at: DateTime.now(),
        type: _type,
        counterparty: _counterparty.text.trim().isEmpty ? null : _counterparty.text.trim(),
        targetLoanId: _type == PersonalTxType.loanPayment ? _targetLoanId : null,
      );

      if (mounted) context.pop();
    } catch (e) {
      setState(() => _err = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final uid = context.read<AuthRepo>().currentUser!.uid;

    final quick = _type == PersonalTxType.income ? _quickIncome : _quickExpense;

    return AppScaffold(
      title: 'Add Entry',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Type selector (banking segmented)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
                color: cs.surface,
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _typeChip('Expense', PersonalTxType.expense, Icons.south_west_rounded),
                  _typeChip('Income', PersonalTxType.income, Icons.north_east_rounded),
                  _typeChip('Give Loan', PersonalTxType.loanGiven, Icons.call_made_rounded),
                  _typeChip('Take Loan', PersonalTxType.loanTaken, Icons.call_received_rounded),
                  _typeChip('Pay / Receive', PersonalTxType.loanPayment, Icons.payments_rounded),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Amount (big, modern)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 22),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
                color: cs.primary.withValues(alpha: 0.08),
              ),
              child: Column(
                children: [
                  Text('AMOUNT', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _amount,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: cs.primary,
                    ),
                    decoration: const InputDecoration(
                      hintText: '0.00',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            TextField(
              controller: _title,
              decoration: InputDecoration(
                labelText: _labelForTitle(_type),
                prefixIcon: const Icon(Icons.description_outlined),
                hintText: _hintForTitle(_type),
              ),
            ),

            const SizedBox(height: 12),

            // Counterparty for loans (optional)
            if (_type == PersonalTxType.loanGiven || _type == PersonalTxType.loanTaken)
              TextField(
                controller: _counterparty,
                decoration: const InputDecoration(
                  labelText: 'Person (optional)',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                  hintText: 'e.g. Ali',
                ),
              ),

            // Loan picker for payments
            if (_type == PersonalTxType.loanPayment) ...[
              const SizedBox(height: 12),
              _LoanPicker(
                uid: uid,
                selectedLoanId: _targetLoanId,
                onChanged: (id) => setState(() => _targetLoanId = id),
              ),
              const SizedBox(height: 6),
              Text(
                'Tip: Use Pay/Receive for partial or full settlement. The app will auto-adjust outstanding based on payments.',
                style: theme.textTheme.labelSmall,
              ),
            ],

            const SizedBox(height: 14),

            // Quick select (expense/income only)
            if (_type == PersonalTxType.expense || _type == PersonalTxType.income) ...[
              Text('Quick Select', style: theme.textTheme.labelMedium),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: quick
                      .map(
                        (cat) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        label: Text(cat),
                        onPressed: () => setState(() => _title.text = cat),
                        backgroundColor: cs.surface,
                        shape: StadiumBorder(
                          side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.35)),
                        ),
                      ),
                    ),
                  )
                      .toList(),
                ),
              ),
              const SizedBox(height: 16),
            ],

            if (_err != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  _err!,
                  style: TextStyle(color: cs.error),
                  textAlign: TextAlign.center,
                ),
              ),

            BusyButton(
              busy: _busy,
              onPressed: _save,
              text: _buttonText(_type),
            ),
          ],
        ),
      ),
    );
  }

  Widget _typeChip(String text, PersonalTxType t, IconData icon) {
    final cs = Theme.of(context).colorScheme;
    final selected = _type == t;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => setState(() {
        _type = t;
        _targetLoanId = null;
        _err = null;

        // Helpful defaults
        if (t == PersonalTxType.loanPayment) {
          _title.text = 'Loan Payment';
        } else if (t == PersonalTxType.loanGiven) {
          _title.text = 'Loan Given';
        } else if (t == PersonalTxType.loanTaken) {
          _title.text = 'Loan Taken';
        }
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: selected ? cs.primary.withValues(alpha: 0.18) : cs.surface,
          border: Border.all(
            color: selected ? cs.primary : cs.outlineVariant.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: selected ? cs.primary : cs.onSurface),
            const SizedBox(width: 8),
            Text(
              text,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: selected ? cs.primary : cs.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _labelForTitle(PersonalTxType t) {
    switch (t) {
      case PersonalTxType.expense:
        return 'Expense Title';
      case PersonalTxType.income:
        return 'Income Title';
      case PersonalTxType.loanGiven:
        return 'Loan Title';
      case PersonalTxType.loanTaken:
        return 'Loan Title';
      case PersonalTxType.loanPayment:
        return 'Payment Title';
    }
  }

  String _hintForTitle(PersonalTxType t) {
    switch (t) {
      case PersonalTxType.expense:
        return 'e.g. Weekly Groceries';
      case PersonalTxType.income:
        return 'e.g. Salary';
      case PersonalTxType.loanGiven:
        return 'e.g. Lent to Ali';
      case PersonalTxType.loanTaken:
        return 'e.g. Borrowed from Ahmed';
      case PersonalTxType.loanPayment:
        return 'e.g. Paid installment';
    }
  }

  String _buttonText(PersonalTxType t) {
    switch (t) {
      case PersonalTxType.expense:
        return 'Save Expense';
      case PersonalTxType.income:
        return 'Save Income';
      case PersonalTxType.loanGiven:
        return 'Save Given Loan';
      case PersonalTxType.loanTaken:
        return 'Save Taken Loan';
      case PersonalTxType.loanPayment:
        return 'Save Payment';
    }
  }
}

class _LoanPicker extends StatelessWidget {
  final String uid;
  final String? selectedLoanId;
  final ValueChanged<String?> onChanged;

  const _LoanPicker({
    required this.uid,
    required this.selectedLoanId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
        color: cs.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Select Loan', style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),

          // We reuse your personal stream to show only open loans.
          StreamBuilder<List<PersonalTx>>(
            stream: context.read<PersonalRepo>().watchPersonal(uid),
            builder: (context, snap) {
              final all = snap.data ?? [];

              final principals = <String, PersonalTx>{};
              final paid = <String, double>{};

              for (final t in all) {
                if (t.type == PersonalTxType.loanGiven || t.type == PersonalTxType.loanTaken) {
                  principals[t.loanId ?? t.id] = t;
                } else if (t.type == PersonalTxType.loanPayment && t.targetLoanId != null) {
                  paid[t.targetLoanId!] = (paid[t.targetLoanId!] ?? 0) + t.amount;
                }
              }

              final open = <MapEntry<String, PersonalTx>>[];
              for (final e in principals.entries) {
                final remaining = e.value.amount - (paid[e.key] ?? 0);
                if (remaining > 0.00001) open.add(e);
              }

              if (open.isEmpty) {
                return Text('No open loans found.', style: theme.textTheme.bodyMedium);
              }

              return DropdownButtonFormField<String>(
                initialValue: selectedLoanId,
                items: open.map((e) {
                  final loan = e.value;
                  final rem = loan.amount - (paid[e.key] ?? 0);
                  final who = (loan.counterparty == null || loan.counterparty!.isEmpty)
                      ? ''
                      : ' • ${loan.counterparty}';
                  final label = '${loan.type == PersonalTxType.loanTaken ? 'To Pay' : 'To Receive'}$who  —  ${Fmt.money(rem)}';
                  return DropdownMenuItem(value: e.key, child: Text(label, overflow: TextOverflow.ellipsis));
                }).toList(),
                onChanged: onChanged,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.account_balance_wallet_rounded),
                  hintText: 'Choose loan',
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}