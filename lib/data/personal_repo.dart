import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/firestore_paths.dart';
import '../domain/models/personal_tx.dart';

class PersonalRepo {
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String uid) {
    return _db
        .doc('${FirestorePaths.users}/$uid')
        .collection('personalTx');
  }

  Stream<List<PersonalTx>> watchPersonal(String uid) {
    return _col(uid)
        .orderBy('at', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => PersonalTx.fromMap(d.id, d.data())).toList());
  }

  /// Add any personal entry:
  /// - expense / income
  /// - loanTaken / loanGiven (principal)
  /// - loanPayment (against a loan via targetLoanId)
  Future<void> addPersonal({
    required String uid,
    required double amount,
    required String title,
    required DateTime at,
    PersonalTxType type = PersonalTxType.expense,
    String? counterparty,
    String? targetLoanId,
  }) async {
    final ref = _col(uid).doc();

    final tx = PersonalTx(
      id: ref.id,
      amount: amount,
      title: title,
      at: at,
      type: type,
      // keep loanId for principal entries (harmless for others)
      loanId: (type == PersonalTxType.loanGiven || type == PersonalTxType.loanTaken)
          ? ref.id
          : null,
      counterparty: (counterparty == null || counterparty.trim().isEmpty)
          ? null
          : counterparty.trim(),
      targetLoanId: (type == PersonalTxType.loanPayment)
          ? targetLoanId
          : null,
    );

    await ref.set(tx.toMap());
  }

  /// Helper: add a loan principal
  Future<String> addLoan({
    required String uid,
    required double amount,
    required String title,
    required DateTime at,
    required PersonalTxType type, // must be loanGiven or loanTaken
    String? counterparty,
  }) async {
    assert(type == PersonalTxType.loanGiven || type == PersonalTxType.loanTaken);

    final ref = _col(uid).doc();

    final tx = PersonalTx(
      id: ref.id,
      amount: amount,
      title: title,
      at: at,
      type: type,
      loanId: ref.id,
      counterparty: (counterparty == null || counterparty.trim().isEmpty)
          ? null
          : counterparty.trim(),
      targetLoanId: null,
    );

    await ref.set(tx.toMap());
    return ref.id;
  }

  /// Helper: add a payment against an existing loan (partial/full)
  /// Use this for:
  /// - paying your taken loan (cash-out)
  /// - receiving back your given loan (cash-in)
  Future<void> addLoanPayment({
    required String uid,
    required String targetLoanId,
    required double amount,
    String title = 'Loan Payment',
    DateTime? at,
  }) async {
    final ref = _col(uid).doc();

    final tx = PersonalTx(
      id: ref.id,
      amount: amount,
      title: title,
      at: at ?? DateTime.now(),
      type: PersonalTxType.loanPayment,
      loanId: null,
      counterparty: null,
      targetLoanId: targetLoanId,
    );

    await ref.set(tx.toMap());
  }
}