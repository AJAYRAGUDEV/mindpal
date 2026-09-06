import '../../models/difficulty.dart';

/// The difficulty settings for Memory Match, in one small table.
///
/// This is the whole "difficulty system" for this game: a lookup from
/// Difficulty to a handful of numbers. To make Easy easier, change one number
/// here — no game logic is touched.
class MemoryMatchConfig {
  const MemoryMatchConfig({
    required this.difficulty,
    required this.pairCount,
    required this.columns,
    required this.difficultyBonus,
  });

  final Difficulty difficulty;

  /// How many pairs are on the board. 4 pairs = 8 cards.
  final int pairCount;

  /// Grid width. Fewer columns means bigger, easier-to-tap cards.
  final int columns;

  /// Flat points added to the score for choosing a harder setting, so a
  /// careful Hard game can out-score a fast Easy game.
  final int difficultyBonus;

  int get cardCount => pairCount * 2;

  int get rows => (cardCount / columns).ceil();

  /// Every difficulty is 4 rows tall — only the width and the number of
  /// pictures change. That keeps the board familiar as the user progresses.
  static const Map<Difficulty, MemoryMatchConfig> _table = {
    Difficulty.easy: MemoryMatchConfig(
      difficulty: Difficulty.easy,
      pairCount: 4, // 8 cards, 2 x 4 — very large cards
      columns: 2,
      difficultyBonus: 0,
    ),
    Difficulty.medium: MemoryMatchConfig(
      difficulty: Difficulty.medium,
      pairCount: 6, // 12 cards, 3 x 4
      columns: 3,
      difficultyBonus: 50,
    ),
    Difficulty.hard: MemoryMatchConfig(
      difficulty: Difficulty.hard,
      pairCount: 8, // 16 cards, 4 x 4
      columns: 4,
      difficultyBonus: 100,
    ),
  };

  static MemoryMatchConfig forDifficulty(Difficulty difficulty) =>
      _table[difficulty]!;
}
