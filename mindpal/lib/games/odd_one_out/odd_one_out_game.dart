import 'dart:math';

import '../../models/difficulty.dart';
import '../../models/game_result.dart';
import '../../models/game_type.dart';
import 'odd_one_out_item.dart';

/// Difficulty for Odd-One-Out.
///
/// Only the NUMBER of tiles changes. The odd item is always from a completely
/// different category, on every difficulty — "harder" must never mean "more
/// ambiguous", because an ambiguous question is unfair rather than difficult.
class OddOneOutConfig {
  const OddOneOutConfig({
    required this.difficulty,
    required this.itemCount,
    required this.columns,
    required this.rounds,
  });

  final Difficulty difficulty;

  /// Tiles on screen, including the odd one.
  final int itemCount;

  final int columns;
  final int rounds;

  static const Map<Difficulty, OddOneOutConfig> _table = {
    Difficulty.easy: OddOneOutConfig(
      difficulty: Difficulty.easy,
      itemCount: 4, // 2 x 2, very large tiles
      columns: 2,
      rounds: 5,
    ),
    Difficulty.medium: OddOneOutConfig(
      difficulty: Difficulty.medium,
      itemCount: 6, // 2 x 3
      columns: 2,
      rounds: 5,
    ),
    Difficulty.hard: OddOneOutConfig(
      difficulty: Difficulty.hard,
      itemCount: 9, // 3 x 3
      columns: 3,
      rounds: 5,
    ),
  };

  static OddOneOutConfig forDifficulty(Difficulty difficulty) =>
      _table[difficulty]!;

  int get rows => (itemCount / columns).ceil();
}

/// The rules of Odd-One-Out. Plain Dart, no Flutter — same as every other
/// game in this project, so the whole thing is testable without a screen.
class OddOneOutGame {
  OddOneOutGame({required this.config, Random? random})
    : _random = random ?? Random() {
    startRound();
  }

  final OddOneOutConfig config;
  final Random _random;

  int round = 1;
  int correctCount = 0;
  int mistakes = 0;

  late List<OddOneOutItem> items;

  /// Where the odd item ended up after shuffling.
  late int oddIndex;

  int? _selectedIndex;

  DateTime? _startedAt;
  DateTime? _finishedAt;

  int? get selectedIndex => _selectedIndex;
  bool get isAnswered => _selectedIndex != null;
  bool get wasCorrect => isAnswered && _selectedIndex == oddIndex;
  bool get isLastRound => round == config.rounds;
  bool get isComplete => _finishedAt != null;

  /// The category the majority of tiles belong to.
  ItemCategory get majorityCategory => items[(oddIndex + 1) % items.length].category;

  ItemCategory get oddCategory => items[oddIndex].category;

  Duration get elapsed {
    final start = _startedAt;
    if (start == null) return Duration.zero;
    return (_finishedAt ?? DateTime.now()).difference(start);
  }

  /// Builds a board: one category for the majority, a DIFFERENT category for
  /// the single odd item.
  void startRound() {
    _selectedIndex = null;

    final categories = List<ItemCategory>.from(ItemCategory.values)
      ..shuffle(_random);
    final majority = categories.first;
    final odd = categories.last; // guaranteed different: the list is shuffled
    // and has four entries, so first and last are never the same object.

    final majorityPool = itemsInCategory(majority)..shuffle(_random);
    final oddPool = itemsInCategory(odd)..shuffle(_random);

    final board = <OddOneOutItem>[
      ...majorityPool.take(config.itemCount - 1),
      oddPool.first,
    ];

    // Remember which object is the odd one BEFORE shuffling, then find it
    // again afterwards. Storing the index before the shuffle would be wrong.
    final oddItem = oddPool.first;
    board.shuffle(_random);

    items = board;
    oddIndex = board.indexOf(oddItem);
  }

  /// Records a tap. Returns whether it was the odd one.
  ///
  /// A second tap on the same round does nothing, so the score cannot be
  /// changed by an impatient double-tap.
  bool answer(int index) {
    if (isAnswered || isComplete) return wasCorrect;

    _startedAt ??= DateTime.now();
    _selectedIndex = index;

    if (index == oddIndex) {
      correctCount++;
    } else {
      mistakes++;
    }

    if (isLastRound) _finishedAt = DateTime.now();
    return wasCorrect;
  }

  /// Moves on. Does nothing on the last round.
  void next() {
    if (!isAnswered || isLastRound) return;
    round++;
    startRound();
  }

  /// 100 points per correct answer. No time pressure and no difficulty bonus —
  /// this is a noticing exercise, not a race.
  int get score => correctCount * 100;

  GameResult toResult() => GameResult(
    gameType: GameType.oddOneOut,
    difficulty: config.difficulty,
    score: score,
    durationSeconds: elapsed.inSeconds,
    completed: isComplete,
    mistakes: mistakes,
    playedAt: DateTime.now(),
  );
}
