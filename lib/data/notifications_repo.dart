import 'dart:io' show Platform;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationsRepo {
  final _db = FirebaseFirestore.instance;
  final _msg = FirebaseMessaging.instance;

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

  // ────────────────────────────────
  //  NEW: In-App "New Expense" Alert
  // ────────────────────────────────

  /// Called when user opens the group dashboard
  Future<void> markExpenseAsSeen(String groupId, String latestTxId, String uid) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('seenExpenses')
        .doc(groupId)
        .set({'latestSeenTxId': latestTxId}, SetOptions(merge: true));
  }

  /// Check if there are new expenses user hasn't seen yet
  Future<bool> hasUnseenExpenses(String groupId, String latestTxId, String uid) async {
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
    print('Has unseen for $groupId: $hasUnseen (lastSeen: $lastSeen, latest: $latestTxId)');

    return hasUnseen;
  }
}