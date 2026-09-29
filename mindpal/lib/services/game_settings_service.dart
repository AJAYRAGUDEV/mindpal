import 'package:flutter/foundation.dart';

import '../models/game_settings.dart';
import '../storage/local_storage.dart';

/// Reads and writes [GameSettings] through the project's existing storage.
///
/// Same shape as every other service here: it holds no state, takes what it
/// needs and returns the new value. One key, one small JSON object — no new
/// storage mechanism for a handful of switches.
class GameSettingsService {
  GameSettingsService(this._storage);

  final LocalStorage _storage;

  static const String _key = 'game_settings_v1';

  GameSettings load() {
    final raw = _storage.readString(_key);
    if (raw == null || raw.isEmpty) return GameSettings.defaults;
    return GameSettings.fromJson(raw);
  }

  /// Saves and returns what was saved, so a caller can do
  /// `setState(() => _settings = await service.save(next))`.
  ///
  /// A failed write is logged and swallowed. Losing a sound preference is not
  /// worth an error dialog in the middle of a game, and the setting still
  /// applies for this session.
  Future<GameSettings> save(GameSettings settings) async {
    try {
      await _storage.writeString(_key, settings.toJson());
    } catch (error) {
      debugPrint('Could not save game settings: ${error.runtimeType}');
    }
    return settings;
  }
}
