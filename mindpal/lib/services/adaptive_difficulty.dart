import '../models/difficulty.dart';
import '../models/game_result.dart';
import '../models/game_type.dart';

/// The numbers behind the difficulty suggestions, in one place.
///
/// This is the "configurable location" the whole feature turns on: to make
/// MindPal slower to suggest a harder level, raise [comfortableStreak] here and
/// nothing else changes.
class AdaptiveDifficultyConfig {
  const AdaptiveDifficultyConfig({
    this.comfortableStreak = 3,
    this.strugglingStreak = 2,
    this.comfortableMistakes = 1,
    this.strugglingMistakes = 4,
    this.comfortableHints = 0,
    this.strugglingHints = 2,
  });

  /// How many comfortable sessions in a row before a harder level is offered.
  /// Three, not two: one good day is not a pattern, and being pushed up too
  /// soon is the fastest way to make someone stop playing.
  final int comfortableStreak;

  /// How many difficult sessions in a row before an easier level is offered.
  /// Two, because the cost of being stuck is higher than the cost of being
  /// offered something slightly too easy.
  final int strugglingStreak;

  /// At most this many mistakes counts as comfortable.
  final int comfortableMistakes;

  /// This many mistakes or more counts as difficult.
  final int strugglingMistakes;

  final int comfortableHints;
  final int strugglingHints;

  static const AdaptiveDifficultyConfig defaults = AdaptiveDifficultyConfig();
}

/// A level MindPal offers, and why — in words the player reads.
class DifficultySuggestion {
  const DifficultySuggestion({
    required this.gameType,
    required this.from,
    required this.to,
    required this.reason,
  });

  final GameType gameType;
  final Difficulty from;
  final Difficulty to;

  /// Shown to the player verbatim. Always about the GAME, never about the
  /// person: "these have been going well", not "your memory has improved".
  final String reason;

  bool get isHarder => to.index > from.index;
}

/// Rule-based difficulty suggestions.
///
/// **This is not machine learning, and the app never calls it that.** It is a
/// handful of `if` statements over the last few saved sessions, and every
/// threshold is visible in [AdaptiveDifficultyConfig] above. Describing it as a
/// trained model would be a lie, and a needless one — the rules work.
///
/// Three things it deliberately does NOT do:
///
///  * **It never reads how long anyone took.** `GameResult.durationSeconds` is
///    recorded and shown, but no decision here touches it. Playing slowly is
///    not playing badly, and treating a slower session as a worse one would
///    turn this into exactly the kind of quiet assessment the app must not make.
///  * **It never changes the level itself.** It returns an offer. The player or
///    a caregiver taps to accept it, or ignores it forever.
///  * **It draws no conclusion about the person.** Nothing here is a score, a
///    stage, a trend or a sign of anything. It picks a board size.
class AdaptiveDifficulty {
  const AdaptiveDifficulty({this.config = AdaptiveDifficultyConfig.defaults});

  final AdaptiveDifficultyConfig config;

  /// A level to offer for [gameType], or null when the sessions so far say
  /// nothing clear. Null is the normal answer and the UI shows nothing for it.
  DifficultySuggestion? suggest({
    required List<GameResult> history,
    required GameType gameType,
    required Difficulty current,
  }) {
    // Only this game, only this level. Sessions at another difficulty say
    // nothing about whether THIS one is right, and mixing them in would make
    // the suggestion flap about.
    final recent = [
      for (final result in history)
        if (result.gameType == gameType && result.difficulty == current) result,
    ]..sort((a, b) => b.playedAt.compareTo(a.playedAt));

    if (recent.isEmpty) return null;

    final harder = _next(current);
    if (harder != null &&
        recent.length >= config.comfortableStreak &&
        recent
            .take(config.comfortableStreak)
            .every(_wasComfortable)) {
      return DifficultySuggestion(
        gameType: gameType,
        from: current,
        to: harder,
        reason:
            'The last ${config.comfortableStreak} of these went smoothly. '
            'Would you like to try ${harder.label}?',
      );
    }

    final easier = _previous(current);
    if (easier != null &&
        recent.length >= config.strugglingStreak &&
        recent
            .take(config.strugglingStreak)
            .every(_wasHardGoing)) {
      return DifficultySuggestion(
        gameType: gameType,
        from: current,
        to: easier,
        reason:
            'These have been a bit of a struggle. ${easier.label} might be '
            'more enjoyable — you can change back any time.',
      );
    }

    return null;
  }

  /// Finished, with few mistakes and no help needed.
  bool _wasComfortable(GameResult result) =>
      result.completed &&
      result.mistakes <= config.comfortableMistakes &&
      result.hintsUsed <= config.comfortableHints;

  /// Left unfinished, or finished only with a lot of wrong tries or help.
  ///
  /// An abandoned session counts. Someone who opens a game and closes it again
  /// is telling us something, even though they scored nothing.
  bool _wasHardGoing(GameResult result) =>
      !result.completed ||
      result.mistakes >= config.strugglingMistakes ||
      result.hintsUsed >= config.strugglingHints;

  Difficulty? _next(Difficulty current) => switch (current) {
    Difficulty.easy => Difficulty.medium,
    Difficulty.medium => Difficulty.hard,
    Difficulty.hard => null,
  };

  Difficulty? _previous(Difficulty current) => switch (current) {
    Difficulty.easy => null,
    Difficulty.medium => Difficulty.easy,
    Difficulty.hard => Difficulty.medium,
  };
}
