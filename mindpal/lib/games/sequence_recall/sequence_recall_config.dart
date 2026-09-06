import '../../models/difficulty.dart';

/// Difficulty settings for Sequence Recall.
///
/// Same idea as MemoryMatchConfig: one small table, no logic. To make the game
/// gentler, change a number here.
class SequenceRecallConfig {
  const SequenceRecallConfig({
    required this.difficulty,
    required this.padCount,
    required this.startLength,
    required this.highlightMillis,
    required this.gapMillis,
    required this.tries,
    required this.difficultyBonus,
  });

  final Difficulty difficulty;

  /// How many pads are on screen to choose from.
  final int padCount;

  /// Length of the round-1 sequence. Round 2 is one longer, and so on.
  final int startLength;

  /// How long each pad stays lit while the sequence is shown.
  final int highlightMillis;

  /// The dark pause between two lit pads. Without a gap, two highlights run
  /// together and the player cannot count them.
  final int gapMillis;

  /// Wrong answers allowed before the game ends. Three on every difficulty —
  /// this game is already harder as it goes; taking away chances as well would
  /// make it feel punishing.
  final int tries;

  final int difficultyBonus;

  /// Two columns on every difficulty keeps the pads as large as possible.
  int get columns => 2;

  static const Map<Difficulty, SequenceRecallConfig> _table = {
    Difficulty.easy: SequenceRecallConfig(
      difficulty: Difficulty.easy,
      padCount: 4, // 2 x 2 grid of very large pads
      startLength: 3,
      highlightMillis: 900,
      gapMillis: 400,
      tries: 3,
      difficultyBonus: 0,
    ),
    Difficulty.medium: SequenceRecallConfig(
      difficulty: Difficulty.medium,
      padCount: 6, // 2 x 3
      startLength: 4,
      highlightMillis: 750,
      gapMillis: 320,
      tries: 3,
      difficultyBonus: 50,
    ),
    Difficulty.hard: SequenceRecallConfig(
      difficulty: Difficulty.hard,
      padCount: 6,
      startLength: 5,
      highlightMillis: 600,
      gapMillis: 260,
      tries: 3,
      difficultyBonus: 100,
    ),
  };

  static SequenceRecallConfig forDifficulty(Difficulty difficulty) =>
      _table[difficulty]!;
}
