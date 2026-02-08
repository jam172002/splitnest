enum PersonalTxType {
  expense,
  income,

  // loan principals
  loanGiven, // you gave money -> you will receive later
  loanTaken, // you took money -> you must pay later

  // payments against a loan (partial/full)
  loanPayment,
}

class PersonalTx {
  final String id;
  final double amount;
  final String title; // e.g. "Groceries", "Salary", "Loan Payment"
  final DateTime at;

  // NEW
  final PersonalTxType type;

  // For loan principal entries:
  final String? loanId; // usually equals doc id
  final String? counterparty; // person name (optional)

  // For loan payments:
  final String? targetLoanId; // loan this payment belongs to

  PersonalTx({
    required this.id,
    required this.amount,
    required this.title,
    required this.at,

    this.type = PersonalTxType.expense,
    this.loanId,
    this.counterparty,
    this.targetLoanId,
  });

  Map<String, dynamic> toMap() => {
    'amount': amount,
    'title': title,
    'at': at.toIso8601String(),

    // NEW
    'type': type.name,
    'loanId': loanId,
    'counterparty': counterparty,
    'targetLoanId': targetLoanId,
  };

  factory PersonalTx.fromMap(String id, Map<String, dynamic> m) {
    final typeStr = (m['type'] as String?) ?? 'expense';
    final type = PersonalTxType.values.firstWhere(
          (e) => e.name == typeStr,
      orElse: () => PersonalTxType.expense, // backward-compatible
    );

    return PersonalTx(
      id: id,
      amount: ((m['amount'] ?? 0) as num).toDouble(),
      title: (m['title'] ?? '') as String,
      at: DateTime.tryParse((m['at'] ?? '') as String) ?? DateTime.now(),

      // NEW
      type: type,
      loanId: (m['loanId'] as String?),
      counterparty: (m['counterparty'] as String?),
      targetLoanId: (m['targetLoanId'] as String?),
    );
  }

  // Convenience helpers (optional)
  bool get isExpense => type == PersonalTxType.expense;
  bool get isIncome => type == PersonalTxType.income;

  bool get isLoanPrincipal =>
      type == PersonalTxType.loanGiven || type == PersonalTxType.loanTaken;

  bool get isLoanPayment => type == PersonalTxType.loanPayment;
}