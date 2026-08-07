import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class PersonalLockController extends ChangeNotifier {
  static const _pinKey = 'personal_lock_pin';
  static const _enabledKey = 'personal_lock_enabled';
  static const _biometricKey = 'personal_lock_biometric';
  static const _durationKey = 'personal_lock_duration_seconds';
  static const _storage = FlutterSecureStorage();

  final LocalAuthentication _auth = LocalAuthentication();
  DateTime? _unlockedUntil;
  Timer? _timer;

  bool isInitialized = false;
  bool isEnabled = false;
  bool useBiometric = true;
  Duration lockDuration = const Duration(minutes: 1);

  PersonalLockController() {
    _loadSettings();
  }

  bool get isUnlocked =>
      !isEnabled ||
      (_unlockedUntil != null && DateTime.now().isBefore(_unlockedUntil!));

  bool get isLocked => isEnabled && !isUnlocked;

  Future<void> _loadSettings() async {
    final enabled = await _storage.read(key: _enabledKey);
    final biometric = await _storage.read(key: _biometricKey);
    final seconds = int.tryParse(
      await _storage.read(key: _durationKey) ?? '',
    );

    isEnabled = enabled == 'true';
    useBiometric = biometric != 'false';
    if (seconds != null && seconds >= 10) {
      lockDuration = Duration(seconds: seconds);
    }
    isInitialized = true;
    notifyListeners();
  }

  Future<void> setEnabled(bool enabled) async {
    isEnabled = enabled;
    await _storage.write(key: _enabledKey, value: '$enabled');
    if (enabled) {
      lockNow();
    } else {
      _unlockedUntil = null;
      _timer?.cancel();
      notifyListeners();
    }
  }

  Future<void> setUseBiometric(bool enabled) async {
    useBiometric = enabled;
    await _storage.write(key: _biometricKey, value: '$enabled');
    notifyListeners();
  }

  Future<void> setLockDuration(Duration duration) async {
    lockDuration = duration;
    await _storage.write(
      key: _durationKey,
      value: '${duration.inSeconds}',
    );
    if (isUnlocked && isEnabled) unlockFor(duration);
    notifyListeners();
  }

  void bumpInactivity() {
    if (!isEnabled || isLocked) return;
    _unlockedUntil = DateTime.now().add(lockDuration);
    _timer?.cancel();
    _timer = Timer(lockDuration, lockNow);
  }

  void unlockFor(Duration duration) {
    if (!isEnabled) return;
    _unlockedUntil = DateTime.now().add(duration);
    _timer?.cancel();
    _timer = Timer(duration, lockNow);
    notifyListeners();
  }

  void lockNow() {
    if (!isEnabled) return;
    _unlockedUntil = null;
    _timer?.cancel();
    notifyListeners();
  }

  Future<bool> hasPin() async {
    final pin = await _storage.read(key: _pinKey);
    return pin != null && pin.trim().isNotEmpty;
  }

  Future<void> setPin(String pin) async {
    await _storage.write(key: _pinKey, value: pin.trim());
  }

  Future<void> removePin() async {
    await _storage.delete(key: _pinKey);
  }

  Future<bool> verifyPin(String pin) async {
    final saved = await _storage.read(key: _pinKey);
    return saved != null && saved == pin.trim();
  }

  Future<bool> canBiometric() async {
    try {
      final supported = await _auth.isDeviceSupported();
      if (!supported) return false;
      return (await _auth.getAvailableBiometrics()).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authBiometric() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Unlock Personal Expenses',
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
