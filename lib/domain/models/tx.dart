enum TxStatus { pending, approved, rejected }

class GroupTx {
  final String id;
  final String type; // expense | settlement
  final double amount;
  final String category; // e.g breakfast, tea, milk
  final String paidBy; // uid
  final List<String> participants; // uids
  final DateTime at;
  final TxStatus status;
  final List<String> endorsedBy; // uids
  final String createdBy; // uid

  GroupTx({
    required this.id,
    required this.type,
    required this.amount,
    required this.category,
    required this.paidBy,
    required this.participants,
    required this.at,
    required this.status,
    required this.endorsedBy,
    required this.createdBy,
  });

  Map<String, dynamic> toMap() => {
    'type': type,
    'amount': amount,
    'category': category,
    'paidBy': paidBy,
    'participants': participants,
    'at': at.toIso8601String(),
    'status': status.name,
    'endorsedBy': endorsedBy,
    'createdBy': createdBy,
  };

  factory GroupTx.fromMap(String id, Map<String, dynamic> m) => GroupTx(
    id: id,
    type: (m['type'] ?? 'expense') as String,
    amount: ((m['amount'] ?? 0) as num).toDouble(),
    category: (m['category'] ?? '') as String,
    paidBy: (m['paidBy'] ?? '') as String,
    participants: List<String>.from((m['participants'] ?? const []) as List),
    at: DateTime.tryParse((m['at'] ?? '') as String) ?? DateTime.now(),
    status: TxStatus.values.firstWhere(
          (e) => e.name == (m['status'] ?? 'pending'),
      orElse: () => TxStatus.pending,
    ),
    endorsedBy: List<String>.from((m['endorsedBy'] ?? const []) as List),
    createdBy: (m['createdBy'] ?? '') as String,
  );
}
