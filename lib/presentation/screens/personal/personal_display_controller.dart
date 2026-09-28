import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists whether the single master hide/show button is available on the
/// Personal Ledger screen. When disabled, amounts are always shown and no
/// button is rendered.
class PersonalDisplayController extends ChangeNotifier {
  static const _masterHideEnabledKey = 'personal_master_hide_enabled';
  static const _storage = FlutterSecureStorage();

  bool isInitialized = false;
  bool masterHideEnabled = false;

  PersonalDisplayController() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final enabled = await _storage.read(key: _masterHideEnabledKey);
    masterHideEnabled = enabled == 'true';
    isInitialized = true;
    notifyListeners();
  }

  Future<void> setMasterHideEnabled(bool enabled) async {
    masterHideEnabled = enabled;
    await _storage.write(key: _masterHideEnabledKey, value: '$enabled');
    notifyListeners();
  }
}
