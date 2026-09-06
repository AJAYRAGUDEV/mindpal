import 'package:shared_preferences/shared_preferences.dart';

import 'local_storage.dart';

/// The real implementation, backed by Android's SharedPreferences
/// (an XML file inside the app's private storage — fully offline).
class SharedPrefsStorage implements LocalStorage {
  SharedPreferences? _prefs;

  SharedPreferences get _requirePrefs {
    final prefs = _prefs;
    if (prefs == null) {
      throw StateError(
        'SharedPrefsStorage.init() must be awaited before reading or writing.',
      );
    }
    return prefs;
  }

  @override
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  @override
  String? readString(String key) => _requirePrefs.getString(key);

  @override
  Future<void> writeString(String key, String value) async {
    await _requirePrefs.setString(key, value);
  }

  @override
  Future<void> remove(String key) async {
    await _requirePrefs.remove(key);
  }
}
