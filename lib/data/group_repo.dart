import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/models/bill.dart';
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
    String approvalMode = 'any',
    String type = 'simple', // ✅ NEW
  }) async {
    final ref = _db.collection(FirestorePaths.groups).doc();
    final group = Group(
      id: ref.id,
      name: name,
      createdBy: uid,
      memberUids: [uid],
      requireApproval: requireApproval,
      adminBypass: adminBypass,
      approvalMode: approvalMode,
      type: type, // ✅ NEW
    );

    // Fetch creator's name from users collection
    final userDoc = await _db.collection('users').doc(uid).get();
    final creatorName = userDoc.data()?['name'] as String? ?? email.split('@')[0];

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
          name: creatorName,  // ← Now uses real name
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

    // Fetch user's name from users collection
    final userDoc = await _db.collection('users').doc(uid).get();
    final userName = userDoc.data()?['name'] as String? ?? email.split('@')[0];

    await _db.runTransaction((tx) async {
      tx.set(
        groupRef.collection('members').doc(uid),
        GroupMember(
          id: uid,
          name: userName,  // ← Now uses real name
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

    // legacy param (your current UI)
    required String paidBy,

    // NEW optional: multi-payer
    List<PayerPortion>? payers,

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

    // ✅ Backward compatible: if payers not provided, build from paidBy
    final finalPayers = (payers != null && payers.isNotEmpty)
        ? payers
        : [PayerPortion(uid: paidBy, amount: amount)];

    final tx = GroupTx(
      id: ref.id,
      type: 'expense',
      amount: amount,
      category: category,
      paidBy: paidBy, // keep legacy field
      payers: finalPayers,
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
        .get();

    final balances = <String, double>{};

    void add(String uid, double v) {
      if (uid.trim().isEmpty) return;
      balances.update(uid, (x) => x + v, ifAbsent: () => v);
    }

    for (final doc in txSnapshot.docs) {
      final tx = GroupTx.fromMap(doc.id, doc.data());

      // ✅ only approved affects balances
      if (tx.status != TxStatus.approved) continue;

      if (tx.type == 'expense' || tx.type == 'bill_instance') {
        if (tx.amount <= 0 || tx.participants.isEmpty) continue;

        // payers get credit
        for (final p in tx.payers) {
          if (p.amount > 0) add(p.uid, p.amount);
        }

        // participants share debit
        final share = tx.amount / tx.participants.length;
        for (final uid in tx.participants) {
          add(uid, -share);
        }
      }

      if (tx.type == 'income') {
        // distributed immediately (uid -> amount)
        tx.distributeTo.forEach((uid, amt) {
          if (amt > 0) add(uid, amt);
        });
      }

      if (tx.type == 'settlement') {
        if (tx.fromUid == null || tx.toUid == null) continue;
        if (tx.amount <= 0) continue;

        // from pays -> less debt => +amount
        add(tx.fromUid!, tx.amount);

        // to receives -> less credit => -amount
        add(tx.toUid!, -tx.amount);
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

  Future<List<GroupTx>> getExpensesPaidByMember(String groupId, String memberId) async {
    final snapshot = await _db
        .collection(FirestorePaths.groups)
        .doc(groupId)
        .collection('tx')
        .where('type', isEqualTo: 'expense')
        .orderBy('at', descending: true)
        .get();

    final all = snapshot.docs.map((d) => GroupTx.fromMap(d.id, d.data())).toList();

    //  include: legacy paidBy OR new payers list
    return all.where((tx) {
      if (tx.status != TxStatus.approved) return false;
      if (tx.paidBy == memberId) return true;
      return tx.payers.any((p) => p.uid == memberId && p.amount > 0);
    }).toList();
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
    batch.update(groupRef, {
      'memberUids': FieldValue.arrayUnion([uid]),
    });

    await batch.commit();
  }

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

  Future<void> resetGroupBalances(String groupId) async {
    final batch = FirebaseFirestore.instance.batch();

    // 1. Delete all transactions (expenses + settlements)
    final txSnapshot = await FirebaseFirestore.instance
        .collection('groups')
        .doc(groupId)
        .collection('tx')
        .get();

    for (var doc in txSnapshot.docs) {
      batch.delete(doc.reference);
    }

    // 2. Optional: reset any group-level summary fields
    batch.update(
      FirebaseFirestore.instance.collection('groups').doc(groupId),
      {
        'lastResetAt': FieldValue.serverTimestamp(),
      },
    );

    await batch.commit();
  }

  Future<void> addIncome({
    required String groupId,
    required Group group,
    required double amount,
    required Map<String, double> distributeTo, // uid -> amount (must sum to total)
    String? description,
    required DateTime at,
    required String createdBy,
    required bool isAdmin,
  }) async {
    if (group.type != 'business') {
      throw Exception('Income is only available in business groups.');
    }
    if (amount <= 0) throw Exception('Amount must be greater than 0');
    if (distributeTo.isEmpty) throw Exception('Select at least one member for distribution');

    final totalDist = distributeTo.values.fold<double>(0, (a, b) => a + b);
    // allow tiny rounding error
    if ((totalDist - amount).abs() > 0.01) {
      throw Exception('Distribution must equal total income.');
    }

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
      type: 'income',
      amount: amount,
      distributeTo: distributeTo,
      description: description?.trim().isNotEmpty == true ? description!.trim() : null,
      at: at,
      status: status,
      endorsedBy: status == TxStatus.approved ? [createdBy] : [],
      createdBy: createdBy,
    );

    await ref.set(tx.toMap());
  }



// inside GroupRepo class:

  CollectionReference<Map<String, dynamic>> _billsCol(String groupId) =>
      _db.collection(FirestorePaths.groups).doc(groupId).collection('bills');

  Stream<List<BillTemplate>> watchBills(String groupId) {
    return _billsCol(groupId)
        .orderBy('dueDay')
        .snapshots()
        .map((s) => s.docs.map((d) => BillTemplate.fromMap(d.id, d.data())).toList());
  }

  Future<String> addBill({
    required String groupId,
    required Group group,
    required String title,
    required double amount,
    required List<String> participants,
    required int dueDay,
    String? category,
    required String createdBy,
  }) async {
    if (group.type != 'business') throw Exception('Bills are only available in business groups.');
    if (title.trim().isEmpty) throw Exception('Enter bill title');
    if (amount <= 0) throw Exception('Amount must be greater than 0');
    if (participants.isEmpty) throw Exception('Select at least one participant');
    if (dueDay < 1 || dueDay > 28) throw Exception('Due day must be between 1 and 28');

    final ref = _billsCol(groupId).doc();
    final bill = BillTemplate(
      id: ref.id,
      title: title.trim(),
      amount: amount,
      interval: BillInterval.monthly,
      participants: participants,
      dueDay: dueDay,
      category: category?.trim().isNotEmpty == true ? category!.trim() : null,
      createdAt: DateTime.now(),
      createdBy: createdBy,
    );

    await ref.set(bill.toMap());
    return ref.id;
  }

  Future<void> updateBill({
    required String groupId,
    required String billId,
    String? title,
    double? amount,
    List<String>? participants,
    int? dueDay,
    String? category,
  }) async {
    final data = <String, dynamic>{};
    if (title != null) data['title'] = title.trim();
    if (amount != null) data['amount'] = amount;
    if (participants != null) data['participants'] = participants;
    if (dueDay != null) data['dueDay'] = dueDay;
    if (category != null) data['category'] = category.trim().isEmpty ? null : category.trim();

    await _billsCol(groupId).doc(billId).update(data);
  }

  Future<void> deleteBill({
    required String groupId,
    required String billId,
  }) async {
    await _billsCol(groupId).doc(billId).delete();
  }

  /// Create monthly bill_instance tx (idempotent per bill+month)
  Future<void> generateBillsForMonth({
    required String groupId,
    required Group group,
    required int year,
    required int month,
    required String createdBy,
    required bool isAdmin,
  }) async {
    if (group.type != 'business') throw Exception('Bills are only available in business groups.');

    final billsSnap = await _billsCol(groupId).get();
    final bills = billsSnap.docs.map((d) => BillTemplate.fromMap(d.id, d.data())).toList();

    if (bills.isEmpty) return;

    // existing bill instances for this month
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 1);

    final txSnap = await _db
        .collection(FirestorePaths.groups)
        .doc(groupId)
        .collection('tx')
        .where('type', isEqualTo: 'bill_instance')
        .get();

    // detect existing via billId + year/month stored
    final existingKeys = <String>{};
    for (final doc in txSnap.docs) {
      final m = doc.data();
      final bid = (m['billId'] ?? '') as String;
      final y = (m['billYear'] ?? 0) as int;
      final mo = (m['billMonth'] ?? 0) as int;
      if (bid.isNotEmpty && y == year && mo == month) {
        existingKeys.add('$bid-$year-$month');
      }
    }

    final status = (isAdmin && group.adminBypass)
        ? TxStatus.approved
        : (group.requireApproval ? TxStatus.pending : TxStatus.approved);

    final batch = _db.batch();
    for (final b in bills) {
      final key = '${b.id}-$year-$month';
      if (existingKeys.contains(key)) continue;

      final due = DateTime(year, month, b.dueDay);
      if (due.isBefore(start) || due.isAfter(end)) {
        // safe guard, usually not needed
      }

      final txRef = _db
          .collection(FirestorePaths.groups)
          .doc(groupId)
          .collection('tx')
          .doc();

      final tx = GroupTx(
        id: txRef.id,
        type: 'bill_instance',
        amount: b.amount,
        category: b.category ?? 'bill',
        description: b.title,
        participants: b.participants,
        payers: const [], // not paid yet (or can be paid later)
        at: due,
        status: status,
        endorsedBy: status == TxStatus.approved ? [createdBy] : [],
        createdBy: createdBy,
      ).toMap();

      batch.set(txRef, {
        ...tx,
        'billId': b.id,
        'billYear': year,
        'billMonth': month,
        'billTitle': b.title,
        'billDueDay': b.dueDay,
      });
    }

    await batch.commit();
  }

  /// Mark a bill instance as paid using payers (supports multi payer)
  Future<void> markBillInstancePaid({
    required String groupId,
    required String txId,
    required List<PayerPortion> payers,
  }) async {
    if (payers.isEmpty) throw Exception('Add at least one payer');
    final total = payers.fold<double>(0, (a, b) => a + b.amount);
    if (total <= 0) throw Exception('Invalid payer amounts');

    await _db
        .collection(FirestorePaths.groups)
        .doc(groupId)
        .collection('tx')
        .doc(txId)
        .update({
      'payers': payers.map((e) => e.toMap()).toList(),
    });
  }
}