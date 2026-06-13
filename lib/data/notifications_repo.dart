import 'dart:io' show Platform;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../domain/models/group_notification.dart';

class NotificationsRepo {
  final _db = FirebaseFirestore.instance;
  final _msg = FirebaseMessaging.instance;

  void configureMessageNavigation(void Function(String path) navigate) {
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      final path = message.data['path'] as String?;
      if (path != null && path.isNotEmpty) navigate(path);
    });

    _msg.getInitialMessage().then((message) {
      final path = message?.data['path'] as String?;
      if (path != null && path.isNotEmpty) navigate(path);
    });
  }

  Future<void> initAndSaveToken(String uid) async {
    await _msg.requestPermission();
    final token = await _msg.getToken();

    if (token == null || token.isEmpty) return;

    await _db.doc('users/$uid/fcmTokens/$token').set({
      'token': token,
      'platform': _platform(),
      'updatedAt': DateTime.now().toIso8601String(),
    });

    _msg.onTokenRefresh.listen((newToken) async {
      await _db.doc('users/$uid/fcmTokens/$newToken').set({
        'token': newToken,
        'platform': _platform(),
        'updatedAt': DateTime.now().toIso8601String(),
      });
    });
  }

  String _platform() {
    try {
      if (Platform.isAndroid) return 'android';
      if (Platform.isIOS) return 'ios';
      if (Platform.isMacOS) return 'macos';
      if (Platform.isWindows) return 'windows';
      if (Platform.isLinux) return 'linux';
    } catch (_) {}
    return 'web';
  }

  Stream<List<GroupNotification>> watchNotifications(
    String uid, {
    String? groupId,
  }) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .limit(200)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => GroupNotification.fromMap(doc.id, doc.data()))
            .where((item) => groupId == null || item.groupId == groupId)
            .toList());
  }

  Future<void> markAsRead(String uid, String notificationId) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .doc(notificationId)
        .update({'isRead': true});
  }

  Future<void> markGroupAsRead(String uid, String groupId) async {
    final snapshot = await _db
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .where('groupId', isEqualTo: groupId)
        .get();
    final unread =
        snapshot.docs.where((doc) => doc.data()['isRead'] != true).toList();
    if (unread.isEmpty) return;
    final batch = _db.batch();
    for (final doc in unread) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  // ────────────────────────────────
  //  NEW: In-App "New Expense" Alert
  // ────────────────────────────────

  /// Called when user opens the group dashboard
  Future<void> markExpenseAsSeen(
      String groupId, String latestTxId, String uid) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('seenExpenses')
        .doc(groupId)
        .set({'latestSeenTxId': latestTxId}, SetOptions(merge: true));
  }

  /// Check if there are new expenses user hasn't seen yet
  Future<bool> hasUnseenExpenses(
      String groupId, String latestTxId, String uid) async {
    final doc = await _db
        .collection('users')
        .doc(uid)
        .collection('seenExpenses')
        .doc(groupId)
        .get();

    if (!doc.exists) {
      print('Has unseen for $groupId: true (no previous seen record)');
      return true; // first time → show banner
    }

    final lastSeen = doc.data()?['latestSeenTxId'] as String?;

    final hasUnseen = lastSeen != latestTxId;

    // ← PUT THE DEBUG PRINT RIGHT HERE
    print(
        'Has unseen for $groupId: $hasUnseen (lastSeen: $lastSeen, latest: $latestTxId)');

    return hasUnseen;
  }
}
