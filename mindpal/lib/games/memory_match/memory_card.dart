import 'memory_symbol.dart';

/// One card on the board.
///
/// Note this class is MUTABLE — `isFaceUp` and `isMatched` change as you play.
/// That is a deliberate difference from UserProfile and GameResult, which are
/// immutable.
///
/// The rule of thumb: data you SAVE is immutable (so nothing can quietly
/// change it behind your back), while a live simulation like a game board is
/// simpler to write as mutable state that one owner controls. Here the only
/// owner is MemoryMatchGame.
class MemoryCard {
  MemoryCard({required this.id, required this.symbol});

  /// Unique per card. Two cards share a symbol but never an id — this is what
  /// lets Flutter tell the pair apart when rebuilding the grid.
  final int id;

  final MemorySymbol symbol;

  /// Temporarily turned over by the player.
  bool isFaceUp = false;

  /// Permanently turned over because its pair was found.
  bool isMatched = false;

  bool get isHidden => !isFaceUp && !isMatched;
}
