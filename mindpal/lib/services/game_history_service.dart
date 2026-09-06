import '../models/game_result.dart';
import '../models/game_type.dart';
import '../storage/json_list_store.dart';
import '../storage/local_storage.dart';

/// Saved game results — the "Activity History".
///
/// A naming decision that matters: this is ACTIVITY history, not a cognitive
/// score, not a trend line, not a measure of anything medical. Scores here say
/// "you played and finished a game", nothing more. The app must never present
/// them as an assessment of the user's mind, and no code in this class tries
/// to interpret them.
class GameHistoryService {
  GameHistoryService(LocalStorage storage)
    : _store = JsonListStore<GameResult>(
        storage: storage,
        key: 'game_history_v1',
        label: 'activity',
        toMap: (result) => result.toMap(),
        fromMap: GameResult.fromMap,
      );

  final JsonListStore<GameResult> _store;

  /// Keeps storage from growing without limit. Everything is one JSON string
  /// in SharedPreferences, so an unbounded list would eventually get slow to
  /// read on every launch.
  static const int _maxEntries = 300;

  Future<List<GameResult>> loadAll() async {
    final results = await _store.loadAll();
    return _newestFirst(results);
  }

  /// Saves one finished game and returns the updated history.
  Future<List<GameResult>> record(
    List<GameResult> current,
    GameResult result,
  ) async {
    final updated = await _store.add(current, result.withId);

    if (updated.length <= _maxEntries) return _newestFirst(updated);

    // Over the cap: keep the newest entries and rewrite the list.
    final trimmed = _newestFirst(updated).take(_maxEntries).toList();
    await _store.persist(trimmed);
    return trimmed;
  }

  // ---------------------------------------------------------------- queries

  List<GameResult> forDay(List<GameResult> history, DateTime day) =>
      _newestFirst(
        history.where((result) => result.isOnSameDayAs(day)).toList(),
      );

  /// How many games were actually FINISHED on [day]. Abandoned games are still
  /// recorded, but they do not count as a completed activity.
  int completedCountForDay(List<GameResult> history, DateTime day) => history
      .where((result) => result.isOnSameDayAs(day) && result.completed)
      .length;

  bool hasActivityOn(List<GameResult> history, DateTime day) =>
      completedCountForDay(history, day) > 0;

  /// The highest score ever recorded for one game, or null if never played.
  GameResult? bestFor(List<GameResult> history, GameType gameType) {
    GameResult? best;
    for (final result in history) {
      if (result.gameType != gameType) continue;
      if (best == null || result.score > best.score) best = result;
    }
    return best;
  }

  GameResult? mostRecent(List<GameResult> history) =>
      history.isEmpty ? null : _newestFirst(history).first;

  List<GameResult> _newestFirst(List<GameResult> results) {
    final copy = [...results];
    copy.sort((a, b) => b.playedAt.compareTo(a.playedAt));
    return copy;
  }
}
