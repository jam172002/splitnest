import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/firestore_paths.dart';
import '../domain/models/group.dart';
import '../domain/models/group_member.dart';
import '../domain/models/member_balance.dart';
import '../domain/models/tx.dart';

class GroupRepo {
  final _db = FirebaseFirestore.instance;

  // ────────────────────────────────────────────────
  // Groups – My groups & single group
  // ────────────────────────────────────────────────

  Stream<List<Group>> watchMyGroups(String uid) {
    return _db
        .collection(FirestorePaths.groups)
        .where('memberUids', arrayContains: uid)
        .snapshots()
        .map((s) => s.docs.map((d) => Group.fromMap(d.id, d.data())).toList());
  }

  Stream<Group> watchGroup(String groupId) {
    return _db
        .collection(FirestorePaths.groups)
        .doc(groupId)
        .snapshots()
        .map((d) => Group.fromMap(d.id, d.data() ?? {}));
  }

  Future<String> createGroup({
    required String name,
    required String uid,
    required String email,
    bool requireApproval = true,
    bool adminBypass = true,
    String approvalMode = 'any', // 'any' | 'all' | 'admin_only'
  }) async {
    final ref = _db.collection(FirestorePaths.groups).doc();
    final group = Group(
      id: ref.id,
      name: name,
      createdBy: uid,
      memberUids: [uid], // ADD THIS LINE: Initialize with the creator's UID
      requireApproval: requireApproval,
      adminBypass: adminBypass,
      approvalMode: approvalMode,
    );

    await _db.runTransaction((tx) async {
      tx.set(ref, {
        ...group.toMap(),
        'memberUids': [uid],
        'createdAt': FieldValue.serverTimestamp(),
      });

      tx.set(
        ref.collection('members').doc(uid),
        GroupMember(
          id: uid,
          name: email.split('@')[0], // fallback name from email
          role: 'admin',
          joinedAt: DateTime.now(),
        ).toMap(),
      );
    });

    // Seed default categories
    final defaultCats = ['breakfast', 'lunch', 'dinner', 'tea', 'milk', 'snacks', 'transport', 'other'];
    final batch = _db.batch();
    for (final cat in defaultCats) {
      final catRef = ref.collection('categories').doc();
      batch.set(catRef, {
        'name': cat,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();

    return ref.id;
  }

  Future<void> joinGroup({
    required String groupId,
    required String uid,
    required String email,
  }) async {
    final groupRef = _db.collection(FirestorePaths.groups).doc(groupId);
    final groupSnap = await groupRef.get();

    if (!groupSnap.exists) {
      throw Exception('Group not found. Please check the invite code.');
    }

    await _db.runTransaction((tx) async {
      tx.set(
        groupRef.collection('members').doc(uid),
        GroupMember(
          id: uid,
          name: email.split('@')[0], // fallback name
          role: 'member',
          joinedAt: DateTime.now(),
        ).toMap(),
      );

      tx.update(groupRef, {
        'memberUids': FieldValue.arrayUnion([uid]),
      });
    });
  }

  // ────────────────────────────────────────────────
  // Members – name-only support + classic UID
  // ────────────────────────────────────────────────

  Stream<List<GroupMember>> watchMembers(String groupId) {
    return _db
        .collection(FirestorePaths.groups)
        .doc(groupId)
        .collection('members')
        .snapshots()
        .map((s) => s.docs.map((d) => GroupMember.fromMap(
      id: d.id,
      map: d.data(),
    )).toList());
  }

  Future<String> roleOf(String groupId, String uid) async {
    final ref = _db
        .collection(FirestorePaths.groups)
        .doc(groupId)
        .collection('members')
        .doc(uid);

    final snap = await ref.get();
    return snap.data()?['role'] as String? ?? 'member';
  }

  Future<void> addMemberByName({
    required String groupId,
    required String name,
    String role = 'member',
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    // Simple ID from name – good enough for small private group
    final memberId = trimmed
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');

    if (memberId.isEmpty) return;

    final ref = _db
        .collection(FirestorePaths.groups)
        .doc(groupId)
        .collection('members')
        .doc(memberId);

    // Prevent overwriting existing member
    final doc = await ref.get();
    if (doc.exists) return;

    await ref.set({
      'name': trimmed,
      'role': role,
      'joinedAt': FieldValue.serverTimestamp(),
    });

    // Optional: keep memberUids updated
    await _db.collection(FirestorePaths.groups).doc(groupId).update({
      'memberUids': FieldValue.arrayUnion([memberId]),
    });
  }

  // ────────────────────────────────────────────────
  // Categories
  // ────────────────────────────────────────────────

  Stream<List<String>> watchCategories(String groupId) {
    return _db
        .collection(FirestorePaths.groups)
        .doc(groupId)
        .collection('categories')
        .snapshots()
        .map((s) => s.docs.map((d) => d.data()['name'] as String? ?? '').where((e) => e.isNotEmpty).toList());
  }

  Stream<List<Map<String, dynamic>>> watchCategoryDocs(String groupId) {
    return _db
        .collection(FirestorePaths.groups)
        .doc(groupId)
        .collection('categories')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
      return {
        'id': doc.id,
        ...doc.data(),
      };
    }).toList());
  }

  Future<void> addCategory(String groupId, String name) async {
    final trimmed = name.trim().toLowerCase();
    if (trimmed.isEmpty) return;

    await _db
        .collection(FirestorePaths.groups)
        .doc(groupId)
        .collection('categories')
        .add({
      'name': trimmed,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteCategory(String groupId, String catId) async {
    await _db
        .collection(FirestorePaths.groups)
        .doc(groupId)
        .collection('categories')
        .doc(catId)
        .delete();
  }

  // ────────────────────────────────────────────────
  // Transactions (Expenses + Settlements)
  // ────────────────────────────────────────────────

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

  Future<void> addExpense({
    required String groupId,
    required Group group,
    required double amount,
    required String category,
    required String paidBy,
    required List<String> participants,
    String? description,
    required DateTime at,
    required String createdBy,
    required bool isAdmin,
  }) async {
    if (amount <= 0) throw Exception('Amount must be greater than 0');
    if (participants.isEmpty) throw Exception('At least one participant is required');

    final status = (isAdmin && group.adminBypass)
        ? TxStatus.approved
        : (group.requireApproval ? TxStatus.pending : TxStatus.approved);

    final ref = _db
        .collection(FirestorePaths.groups)
        .doc(groupId)
        .collection('tx')
        .doc();

    final tx = GroupTx(
      id: ref.id,
      type: 'expense',
      amount: amount,
      category: category,
      paidBy: paidBy,
      participants: participants,
      description: description?.trim().isNotEmpty == true ? description!.trim() : null,
      at: at,
      status: status,
      endorsedBy: status == TxStatus.approved ? [createdBy] : [],
      createdBy: createdBy,
    );

    await ref.set(tx.toMap());
  }

  Future<void> addSettlement({
    required String groupId,
    required double amount,
    required String fromUid,
    required String toUid,
    String? description,
    required String createdBy,
  }) async {
    if (amount <= 0) throw Exception('Settlement amount must be greater than 0');
    if (fromUid == toUid) throw Exception('Cannot settle to the same person');

    final ref = _db
        .collection(FirestorePaths.groups)
        .doc(groupId)
        .collection('tx')
        .doc();

    final tx = GroupTx(
      id: ref.id,
      type: 'settlement',
      amount: amount,
      fromUid: fromUid,
      toUid: toUid,
      description: description?.trim().isNotEmpty == true ? description!.trim() : null,
      at: DateTime.now(),
      status: TxStatus.approved,
      endorsedBy: [createdBy],
      createdBy: createdBy,
    );

    await ref.set(tx.toMap());
  }

  Future<void> endorseExpense({
    required String groupId,
    required String txId,
    required String uid,
    required Group group,
    required bool isAdmin,
  }) async {
    final txRef = _db
        .collection(FirestorePaths.groups)
        .doc(groupId)
        .collection('tx')
        .doc(txId);

    await _db.runTransaction((t) async {
      final snap = await t.get(txRef);
      if (!snap.exists) return;

      final current = GroupTx.fromMap(snap.id, snap.data()!);
      if (current.status != TxStatus.pending) return;
      if (current.type != 'expense') return;

      if (group.approvalMode == 'admin_only' && !isAdmin) {
        throw Exception('Only admins can approve in this group.');
      }

      final endorsed = {...current.endorsedBy, uid}.toList();

      bool shouldApprove = false;
      switch (group.approvalMode) {
        case 'any':
          shouldApprove = endorsed.isNotEmpty;
          break;
        case 'all':
          final participantsSet = current.participants.toSet();
          shouldApprove = participantsSet.isNotEmpty &&
              participantsSet.difference(endorsed.toSet()).isEmpty;
          break;
        case 'admin_only':
          shouldApprove = isAdmin;
          break;
      }

      t.update(txRef, {
        'endorsedBy': endorsed,
        'status': shouldApprove ? TxStatus.approved.name : TxStatus.pending.name,
      });
    });
  }

  Future<void> rejectExpense({
    required String groupId,
    required String txId,
  }) async {
    await _db
        .collection(FirestorePaths.groups)
        .doc(groupId)
        .collection('tx')
        .doc(txId)
        .update({'status': TxStatus.rejected.name});
  }

  // ────────────────────────────────────────────────
  // Group Settings
  // ────────────────────────────────────────────────

  Future<void> updateApprovalSettings({
    required String groupId,
    required bool requireApproval,
    required bool adminBypass,
    required String approvalMode,
  }) async {
    await _db.collection(FirestorePaths.groups).doc(groupId).update({
      'requireApproval': requireApproval,
      'adminBypass': adminBypass,
      'approvalMode': approvalMode,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ────────────────────────────────────────────────
  // Balance Calculations – for GroupBalancesScreen
  // ────────────────────────────────────────────────

  Future<Map<String, double>> calculateMemberBalances(String groupId) async {
    final txSnapshot = await _db
        .collection(FirestorePaths.groups)
        .doc(groupId)
        .collection('tx')
        .where('type', isEqualTo: 'expense')
        .get();

    final balances = <String, double>{};

    for (final doc in txSnapshot.docs) {
      final data = doc.data();
      final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
      final paidBy = data['paidBy'] as String?;
      final participants = (data['participants'] as List<dynamic>?)?.cast<String>() ?? [];

      if (amount <= 0 || paidBy == null || participants.isEmpty) continue;

      final sharePerPerson = amount / participants.length;

      balances.update(
        paidBy,
            (value) => value + amount,
        ifAbsent: () => amount,
      );

      for (final participant in participants) {
        balances.update(
          participant,
              (value) => value - sharePerPerson,
          ifAbsent: () => -sharePerPerson,
        );
      }
    }

    return balances;
  }


  Future<List<MemberBalance>> getMemberBalances(String groupId) async {
    final netBalances = await calculateMemberBalances(groupId);

    // Get all members to fetch names
    final membersSnapshot = await _db
        .collection(FirestorePaths.groups)
        .doc(groupId)
        .collection('members')
        .get();

    final memberMap = <String, String>{};
    for (final doc in membersSnapshot.docs) {
      final data = doc.data();
      final name = data['name'] as String? ?? 'Unknown';
      memberMap[doc.id] = name;
    }

    final result = <MemberBalance>[];
    for (final entry in netBalances.entries) {
      final memberId = entry.key;
      final name = memberMap[memberId] ?? 'Unknown';
      result.add(MemberBalance(
        memberId: memberId,
        name: name,
        netBalance: entry.value,
      ));
    }

    // Sort by who is owed the most → who owes the most
    result.sort((a, b) => b.netBalance.compareTo(a.netBalance));

    return result;
  }
  Future<void> removeMember(String groupId, String uid) async {
    final groupRef = _db.collection('groups').doc(groupId);
    final memberRef = groupRef.collection('members').doc(uid);

    final batch = _db.batch();

    // 1. Remove from the members sub-collection
    batch.delete(memberRef);

    // 2. Remove from the access array
    batch.update(groupRef, {
      'memberUids': FieldValue.arrayRemove([uid])
    });

    await batch.commit();
  }
  // ────────────────────────────────────────────────
  // Member Transaction Details (for detail screen)
  // ────────────────────────────────────────────────

  /// Returns all expenses where this member was the payer
  Future<List<GroupTx>> getExpensesPaidByMember(String groupId, String memberId) async {
    final snapshot = await _db
        .collection(FirestorePaths.groups)
        .doc(groupId)
        .collection('tx')
        .where('type', isEqualTo: 'expense')
        .where('paidBy', isEqualTo: memberId)
        .orderBy('at', descending: true)
        .get();

    return snapshot.docs.map((doc) => GroupTx.fromMap(doc.id, doc.data())).toList();
  }
  Future<void> addMember({
    required String groupId,
    required String name,
    required String role,
    required String uid,
  }) async {
    final groupRef = _db.collection('groups').doc(groupId);
    final memberRef = groupRef.collection('members').doc(uid);

    final batch = _db.batch();

    // 1. Add the member document
    batch.set(memberRef, {
      'name': name,
      'role': role,
      'joinedAt': FieldValue.serverTimestamp(),
    });

    // 2. IMPORTANT: Update the main group document's array
    // This fixes the "Invisible on restart" and "Member Count" bugs
    batch.update(groupRef, {
      'memberUids': FieldValue.arrayUnion([uid]), // This is what watchMyGroups looks for
    });

    await batch.commit();
  }

  /// Returns all expenses where this member was a participant (they owe a share)
  Future<List<GroupTx>> getExpensesParticipatedByMember(String groupId, String memberId) async {
    final snapshot = await _db
        .collection(FirestorePaths.groups)
        .doc(groupId)
        .collection('tx')
        .where('type', isEqualTo: 'expense')
        .where('participants', arrayContains: memberId)
        .orderBy('at', descending: true)
        .get();

    return snapshot.docs.map((doc) => GroupTx.fromMap(doc.id, doc.data())).toList();
  }
  // ────────────────────────────────────────────────
  // Delete Group (ADMIN ONLY)
  // ────────────────────────────────────────────────
  Future<void> deleteGroup(String groupId) async {
    final groupRef = _db.collection(FirestorePaths.groups).doc(groupId);

    Future<void> deleteSubcollection(String name) async {
      final snap = await groupRef.collection(name).get();
      for (final doc in snap.docs) {
        await doc.reference.delete();
      }
    }

    await deleteSubcollection('members');
    await deleteSubcollection('categories');
    await deleteSubcollection('tx');

    await groupRef.delete();
  }

}