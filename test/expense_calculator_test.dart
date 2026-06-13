import 'package:flutter_test/flutter_test.dart';
import 'package:splitnest/domain/models/expense_calculator.dart';
import 'package:splitnest/domain/models/tx.dart';

void main() {
  group('ExpenseCalculator.calculateSettlements', () {
    test('matches one debtor with multiple creditors', () {
      final transfers = ExpenseCalculator.calculateSettlements({
        'me': -90,
        'alex': 50,
        'sam': 40,
      });

      expect(transfers, hasLength(2));
      expect(transfers[0].fromUid, 'me');
      expect(transfers[0].toUid, 'alex');
      expect(transfers[0].amount, 50);
      expect(transfers[1].fromUid, 'me');
      expect(transfers[1].toUid, 'sam');
      expect(transfers[1].amount, 40);
    });

    test('matches multiple debtors with one creditor', () {
      final transfers = ExpenseCalculator.calculateSettlements({
        'me': 75,
        'alex': -25,
        'sam': -50,
      });

      expect(transfers, hasLength(2));
      expect(transfers[0].fromUid, 'alex');
      expect(transfers[0].toUid, 'me');
      expect(transfers[0].amount, 25);
      expect(transfers[1].fromUid, 'sam');
      expect(transfers[1].toUid, 'me');
      expect(transfers[1].amount, 50);
    });

    test('ignores settled and rounding-only balances', () {
      final transfers = ExpenseCalculator.calculateSettlements({
        'me': -0.001,
        'alex': 0.001,
        'sam': 0,
      });

      expect(transfers, isEmpty);
    });
  });

  test('keeps disputed shares separate from approved totals', () {
    final tx = GroupTx(
      id: 'expense-1',
      type: 'expense',
      amount: 100,
      at: DateTime(2026),
      createdBy: 'alex',
      payers: const [PayerPortion(uid: 'alex', amount: 100)],
      participants: const ['alex', 'me'],
      status: TxStatus.disputed,
    );

    final summary = ExpenseCalculator.calculateMemberSummary([tx], 'me');

    expect(summary.totalPaid, 0);
    expect(summary.totalShare, 0);
    expect(summary.netBalance, 0);
    expect(ExpenseCalculator.calculateDisputedShare([tx], 'me'), 50);
  });
}
