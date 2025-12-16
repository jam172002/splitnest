import 'dart:io' show Platform;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationsRepo {
  final _db = FirebaseFirestore.instance;
  final _msg = FirebaseMessaging.instance;

  Future<void> initAndSaveToken(String uid) async {
    // Web requires notification permission
    await _msg.requestPermission();

    // iOS needs APNS; Android ok; Web will return a token if configured
    final token = await _msg.getToken(
      vapidKey: null, // optional for web; if you use VAPID, put it here
    );

    if (token == null || token.isEmpty) return;

    await _db.doc('users/$uid/fcmTokens/$token').set({
      'token': token,
      'platform': _platform(),
      'updatedAt': DateTime.now().toIso8601String(),
    });

    // Keep token updated
    _msg.onTokenRefresh.listen((newToken) async {
      await _db.doc('users/$uid/fcmTokens/$newToken').set({
        'token': newToken,
        'platform': _platform(),
        'updatedAt': DateTime.now().toIso8601String(),
      });
    });
  }

  String _platform() {
    // Web won't have Platform.*
    try {
      if (Platform.isAndroid) return 'android';
      if (Platform.isIOS) return 'ios';
      if (Platform.isMacOS) return 'macos';
      if (Platform.isWindows) return 'windows';
      if (Platform.isLinux) return 'linux';
    } catch (_) {}
    return 'web';
  }
}
