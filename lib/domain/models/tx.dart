// domain/models/tx.dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum TxStatus { pending, approved, rejected }

class PayerPortion {
  final String uid;
  final double amount;

  const PayerPortion({required this.uid, required this.amount});

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'amount': amount,
  };

  factory PayerPortion.fromMap(Map<String, dynamic> m) => PayerPortion(
    uid: (m['uid'] ?? '') as String,
    amount: ((m['amount'] ?? 0) as num).toDouble(),
  );
}

class GroupTx {
  final String id;

  /// expense | income | settlement | bill_instance
  final String type;

  final double amount;
  final String? category;
  final String? description;

  /// Old legacy single payer (kept for backwards compatibility)
  final String? paidBy;

  /// NEW: multi-payer support
  final List<PayerPortion> payers;

  /// Participants for expense/bill splitting
  final List<String> participants;

  /// NEW: Unequal split (uid -> amount owed). If null/empty => equal split.
  final Map<String, double> participantShares;

  /// NEW: for business income distribution (uid -> amount)
  final Map<String, double> distributeTo;

  /// settlement fields
  final String? fromUid;
  final String? toUid;

  final DateTime at;

  final TxStatus status;
  final List<String> endorsedBy;
  final String createdBy;

  GroupTx({
    required this.id,
    required this.type,
    required this.amount,
    required this.at,
    required this.createdBy,
    this.category,
    this.description,
    this.paidBy,
    this.payers = const [],
    this.participants = const [],
    Map<String, double> participantShares = const {},
    this.distributeTo = const {},
    this.fromUid,
    this.toUid,
    this.status = TxStatus.approved,
    this.endorsedBy = const [],
  }) : participantShares = participantShares;

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'amount': amount,
      if (category != null) 'category': category,
      if (description != null) 'description': description,

      // Legacy payer (optional)
      if (paidBy != null) 'paidBy': paidBy,

      // Multi payer
      if (payers.isNotEmpty) 'payers': payers.map((e) => e.toMap()).toList(),

      // Participants
      if (participants.isNotEmpty) 'participants': participants,

      // Unequal split (only store if not empty)
      if (participantShares.isNotEmpty) 'participantShares': participantShares,

      // Income distribution
      if (distributeTo.isNotEmpty) 'distributeTo': distributeTo,

      // Settlement
      if (fromUid != null) 'fromUid': fromUid,
      if (toUid != null) 'toUid': toUid,

      'at': at.toIso8601String(),
      'status': status.name,
      'endorsedBy': endorsedBy,
      'createdBy': createdBy,
    };
  }

  factory GroupTx.fromMap(String id, Map<String, dynamic> m) {
    // at
    final atRaw = m['at'];
    DateTime at;
    if (atRaw is Timestamp) {
      at = atRaw.toDate();
    } else {
      at = DateTime.tryParse((atRaw ?? '') as String) ?? DateTime.now();
    }

    // participants
    final participants =
        (m['participants'] as List?)?.map((e) => e.toString()).toList() ?? const <String>[];

    // payers (new) OR fallback to paidBy (legacy)
    final payersRaw = m['payers'];
    List<PayerPortion> payers = [];
    if (payersRaw is List) {
      payers = payersRaw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .map(PayerPortion.fromMap)
          .toList();
    }

    final paidBy = (m['paidBy'] ?? '') as String?;
    if (payers.isEmpty && paidBy != null && paidBy.trim().isNotEmpty) {
      // Legacy: single payer paid full amount
      final amt = ((m['amount'] ?? 0) as num).toDouble();
      payers = [PayerPortion(uid: paidBy, amount: amt)];
    }

    // participantShares (unequal split)
    final sharesRaw = m['participantShares'];
    final participantShares = <String, double>{};
    if (sharesRaw is Map) {
      sharesRaw.forEach((k, v) {
        participantShares[k.toString()] = ((v ?? 0) as num).toDouble();
      });
    }

    // distributeTo (income distribution)
    final distRaw = m['distributeTo'];
    final distributeTo = <String, double>{};
    if (distRaw is Map) {
      distRaw.forEach((k, v) {
        distributeTo[k.toString()] = ((v ?? 0) as num).toDouble();
      });
    }

    return GroupTx(
      id: id,
      type: (m['type'] ?? 'expense') as String,
      amount: ((m['amount'] ?? 0) as num).toDouble(),
      category: m['category'] as String?,
      description: m['description'] as String?,
      paidBy: paidBy,
      payers: payers,
      participants: participants,
      participantShares: participantShares,
      distributeTo: distributeTo,
      fromUid: m['fromUid'] as String?,
      toUid: m['toUid'] as String?,
      at: at,
      status: TxStatus.values.firstWhere(
            (e) => e.name == (m['status'] ?? TxStatus.approved.name),
        orElse: () => TxStatus.approved,
      ),
      endorsedBy: (m['endorsedBy'] as List?)?.map((e) => e.toString()).toList() ?? const <String>[],
      createdBy: (m['createdBy'] ?? '') as String,
    );
  }

  /// Helper: get share for a user (unequal if present, else equal)
  double shareFor(String uid) {
    if (participantShares.isNotEmpty) {
      return participantShares[uid] ?? 0.0;
    }
    if (!participants.contains(uid) || participants.isEmpty) return 0.0;
    return amount / participants.length;
  }
}