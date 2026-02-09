import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class PersonalLockController extends ChangeNotifier {
  static const _pinKey = 'personal_lock_pin';
  static const _storage = FlutterSecureStorage();

  Duration lockDuration = const Duration(seconds: 10);
  final LocalAuthentication _auth = LocalAuthentication();
  DateTime? _unlockedUntil;
  Timer? _timer;

  bool get isUnlocked =>
      _unlockedUntil != null && DateTime.now().isBefore(_unlockedUntil!);

  bool get isLocked => !isUnlocked;

  /// Call this whenever the user interacts with the Personal tab.
  /// It extends the unlock window by [lockDuration] from *now*.
  void bumpInactivity() {
    if (isLocked) return; // don't bump when already locked
    _unlockedUntil = DateTime.now().add(lockDuration);
    _timer?.cancel();
    _timer = Timer(lockDuration, () {
      notifyListeners(); // show overlay after inactivity duration
    });
    // no need to notify every tap; but ok if you want
    // notifyListeners();
  }

  void unlockFor(Duration d) {
    _unlockedUntil = DateTime.now().add(d);
    _timer?.cancel();
    _timer = Timer(d, () {
      notifyListeners();
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

      final biometrics = await _auth.getAvailableBiometrics();
      return biometrics.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authBiometric() async {
    try {
      // This shows Fingerprint OR Face ID depending on device,
      // and may allow device PIN/pattern fallback automatically.
      return await _auth.authenticate(
        localizedReason: 'Unlock Personal tab',
      );
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