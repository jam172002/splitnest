import 'personal_tx.dart';

enum DebtSource { personal, group, friend }

/// A single "I owe" / "I'm owed" line, from whichever system it came from.
/// [amount] is signed: positive = money owed *to* the user (receivable),
/// negative = money the user owes (payable).
class DebtEntry {
  final DebtSource source;
  final String label;

  /// Present when [source] is personal — the underlying loan doc id,
  /// used to route into the existing pay/receive flow.
  final String? loanId;

  /// Present when [source] is group — used to navigate to that group.
  final String? groupId;

  /// Present when [source] is friend — used to open that chat.
  final String? friendUid;

  final double amount;

  const DebtEntry({
    required this.source,
    required this.label,
    required this.amount,
    this.loanId,
    this.groupId,
    this.friendUid,
  });

  bool get isReceivable => amount > 0.005;
  bool get isPayable => amount < -0.005;
}

class DebtTotals {
  final double payable;
  final double receivable;
  final List<DebtEntry> entries;

  const DebtTotals({
    required this.payable,
    required this.receivable,
    required this.entries,
  });

  static const empty = DebtTotals(payable: 0, receivable: 0, entries: []);
}

/// Combines the app's three independent balance systems (personal manual
/// loan ledger, per-group settlement balances, per-friend chat loans) into
/// one "what do I owe / what am I owed" picture, without merging their
/// underlying Firestore data models.
class DebtAggregator {
  const DebtAggregator._();

  /// Personal ledger loans (PersonalTx loanGiven/loanTaken + loanPayment).
  static List<DebtEntry> fromPersonalLoans(List<PersonalTx> items) {
    final principals = <String, PersonalTx>{};
    final paidByLoan = <String, double>{};

    for (final t in items) {
      if (t.type == PersonalTxType.loanGiven || t.type == PersonalTxType.loanTaken) {
        principals[t.loanId ?? t.id] = t;
      } else if (t.type == PersonalTxType.loanPayment && t.targetLoanId != null) {
        paidByLoan[t.targetLoanId!] = (paidByLoan[t.targetLoanId!] ?? 0) + t.amount;
      }
    }

    final entries = <DebtEntry>[];
    for (final e in principals.entries) {
      final loanId = e.key;
      final principal = e.value;
      final remaining = principal.amount - (paidByLoan[loanId] ?? 0);
      if (remaining <= 0.005) continue;

      final label = (principal.counterparty == null || principal.counterparty!.trim().isEmpty)
          ? principal.title
          : '${principal.title} • ${principal.counterparty}';

      // loanTaken => you owe (payable, negative). loanGiven => you're owed (receivable, positive).
      final signedAmount = principal.type == PersonalTxType.loanTaken ? -remaining : remaining;

      entries.add(DebtEntry(
        source: DebtSource.personal,
        label: label,
        amount: signedAmount,
        loanId: loanId,
      ));
    }
    return entries;
  }

  /// One entry per group where the user has a non-zero net balance.
  /// [netByGroup] maps groupId -> the user's net balance in that group
  /// (positive = credited/owed money, negative = owes money).
  static List<DebtEntry> fromGroupBalances({
    required Map<String, double> netByGroup,
    required Map<String, String> groupNames,
  }) {
    final entries = <DebtEntry>[];
    for (final e in netByGroup.entries) {
      if (e.value.abs() <= 0.005) continue;
      entries.add(DebtEntry(
        source: DebtSource.group,
        label: groupNames[e.key] ?? 'Group',
        amount: e.value,
        groupId: e.key,
      ));
    }
    return entries;
  }

  /// One entry per friend with a non-zero P2P chat loan balance.
  /// [balanceByFriendUid] maps friendUid -> balance (positive = they owe you).
  static List<DebtEntry> fromFriendLoans({
    required Map<String, double> balanceByFriendUid,
    required Map<String, String> friendNames,
  }) {
    final entries = <DebtEntry>[];
    for (final e in balanceByFriendUid.entries) {
      if (e.value.abs() <= 0.005) continue;
      entries.add(DebtEntry(
        source: DebtSource.friend,
        label: friendNames[e.key] ?? 'Friend',
        amount: e.value,
        friendUid: e.key,
      ));
    }
    return entries;
  }

  static DebtTotals summarize(List<DebtEntry> entries) {
    double payable = 0;
    double receivable = 0;
    for (final e in entries) {
      if (e.isPayable) payable += -e.amount;
      if (e.isReceivable) receivable += e.amount;
    }
    final sorted = [...entries]..sort((a, b) => b.amount.compareTo(a.amount));
    return DebtTotals(payable: payable, receivable: receivable, entries: sorted);
  }
}
