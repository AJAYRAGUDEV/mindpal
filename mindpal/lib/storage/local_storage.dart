/// The contract for "somewhere I can keep data on this device".
///
/// This is the most important file in the project for future flexibility.
/// Nothing above this layer knows whether we use SharedPreferences, SQLite,
/// or a plain file. On Day 3, if reminders outgrow SharedPreferences, we write
/// a new class that implements LocalStorage and change ONE line in main.dart.
///
/// Note the read is synchronous but writes are async: SharedPreferences keeps
/// an in-memory copy after loading, so reading is instant.
abstract class LocalStorage {
  /// Must be awaited once, at startup, before any read or write.
  Future<void> init();

  /// Returns null when the key has never been written.
  String? readString(String key);

  Future<void> writeString(String key, String value);

  Future<void> remove(String key);
}

/// A storage that forgets everything when the app closes.
///
/// Used as a safety net: if real storage fails to open on a device, the app
/// still runs for this session instead of showing a dead screen. It is also
/// handy for widget tests, which should not touch the real disk.
class InMemoryStorage implements LocalStorage {
  final Map<String, String> _values = {};

  @override
  Future<void> init() async {}

  @override
  String? readString(String key) => _values[key];

  @override
  Future<void> writeString(String key, String value) async {
    _values[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    _values.remove(key);
  }
}
