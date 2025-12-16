class PersonalTx {
  final String id;
  final double amount;
  final String title; // e.g. "Groceries"
  final DateTime at;

  PersonalTx({
    required this.id,
    required this.amount,
    required this.title,
    required this.at,
  });

  Map<String, dynamic> toMap() => {
    'amount': amount,
    'title': title,
    'at': at.toIso8601String(),
  };

  factory PersonalTx.fromMap(String id, Map<String, dynamic> m) => PersonalTx(
    id: id,
    amount: ((m['amount'] ?? 0) as num).toDouble(),
    title: (m['title'] ?? '') as String,
    at: DateTime.tryParse((m['at'] ?? '') as String) ?? DateTime.now(),
  );
}
