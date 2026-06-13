import 'package:cloud_firestore/cloud_firestore.dart';

class GroupNotification {
  final String id;
  final String groupId;
  final String groupName;
  final String txId;
  final String type;
  final String title;
  final String message;
  final String category;
  final String note;
  final double amount;
  final bool requiresAction;
  final bool isRead;
  final DateTime createdAt;

  const GroupNotification({
    required this.id,
    required this.groupId,
    required this.groupName,
    required this.txId,
    required this.type,
    required this.title,
    required this.message,
    required this.category,
    required this.note,
    required this.amount,
    required this.requiresAction,
    required this.isRead,
    required this.createdAt,
  });

  factory GroupNotification.fromMap(String id, Map<String, dynamic> map) {
    final rawDate = map['createdAt'];
    return GroupNotification(
      id: id,
      groupId: map['groupId'] as String? ?? '',
      groupName: map['groupName'] as String? ?? 'Group',
      txId: map['txId'] as String? ?? '',
      type: map['type'] as String? ?? 'expense_added',
      title: map['title'] as String? ?? 'SplitNest',
      message: map['message'] as String? ?? '',
      category: map['category'] as String? ?? 'expense',
      note: map['note'] as String? ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      requiresAction: map['requiresAction'] as bool? ?? false,
      isRead: map['isRead'] as bool? ?? false,
      createdAt: rawDate is Timestamp ? rawDate.toDate() : DateTime.now(),
    );
  }
}
