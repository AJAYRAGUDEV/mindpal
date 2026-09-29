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
  OddOneOutGame({
    required this.config,
    this.deck = OddOneOutDeck.everyday,
    Random? random,
  }) : _random = random ?? Random() {
    startRound();
  }

  final OddOneOutConfig config;

  /// Where the tiles come from. Defaults to the app's everyday pictures, so
  /// every existing caller behaves exactly as before.
  final OddOneOutDeck deck;

  final Random _random;

  /// How many tiles this board really has.
  ///
  /// The difficulty asks for a number; a small cultural pack may not have
  /// enough items of one kind to fill it. Dealing the biggest honest board and
  /// telling the player beats padding the board with items from a third
  /// category, which would destroy the "one clear rule" the game depends on.
  int get itemCount {
    final largest = deck.largestBoard;
    if (largest <= 0) return config.itemCount;
    return config.itemCount <= largest ? config.itemCount : largest;
  }

  /// True when the board had to be made smaller than the difficulty asked for.
  /// The screen shows a plain note when this is set.
  bool get boardWasReduced => itemCount < config.itemCount;

  /// Kept in step with [itemCount] so the grid never has a ragged last row.
  int get columns => itemCount <= 4 ? 2 : (itemCount <= 6 ? 2 : 3);

  int get rows => (itemCount / columns).ceil();

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

  OddOneOutItem get oddItem => items[oddIndex];

  /// Why that tile is the odd one, in one plain sentence.
  ///
  /// Built from the two category names rather than written per round, so it can
  /// never drift out of step with the board it is explaining. Any item's own
  /// fact is appended when it has one.
  ///
  /// "The others are musical instruments. Pitha is a food."
  String get explanation {
    final sentence =
        'The others are all ${majorityCategory.many}. '
        '${oddItem.label} is ${oddCategory.singular}.';
    final fact = oddItem.fact;
    return fact == null || fact.trim().isEmpty ? sentence : '$sentence $fact';
  }

  /// A nudge that names the rule without giving away the answer.
  String get hint =>
      'Most of these are ${majorityCategory.many}. Look for the one that '
      'is not.';

  int hintsUsed = 0;

  /// Counted once per round at most, so tapping Hint repeatedly does not
  /// inflate the number the difficulty suggestion reads.
  bool _hintedThisRound = false;

  void useHint() {
    if (_hintedThisRound) return;
    _hintedThisRound = true;
    hintsUsed++;
  }

  Duration get elapsed {
    final start = _startedAt;
    if (start == null) return Duration.zero;
    return (_finishedAt ?? DateTime.now()).difference(start);
  }

  /// Builds a board: one category for the majority, a DIFFERENT category for
  /// the single odd item.
  void startRound() {
    _selectedIndex = null;

    // A deck needs two categories to have a right answer at all: with one, the
    // majority and the odd item would come from the same group and every tile
    // would be equally correct. The hub will not offer the game for such a
    // pack, and this turns the mistake into a clear failure rather than a board
    // with no answer.
    assert(
      deck.isPlayable,
      'Odd-One-Out needs at least two kinds with two items each; this deck has '
      '${deck.categories.length}.',
    );

    // Only the categories this deck actually holds items for, so a board is
    // never dealt short.
    final categories = List<ItemCategory>.from(deck.categories)
      ..shuffle(_random);
    final majority = categories.first;
    final odd = categories.last; // guaranteed different: the list is shuffled
    // and has at least two entries, so first and last are never the same.

    final majorityPool = deck.itemsIn(majority)..shuffle(_random);
    final oddPool = deck.itemsIn(odd)..shuffle(_random);

    final board = <OddOneOutItem>[
      ...majorityPool.take(itemCount - 1),
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
    _hintedThisRound = false;
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
    packId: deck.packId,
    correct: correctCount,
    hintsUsed: hintsUsed,
  );
}
