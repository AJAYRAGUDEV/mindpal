import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../storage/local_storage.dart';
import '../content/pongal_adventure.dart';
import '../engine/adventure_state.dart';
import '../model/adventure.dart';

/// One finished adventure, kept for My Progress.
///
/// A summary, not a replay: what was played, how it ended, and the plain counts.
/// Deliberately no score, no rating and nothing that could be read as an
/// assessment of the person — the same rule the games follow.
class AdventureRun {
  const AdventureRun({
    required this.adventureId,
    required this.title,
    required this.endingId,
    required this.endingTitle,
    required this.finishedAt,
    this.decisions = const [],
    this.cluesFound = 0,
    this.wrongAccusations = 0,
    this.hintsUsed = 0,
    this.coinsLeft = 0,
    this.styleName = '',
  });

  final String adventureId;
  final String title;
  final String endingId;
  final String endingTitle;
  final DateTime finishedAt;

  /// The ids of the choices that shaped it.
  final List<String> decisions;

  final int cluesFound;
  final int wrongAccusations;
  final int hintsUsed;
  final int coinsLeft;
  final String styleName;

  Map<String, dynamic> toMap() => {
    'adventureId': adventureId,
    'title': title,
    'endingId': endingId,
    'endingTitle': endingTitle,
    'finishedAt': finishedAt.toIso8601String(),
    'decisions': decisions,
    'cluesFound': cluesFound,
    'wrongAccusations': wrongAccusations,
    'hintsUsed': hintsUsed,
    'coinsLeft': coinsLeft,
    'styleName': styleName,
  };

  factory AdventureRun.fromMap(Map<String, dynamic> map) => AdventureRun(
    adventureId: map['adventureId'] as String? ?? '',
    title: map['title'] as String? ?? '',
    endingId: map['endingId'] as String? ?? '',
    endingTitle: map['endingTitle'] as String? ?? '',
    finishedAt:
        DateTime.tryParse(map['finishedAt'] as String? ?? '') ?? DateTime.now(),
    decisions: [
      for (final value in (map['decisions'] as List? ?? const []))
        if (value is String) value,
    ],
    cluesFound: (map['cluesFound'] as num?)?.toInt() ?? 0,
    wrongAccusations: (map['wrongAccusations'] as num?)?.toInt() ?? 0,
    hintsUsed: (map['hintsUsed'] as num?)?.toInt() ?? 0,
    coinsLeft: (map['coinsLeft'] as num?)?.toInt() ?? 0,
    styleName: map['styleName'] as String? ?? '',
  );
}

/// Where adventures and playthroughs live on the device.
///
/// **Everything here is local.** The bundled adventure is compiled in and needs
/// no storage at all; a generated one is written out in full the moment it
/// arrives, so it can be replayed with no connection afterwards. Progress is
/// saved after every action, because an app for people with memory difficulty
/// must never punish somebody for closing it at the wrong moment.
///
/// Uses the project's existing [LocalStorage], so it works on Android and in
/// the browser with no new mechanism.
class AdventureStore {
  AdventureStore(this._storage);

  final LocalStorage _storage;

  static const String _libraryKey = 'adventure_library_v1';
  static const String _progressKey = 'adventure_progress_v1';
  static const String _runsKey = 'adventure_runs_v1';
  static const String _currentKey = 'adventure_current_v1';

  /// How many generated adventures to keep. They are a few tens of kilobytes
  /// each and this is one string in SharedPreferences, so the list is capped
  /// rather than left to grow for ever.
  static const int _maxSaved = 6;

  /// Every adventure that can be played right now: the bundled one first,
  /// then whatever has been generated and saved, newest first.
  ///
  /// The bundled adventure is always present and always playable, which is what
  /// makes "offline" a promise rather than a hope.
  List<Adventure> library() => [kPongalAdventure, ..._savedAdventures()];

  Adventure? byId(String id) {
    if (id == kPongalAdventure.id) return kPongalAdventure;
    return _savedAdventures().where((a) => a.id == id).firstOrNull;
  }

  List<Adventure> _savedAdventures() {
    final raw = _storage.readString(_libraryKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return [
        for (final entry in decoded)
          if (entry is Map<String, dynamic>) Adventure.fromMap(entry),
      ];
    } catch (error, stackTrace) {
      // Bad saved data must never stop the app opening. The bundled adventure
      // is still there, so the player loses nothing they cannot get back.
      debugPrint('Could not read the adventure library: $error\n$stackTrace');
      return const [];
    }
  }

  /// Saves a generated adventure, newest first, trimming the oldest away.
  Future<void> saveAdventure(Adventure adventure) async {
    final existing = _savedAdventures()
        .where((saved) => saved.id != adventure.id)
        .toList();
    final updated = [adventure, ...existing].take(_maxSaved).toList();
    await _writeLibrary(updated);
  }

  Future<void> deleteAdventure(String id) async {
    await _writeLibrary(
      _savedAdventures().where((saved) => saved.id != id).toList(),
    );
    await clearProgress(id);
  }

  Future<void> _writeLibrary(List<Adventure> adventures) async {
    try {
      await _storage.writeString(
        _libraryKey,
        jsonEncode([for (final a in adventures) a.toMap()]),
      );
    } catch (error) {
      debugPrint('Could not save the adventure library: ${error.runtimeType}');
    }
  }

  // ------------------------------------------------------------- progress

  Map<String, AdventureState> _allProgress() {
    final raw = _storage.readString(_progressKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return {
        for (final entry in decoded.entries)
          if (entry.value is Map<String, dynamic>)
            entry.key: AdventureState.fromMap(
              entry.value as Map<String, dynamic>,
            ),
      };
    } catch (error) {
      debugPrint('Could not read saved progress: ${error.runtimeType}');
      return {};
    }
  }

  /// Where the player got to in one adventure, or null if they have not
  /// started it or have finished it.
  AdventureState? progressFor(String adventureId) =>
      _allProgress()[adventureId];

  /// The adventure to offer under "Continue".
  ({Adventure adventure, AdventureState state})? current() {
    final id = _storage.readString(_currentKey);
    if (id == null || id.isEmpty) return null;
    final adventure = byId(id);
    final state = progressFor(id);
    if (adventure == null || state == null || state.isFinished) return null;
    return (adventure: adventure, state: state);
  }

  /// Called after every action, so closing the app never loses anything.
  Future<void> saveProgress(AdventureState state) async {
    final all = _allProgress()..[state.adventureId] = state;
    await _writeProgress(all);
    try {
      await _storage.writeString(_currentKey, state.adventureId);
    } catch (_) {
      // The progress itself is saved; only the shortcut is lost.
    }
  }

  Future<void> clearProgress(String adventureId) async {
    final all = _allProgress()..remove(adventureId);
    await _writeProgress(all);
    if (_storage.readString(_currentKey) == adventureId) {
      await _storage.remove(_currentKey);
    }
  }

  Future<void> _writeProgress(Map<String, AdventureState> all) async {
    try {
      await _storage.writeString(
        _progressKey,
        jsonEncode({
          for (final entry in all.entries) entry.key: entry.value.toMap(),
        }),
      );
    } catch (error) {
      debugPrint('Could not save progress: ${error.runtimeType}');
    }
  }

  // ----------------------------------------------------------------- runs

  List<AdventureRun> runs() {
    final raw = _storage.readString(_runsKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      final all = [
        for (final entry in decoded)
          if (entry is Map<String, dynamic>) AdventureRun.fromMap(entry),
      ];
      return all..sort((a, b) => b.finishedAt.compareTo(a.finishedAt));
    } catch (error) {
      debugPrint('Could not read finished adventures: ${error.runtimeType}');
      return const [];
    }
  }

  /// Files a finished adventure and clears its progress, so "Continue" does
  /// not offer a game that is already over.
  Future<void> recordRun(Adventure adventure, AdventureState state) async {
    final ending = adventure.ending(state.endingId ?? '');
    final style = adventure.preparation.styles
        .where((candidate) => candidate.id == state.styleId)
        .firstOrNull;

    final run = AdventureRun(
      adventureId: adventure.id,
      title: adventure.title,
      endingId: ending?.id ?? '',
      endingTitle: ending?.title ?? '',
      finishedAt: DateTime.now(),
      decisions: state.decisions,
      cluesFound: state.clues.length,
      wrongAccusations: state.wrongAccusations,
      hintsUsed: state.hintsUsed,
      coinsLeft: state.coins,
      styleName: style?.name ?? '',
    );

    try {
      final updated = [run, ...runs()].take(100).toList();
      await _storage.writeString(
        _runsKey,
        jsonEncode([for (final entry in updated) entry.toMap()]),
      );
    } catch (error) {
      debugPrint('Could not file a finished adventure: ${error.runtimeType}');
    }

    await clearProgress(adventure.id);
  }

  /// Which endings the player has seen, across every run. Shown in My Progress
  /// as discoveries, and the reason to play again.
  Set<String> endingsSeenFor(String adventureId) => {
    for (final run in runs())
      if (run.adventureId == adventureId) run.endingId,
  };
}
