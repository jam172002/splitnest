import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/firestore_paths.dart';
import '../domain/models/personal_tx.dart';

class PersonalRepo {
  final _db = FirebaseFirestore.instance;

  Stream<List<PersonalTx>> watchPersonal(String uid) {
    return _db
        .doc('${FirestorePaths.users}/$uid')
        .collection('personalTx')
        .orderBy('at', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => PersonalTx.fromMap(d.id, d.data())).toList());
  }

  Future<void> addPersonal({
    required String uid,
    required double amount,
    required String title,
    required DateTime at,
  }) async {
    final ref = _db
        .doc('${FirestorePaths.users}/$uid')
        .collection('personalTx')
        .doc();
    await ref.set(PersonalTx(id: ref.id, amount: amount, title: title, at: at).toMap());
  }
}
