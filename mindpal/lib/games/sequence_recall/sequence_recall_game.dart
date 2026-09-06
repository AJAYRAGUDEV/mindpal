import 'dart:math';

import '../../models/game_result.dart';
import '../../models/game_type.dart';
import 'sequence_recall_config.dart';

/// What one pad tap did.
enum SequenceTapResult {
  /// Right pad, but the sequence is not finished yet.
  correct,

  /// Right pad, and that was the last one — the round is passed.
  roundComplete,

  /// Wrong pad. One try is gone.
  wrong,
}

/// The rules of Sequence Recall.
///
/// Like MemoryMatchGame, this is plain Dart with no Flutter import, so all of
/// it is unit-testable.
///
/// Note what is NOT here: anything about *timing*. "Light this pad for 900ms"
/// is presentation, and lives in the screen. This class only knows what the
/// sequence is and whether the player reproduced it.
class SequenceRecallGame {
  SequenceRecallGame({required this.config, Random? random})
    : _random = random ?? Random(),
      triesRemaining = config.tries {
    startRound();
  }

  final SequenceRecallConfig config;
  final Random _random;

  /// 1-based. Round 1 uses `config.startLength` pads, round 2 one more, etc.
  int round = 1;

  int mistakes = 0;
  int roundsCompleted = 0;
  int triesRemaining;

  /// Points banked from rounds already passed.
  int _points = 0;

  /// The pad indexes the player must repeat, in order.
  List<int> sequence = const [];

  /// How many pads of the current sequence have been tapped correctly.
  int progress = 0;

  DateTime? _startedAt;
  DateTime? _finishedAt;

  int get sequenceLength => config.startLength + (round - 1);

  /// The longest sequence the player actually got right.
  int get longestSequence =>
      roundsCompleted == 0 ? 0 : config.startLength + roundsCompleted - 1;

  bool get isOver => triesRemaining <= 0;

  Duration get elapsed {
    final start = _startedAt;
    if (start == null) return Duration.zero;
    return (_finishedAt ?? DateTime.now()).difference(start);
  }

  /// Builds a fresh random sequence for the current round.
  ///
  /// Called at the start of the game, after a passed round, and after a failed
  /// round (a retry gets a NEW sequence of the same length, so the player is
  /// exercising memory rather than re-learning one pattern).
  void startRound() {
    progress = 0;

    final generated = <int>[];
    while (generated.length < sequenceLength) {
      final next = _random.nextInt(config.padCount);
      // Never light the same pad twice in a row. Two identical highlights back
      // to back look like ONE long highlight, and the sequence becomes
      // impossible to count — a genuinely unfair puzzle.
      if (generated.isNotEmpty && generated.last == next) continue;
      generated.add(next);
    }

    sequence = generated;
  }

  /// The player tapped a pad. The screen must only call this while it is the
  /// player's turn.
  SequenceTapResult submitTap(int padIndex) {
    _startedAt ??= DateTime.now();

    if (padIndex != sequence[progress]) {
      mistakes++;
      triesRemaining--;
      if (isOver) _finishedAt = DateTime.now();
      return SequenceTapResult.wrong;
    }

    progress++;

    if (progress < sequence.length) return SequenceTapResult.correct;

    // Whole sequence reproduced.
    roundsCompleted++;
    _points += sequence.length * 30;
    return SequenceTapResult.roundComplete;
  }

  /// Move up to a longer sequence. The screen calls this after a passed round,
  /// then calls [startRound].
  void advanceRound() => round++;

  /// The pad the player should tap next. Used only to build a helpful message.
  int get expectedPad => sequence[progress];

  /// Score = points banked from passed rounds, minus mistakes, plus the
  /// difficulty bonus.
  ///
  ///   each passed round : sequence length x 30
  ///                       (round 1 of Easy = 3 x 30 = 90, round 2 = 120 ...)
  ///   each mistake      : -20
  ///   difficulty        : +0 / +50 / +100
  ///
  /// There is no time penalty here — the game controls its own pace, so
  /// charging the player for time would punish them for our animation speed.
  int get score {
    if (roundsCompleted == 0) return 0;
    final total = _points - (mistakes * 20) + config.difficultyBonus;
    return total < 0 ? 0 : total;
  }

  /// `completed` means "the user actually did a round of cognitive work",
  /// which is what the daily activity summary cares about. This game has no
  /// natural end, so finishing every round is not a possible outcome.
  GameResult toResult() => GameResult(
    gameType: GameType.sequenceRecall,
    difficulty: config.difficulty,
    score: score,
    durationSeconds: elapsed.inSeconds,
    completed: roundsCompleted > 0,
    mistakes: mistakes,
    playedAt: DateTime.now(),
  );
}
