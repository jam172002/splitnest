import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

class ChatRepo {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String chatIdFor(String firstUid, String secondUid) {
    final ids = [firstUid, secondUid]..sort();
    return ids.join('_');
  }

  Future<String> ensurePublicId(String uid) async {
    final userRef = _db.collection('users').doc(uid);
    final current = await userRef.get();
    final existing = current.data()?['publicId'] as String?;
    if (existing != null && RegExp(r'^\d{10}$').hasMatch(existing)) {
      return existing;
    }

    final random = Random.secure();
    for (var attempt = 0; attempt < 20; attempt++) {
      final candidate = List.generate(
        10,
        (index) => index == 0 ? random.nextInt(9) + 1 : random.nextInt(10),
      ).join();
      final idRef = _db.collection('publicIds').doc(candidate);
      final reserved = await _db.runTransaction<bool>((transaction) async {
        final idSnapshot = await transaction.get(idRef);
        final userSnapshot = await transaction.get(userRef);
        final assigned = userSnapshot.data()?['publicId'] as String?;
        if (assigned != null && assigned.isNotEmpty) return true;
        if (idSnapshot.exists) return false;
        transaction.set(idRef, {'uid': uid});
        transaction.set(
            userRef, {'publicId': candidate}, SetOptions(merge: true));
        return true;
      });
      if (reserved) {
        final refreshed = await userRef.get();
        return refreshed.data()?['publicId'] as String? ?? candidate;
      }
    }
    throw Exception('Unable to create a unique ID. Please try again.');
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchUser(String uid) {
    return _db.collection('users').doc(uid).snapshots();
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?> findUserByPublicId(
    String publicId,
  ) async {
    final idSnapshot = await _db.collection('publicIds').doc(publicId).get();
    final uid = idSnapshot.data()?['uid'] as String?;
    if (uid == null) return null;
    final user = await _db.collection('users').doc(uid).get();
    return user.exists ? user : null;
  }

  Future<void> sendFriendRequest({
    required String fromUid,
    required String toUid,
  }) async {
    if (fromUid == toUid) throw Exception('You cannot add yourself');
    final friend = await _db.doc('users/$fromUid/friends/$toUid').get();
    if (friend.exists) throw Exception('You are already connected');

    final reverse = await _db.doc('friendRequests/${toUid}_$fromUid').get();
    if (reverse.data()?['status'] == 'pending') {
      throw Exception('This user already sent you a request');
    }

    final requestRef = _db.doc('friendRequests/${fromUid}_$toUid');
    final existing = await requestRef.get();
    if (existing.data()?['status'] == 'pending') {
      throw Exception('Friend request already sent');
    }

    final sender = await _db.collection('users').doc(fromUid).get();
    await requestRef.set({
      'fromUid': fromUid,
      'fromName': sender.data()?['name'] ?? 'User',
      'toUid': toUid,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchIncomingRequests(
    String uid,
  ) {
    return _db
        .collection('friendRequests')
        .where('toUid', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

  Future<void> respondToRequest({
    required String requestId,
    required String currentUid,
    required bool accept,
  }) async {
    final requestRef = _db.collection('friendRequests').doc(requestId);
    await _db.runTransaction((transaction) async {
      final requestSnapshot = await transaction.get(requestRef);
      final data = requestSnapshot.data();
      if (data == null || data['toUid'] != currentUid) {
        throw Exception('Friend request not found');
      }
      if (data['status'] != 'pending') {
        throw Exception('Friend request has already been handled');
      }

      final fromUid = data['fromUid'] as String;
      transaction.update(requestRef, {
        'status': accept ? 'accepted' : 'rejected',
        'respondedAt': FieldValue.serverTimestamp(),
      });
      if (!accept) return;

      final chatId = chatIdFor(fromUid, currentUid);
      transaction.set(_db.doc('users/$fromUid/friends/$currentUid'), {
        'uid': currentUid,
        'chatId': chatId,
        'createdAt': FieldValue.serverTimestamp(),
      });
      transaction.set(_db.doc('users/$currentUid/friends/$fromUid'), {
        'uid': fromUid,
        'chatId': chatId,
        'createdAt': FieldValue.serverTimestamp(),
      });
      transaction.set(
        _db.collection('chats').doc(chatId),
        {
          'memberUids': [fromUid, currentUid],
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchFriends(String uid) {
    return _db.collection('users').doc(uid).collection('friends').snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchMessages(String chatId) {
    return _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(200)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchLoanTransactions(
    String chatId,
  ) {
    return _db
        .collection('chats')
        .doc(chatId)
        .collection('loanTransactions')
        .orderBy('createdAt')
        .snapshots();
  }

  double loanBalanceFor(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> transactions,
    String uid,
  ) {
    double balance = 0;
    for (final transaction in transactions) {
      final data = transaction.data();
      final amount = (data['amount'] as num?)?.toDouble() ?? 0;
      if (data['type'] == 'loan') {
        if (data['lenderUid'] == uid) balance += amount;
        if (data['borrowerUid'] == uid) balance -= amount;
      } else if (data['type'] == 'repayment') {
        if (data['payerUid'] == uid) balance += amount;
        if (data['receiverUid'] == uid) balance -= amount;
      }
    }
    return balance;
  }

  Future<void> recordLoan({
    required String chatId,
    required String lenderUid,
    required String borrowerUid,
    required double amount,
  }) async {
    if (amount <= 0) throw Exception('Enter a valid amount');
    final chatRef = _db.collection('chats').doc(chatId);
    final chat = await chatRef.get();
    final members = List<String>.from(chat.data()?['memberUids'] ?? []);
    if (!members.contains(lenderUid) || !members.contains(borrowerUid)) {
      throw Exception('This conversation is not available');
    }
    final batch = _db.batch();
    final loanRef = chatRef.collection('loanTransactions').doc();
    final messageRef = chatRef.collection('messages').doc();
    final text = 'Gave a loan of PKR ${amount.toStringAsFixed(2)}';
    batch.set(loanRef, {
      'type': 'loan',
      'lenderUid': lenderUid,
      'borrowerUid': borrowerUid,
      'amount': amount,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(messageRef, {
      'senderUid': lenderUid,
      'text': text,
      'type': 'loan_given',
      'amount': amount,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(
      chatRef,
      {
        'lastMessage': text,
        'lastSenderUid': lenderUid,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  Future<void> recordLoanPayment({
    required String chatId,
    required String payerUid,
    required String receiverUid,
    required double amount,
  }) async {
    if (amount <= 0) throw Exception('Enter a valid amount');
    final loanSnapshot = await _db
        .collection('chats')
        .doc(chatId)
        .collection('loanTransactions')
        .orderBy('createdAt')
        .get();
    final payerBalance = loanBalanceFor(loanSnapshot.docs, payerUid);
    final outstanding = payerBalance < 0 ? -payerBalance : 0.0;
    if (outstanding <= 0.005) {
      throw Exception('You do not owe a loan to this user');
    }
    if (amount - outstanding > 0.01) {
      throw Exception(
        'Payment cannot exceed PKR ${outstanding.toStringAsFixed(2)}',
      );
    }

    final chatRef = _db.collection('chats').doc(chatId);
    final batch = _db.batch();
    final paymentRef = chatRef.collection('loanTransactions').doc();
    final messageRef = chatRef.collection('messages').doc();
    final text = 'Paid loan PKR ${amount.toStringAsFixed(2)}';
    batch.set(paymentRef, {
      'type': 'repayment',
      'payerUid': payerUid,
      'receiverUid': receiverUid,
      'amount': amount,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(messageRef, {
      'senderUid': payerUid,
      'text': text,
      'type': 'loan_paid',
      'amount': amount,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(
      chatRef,
      {
        'lastMessage': text,
        'lastSenderUid': payerUid,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  Future<void> sendMessage({
    required String chatId,
    required String senderUid,
    required String text,
    String type = 'text',
    double? amount,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final chatRef = _db.collection('chats').doc(chatId);
    final chatSnapshot = await chatRef.get();
    final members = List<String>.from(
      chatSnapshot.data()?['memberUids'] ?? const <String>[],
    );
    if (!chatSnapshot.exists || !members.contains(senderUid)) {
      throw Exception('You can only message accepted friends');
    }
    final messageRef = chatRef.collection('messages').doc();
    final batch = _db.batch();
    batch.set(messageRef, {
      'senderUid': senderUid,
      'text': trimmed,
      'type': type,
      if (amount != null) 'amount': amount,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(
      chatRef,
      {
        'lastMessage': trimmed,
        'lastSenderUid': senderUid,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  Future<void> sendGroupInvite({
    required String chatId,
    required String senderUid,
    required String groupId,
    required String groupName,
  }) async {
    final chatRef = _db.collection('chats').doc(chatId);
    final chatSnapshot = await chatRef.get();
    final members = List<String>.from(
      chatSnapshot.data()?['memberUids'] ?? const <String>[],
    );
    if (!chatSnapshot.exists || !members.contains(senderUid)) {
      throw Exception('You can only invite accepted friends');
    }
    final messageRef = chatRef.collection('messages').doc();
    final text = 'Invited you to join "$groupName"';
    final batch = _db.batch();
    batch.set(messageRef, {
      'senderUid': senderUid,
      'text': text,
      'type': 'group_invite',
      'groupId': groupId,
      'groupName': groupName,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(
      chatRef,
      {
        'lastMessage': text,
        'lastSenderUid': senderUid,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  Future<void> unfriend(String uid, String otherUid) async {
    final batch = _db.batch();
    batch.delete(_db.doc('users/$uid/friends/$otherUid'));
    batch.delete(_db.doc('users/$otherUid/friends/$uid'));
    await batch.commit();
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> mutualGroups(
    String firstUid,
    String secondUid,
  ) async {
    final snapshot = await _db
        .collection('groups')
        .where('memberUids', arrayContains: firstUid)
        .get();
    return snapshot.docs
        .where((doc) => List<String>.from(doc.data()['memberUids'] ?? [])
            .contains(secondUid))
        .toList();
  }
}
