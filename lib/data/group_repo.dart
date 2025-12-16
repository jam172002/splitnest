import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/firestore_paths.dart';
import '../domain/models/group.dart';
import '../domain/models/group_member.dart';
import '../domain/models/tx.dart';

class GroupRepo {
  final _db = FirebaseFirestore.instance;

  Stream<List<Group>> watchMyGroups(String uid) {
    // Query groups where a members/{uid} doc exists:
    // Firestore cannot query subcollections directly; we keep a mirror in groups with memberUids.
    return _db
        .collection(FirestorePaths.groups)
        .where('memberUids', arrayContains: uid)
        .snapshots()
        .map((s) => s.docs.map((d) => Group.fromMap(d.id, d.data())).toList());
  }

  Future<String> createGroup({
    required String name,
    required String uid,
    required String email,
    bool requireApproval = true,
    bool adminBypass = true,
  }) async {
    final ref = _db.collection(FirestorePaths.groups).doc();
    final group = Group(
      id: ref.id,
      name: name,
      createdBy: uid,
      requireApproval: requireApproval,
      adminBypass: adminBypass,
    );

    await _db.runTransaction((tx) async {
      tx.set(ref, {
        ...group.toMap(),
        'memberUids': [uid],
      });

      final memberRef = ref.collection('members').doc(uid);
      tx.set(
        memberRef,
        GroupMember(
          uid: uid,
          email: email,
          role: 'admin',
          joinedAt: DateTime.now(),
        ).toMap(),
      );
    });

    // Seed default categories (optional)
    final cats = ['breakfast', 'lunch', 'dinner', 'tea', 'milk'];
    final batch = _db.batch();
    for (final c in cats) {
      final cRef = ref.collection('categories').doc();
      batch.set(cRef, {'name': c});
    }
    await batch.commit();

    return ref.id;
  }

  Future<void> joinGroup({
    required String groupId,
    required String uid,
    required String email,
  }) async {
    final gRef = _db.collection(FirestorePaths.groups).doc(groupId);
    final gSnap = await gRef.get();
    if (!gSnap.exists) {
      throw Exception('Group not found. Check invite code.');
    }

    await _db.runTransaction((tx) async {
      tx.set(
        gRef.collection('members').doc(uid),
        GroupMember(
          uid: uid,
          email: email,
          role: 'member',
          joinedAt: DateTime.now(),
        ).toMap(),
      );

      tx.update(gRef, {
        'memberUids': FieldValue.arrayUnion([uid]),
      });
    });
  }

  Stream<List<GroupMember>> watchMembers(String groupId) {
    return _db
        .collection(FirestorePaths.groups)
        .doc(groupId)
        .collection('members')
        .snapshots()
        .map((s) => s.docs.map((d) => GroupMember.fromMap(d.data())).toList());
  }

  Stream<Group> watchGroup(String groupId) {
    return _db
        .collection(FirestorePaths.groups)
        .doc(groupId)
        .snapshots()
        .map((d) => Group.fromMap(d.id, d.data() ?? {}));
  }

  Stream<List<GroupTx>> watchTx(String groupId) {
    return _db
        .collection(FirestorePaths.groups)
        .doc(groupId)
        .collection('tx')
        .orderBy('at', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => GroupTx.fromMap(d.id, d.data())).toList());
  }

  Stream<List<GroupTx>> watchPending(String groupId) {
    return _db
        .collection(FirestorePaths.groups)
        .doc(groupId)
        .collection('tx')
        .where('status', isEqualTo: TxStatus.pending.name)
        .orderBy('at', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => GroupTx.fromMap(d.id, d.data())).toList());
  }

  Stream<List<String>> watchCategories(String groupId) {
    return _db
        .collection(FirestorePaths.groups)
        .doc(groupId)
        .collection('categories')
        .snapshots()
        .map((s) => s.docs.map((d) => (d.data()['name'] ?? '').toString()).where((e) => e.isNotEmpty).toList());
  }

  Future<void> addExpense({
    required String groupId,
    required double amount,
    required String category,
    required String paidBy,
    required List<String> participants,
    required DateTime at,
    required String createdBy,
    required bool requireApproval,
    required bool adminBypass,
    required bool isAdmin,
  }) async {
    final status = (isAdmin && adminBypass)
        ? TxStatus.approved
        : (requireApproval ? TxStatus.pending : TxStatus.approved);

    final ref = _db
        .collection(FirestorePaths.groups)
        .doc(groupId)
        .collection('tx')
        .doc();

    final txObj = GroupTx(
      id: ref.id,
      type: 'expense',
      amount: amount,
      category: category,
      paidBy: paidBy,
      participants: participants,
      at: at,
      status: status,
      endorsedBy: (status == TxStatus.approved) ? [createdBy] : [],
      createdBy: createdBy,
    );

    await ref.set(txObj.toMap());
  }

  Future<void> endorseExpense({
    required String groupId,
    required String txId,
    required String uid,
  }) async {
    final ref = _db
        .collection(FirestorePaths.groups)
        .doc(groupId)
        .collection('tx')
        .doc(txId);

    await _db.runTransaction((t) async {
      final snap = await t.get(ref);
      if (!snap.exists) return;
      final data = snap.data()!;
      final current = GroupTx.fromMap(snap.id, data);

      if (current.status != TxStatus.pending) return;

      final endorsed = {...current.endorsedBy, uid}.toList();

      // Approval rule (MVP): approve when ANY participant endorses (or creator endorses)
      // You can change to "all participants" later.
      final shouldApprove = endorsed.isNotEmpty;

      t.update(ref, {
        'endorsedBy': endorsed,
        'status': shouldApprove ? TxStatus.approved.name : TxStatus.pending.name,
      });
    });
  }

  Future<void> rejectExpense({
    required String groupId,
    required String txId,
  }) async {
    final ref = _db
        .collection(FirestorePaths.groups)
        .doc(groupId)
        .collection('tx')
        .doc(txId);

    await ref.update({'status': TxStatus.rejected.name});
  }

  Future<String> roleOf(String groupId, String uid) async {
    final ref = _db
        .collection(FirestorePaths.groups)
        .doc(groupId)
        .collection('members')
        .doc(uid);
    final s = await ref.get();
    return (s.data()?['role'] ?? 'member').toString();
  }
}
