import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class PersonalLockController extends ChangeNotifier {
  static const _pinKey = 'personal_lock_pin';
  static const _storage = FlutterSecureStorage();

  final LocalAuthentication _auth = LocalAuthentication();

  DateTime? _unlockedUntil;
  Timer? _timer;

  Duration lockDuration = const Duration(seconds: 10);

  bool get isUnlocked =>
      _unlockedUntil != null && DateTime.now().isBefore(_unlockedUntil!);

  bool get isLocked => !isUnlocked;

  void unlockFor(Duration d) {
    _unlockedUntil = DateTime.now().add(d);
    _timer?.cancel();
    _timer = Timer(d, () {
      notifyListeners(); // triggers overlay to appear again
    });
    notifyListeners();
  }

  void lockNow() {
    _unlockedUntil = null;
    _timer?.cancel();
    notifyListeners();
  }

  // ---- PIN ----
  Future<bool> hasPin() async {
    final pin = await _storage.read(key: _pinKey);
    return pin != null && pin.trim().isNotEmpty;
  }

  Future<void> setPin(String pin) async {
    await _storage.write(key: _pinKey, value: pin.trim());
  }

  Future<bool> verifyPin(String pin) async {
    final saved = await _storage.read(key: _pinKey);
    return saved != null && saved == pin.trim();
  }

  // ---- BIOMETRIC ----
  Future<bool> canBiometric() async {
    try {
      final supported = await _auth.isDeviceSupported();
      if (!supported) return false;

      final available = await _auth.getAvailableBiometrics();
      return available.isNotEmpty;
    } catch (_) {
      return false;
    }
  }


  Future<bool> authBiometric() async {
    try {
      return await _auth.authenticate(localizedReason: 'Unlock Personal tab');
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}