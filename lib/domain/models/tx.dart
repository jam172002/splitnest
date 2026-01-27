enum TxStatus { pending, approved, rejected }

class GroupTx {
  final String id;
  final String type; // 'expense' | 'settlement'

  final double amount;
  final DateTime at;

  // Expense fields
  final String category;
  final String paidBy; // uid
  final List<String> participants; // uids

  // Settlement fields
  final String? fromUid;
  final String? toUid;

  // Common fields
  final String? description;          // ← NEW: optional note/description
  final TxStatus status;
  final List<String> endorsedBy;      // uids who approved
  final String createdBy;             // uid

  GroupTx({
    required this.id,
    required this.type,
    required this.amount,
    required this.at,
    required this.status,
    required this.endorsedBy,
    required this.createdBy,
    this.category = '',
    this.paidBy = '',
    this.participants = const [],
    this.fromUid,
    this.toUid,
    this.description,                    // ← added here
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'type': type,
      'amount': amount,
      'at': at.toIso8601String(),
      'status': status.name,
      'endorsedBy': endorsedBy,
      'createdBy': createdBy,
    };

    // Expense-specific
    if (type == 'expense') {
      map.addAll({
        'category': category,
        'paidBy': paidBy,
        'participants': participants,
      });
    }

    // Settlement-specific
    if (type == 'settlement') {
      map.addAll({
        'fromUid': fromUid,
        'toUid': toUid,
      });
    }

    // Common optional field
    if (description != null && description!.trim().isNotEmpty) {
      map['description'] = description!.trim();
    }

    return map;
  }

  factory GroupTx.fromMap(String id, Map<String, dynamic> m) {
    final type = (m['type'] ?? 'expense') as String;

    return GroupTx(
      id: id,
      type: type,
      amount: ((m['amount'] ?? 0) as num).toDouble(),
      at: DateTime.tryParse((m['at'] ?? '') as String) ?? DateTime.now(),
      status: TxStatus.values.firstWhere(
            (e) => e.name == (m['status'] ?? 'pending'),
        orElse: () => TxStatus.pending,
      ),
      endorsedBy: List<String>.from((m['endorsedBy'] ?? []) as List),
      createdBy: (m['createdBy'] ?? '') as String,

      // Expense fields
      category: type == 'expense' ? (m['category'] ?? '') as String : '',
      paidBy: type == 'expense' ? (m['paidBy'] ?? '') as String : '',
      participants: type == 'expense'
          ? List<String>.from((m['participants'] ?? []) as List)
          : const [],

      // Settlement fields
      fromUid: type == 'settlement' ? (m['fromUid'] as String?) : null,
      toUid: type == 'settlement' ? (m['toUid'] as String?) : null,

      // Common optional field
      description: m['description'] as String?,   // ← read from Firestore
    );
  }
}