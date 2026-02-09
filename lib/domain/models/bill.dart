import 'package:cloud_firestore/cloud_firestore.dart';

enum BillInterval { monthly }

class BillTemplate {
  final String id;
  final String title;
  final double amount;
  final BillInterval interval;

  /// which members share this bill
  final List<String> participants;

  /// day in month bill is due (1..28/30)
  final int dueDay;

  /// optional: category label
  final String? category;

  /// audit
  final DateTime createdAt;
  final String createdBy;

  BillTemplate({
    required this.id,
    required this.title,
    required this.amount,
    required this.interval,
    required this.participants,
    required this.dueDay,
    required this.createdAt,
    required this.createdBy,
    this.category,
  });

  Map<String, dynamic> toMap() => {
    'title': title,
    'amount': amount,
    'interval': interval.name,
    'participants': participants,
    'dueDay': dueDay,
    if (category != null) 'category': category,
    'createdAt': createdAt.toIso8601String(),
    'createdBy': createdBy,
  };

  factory BillTemplate.fromMap(String id, Map<String, dynamic> m) {
    DateTime createdAt;
    final raw = m['createdAt'];
    if (raw is Timestamp) {
      createdAt = raw.toDate();
    } else {
      createdAt = DateTime.tryParse((raw ?? '') as String) ?? DateTime.now();
    }

    return BillTemplate(
      id: id,
      title: (m['title'] ?? '') as String,
      amount: ((m['amount'] ?? 0) as num).toDouble(),
      interval: BillInterval.values.firstWhere(
            (e) => e.name == (m['interval'] ?? 'monthly'),
        orElse: () => BillInterval.monthly,
      ),
      participants: (m['participants'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      dueDay: (m['dueDay'] ?? 1) as int,
      category: m['category'] as String?,
      createdAt: createdAt,
      createdBy: (m['createdBy'] ?? '') as String,
    );
  }
}