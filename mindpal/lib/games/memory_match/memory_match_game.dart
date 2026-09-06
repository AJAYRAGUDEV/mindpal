import 'dart:math';

import '../../models/game_result.dart';
import '../../models/game_type.dart';
import 'memory_card.dart';
import 'memory_match_config.dart';
import 'memory_symbol.dart';

/// What happened when the player tapped a card. The screen uses this to decide
/// which message to show and whether to start the "hide again" timer.
enum TapResult {
  /// Tap did nothing (card already face up, board locked, game over).
  ignored,

  /// First card of a pair is now showing. Nothing to judge yet.
  firstCardRevealed,

  /// Second card matched the first. Both stay face up.
  matched,

  /// Second card did not match. The board is now locked until the screen
  /// calls [hideMismatch].
  mismatched,
}

/// The rules of Memory Match.
///
/// Notice there is NO `import 'package:flutter/...'` in this file. It is plain
/// Dart. That means:
///   * you can unit-test it in milliseconds without building any UI,
///   * the rules cannot accidentally depend on what is on screen,
///   * if we ever redesign the game's look, this file does not change.
///
/// This separation — logic in one file, appearance in another — is the single
/// most useful habit for keeping a growing app debuggable.
class MemoryMatchGame {
  MemoryMatchGame({required this.config, Random? random})
    : _random = random ?? Random() {
    _dealCards();
  }

  final MemoryMatchConfig config;

  /// Injectable so tests can pass `Random(42)` and get the same board every
  /// time. Real gameplay passes nothing and gets a genuinely shuffled board.
  final Random _random;

  late final List<MemoryCard> cards;

  int moves = 0;
  int matches = 0;
  int mistakes = 0;

  DateTime? _startedAt;
  DateTime? _finishedAt;

  MemoryCard? _firstPick;
  MemoryCard? _secondPick;

  /// True while two non-matching cards are showing. The board ignores taps
  /// during this window so the player cannot flip a third card.
  bool get isWaitingToHide => _secondPick != null;

  bool get isComplete => matches == config.pairCount;

  /// The clock only starts on the first tap, not when the screen opens — the
  /// user should be able to take their time getting settled.
  bool get hasStarted => _startedAt != null;

  Duration get elapsed {
    final start = _startedAt;
    if (start == null) return Duration.zero;
    return (_finishedAt ?? DateTime.now()).difference(start);
  }

  void _dealCards() {
    // Pick `pairCount` distinct symbols from the pool, in random order.
    final pool = List<MemorySymbol>.from(kMemorySymbols)..shuffle(_random);
    final chosen = pool.take(config.pairCount);

    var nextId = 0;
    cards =
        [
          // A "collection for" with a spread: for each symbol, add two cards.
          for (final symbol in chosen) ...[
            MemoryCard(id: nextId++, symbol: symbol),
            MemoryCard(id: nextId++, symbol: symbol),
          ],
        ]..shuffle(_random); // ..shuffle returns the list, not the shuffle
  }

  /// The one entry point for playing. Everything else is a getter.
  TapResult tap(MemoryCard card) {
    if (isComplete || isWaitingToHide || card.isMatched || card.isFaceUp) {
      return TapResult.ignored;
    }

    _startedAt ??= DateTime.now(); // ??= means "assign only if still null"
    card.isFaceUp = true;

    if (_firstPick == null) {
      _firstPick = card;
      return TapResult.firstCardRevealed;
    }

    moves++;

    // Same symbol object, but compared by label so the check stays obvious.
    if (_firstPick!.symbol.label == card.symbol.label) {
      _firstPick!.isMatched = true;
      card.isMatched = true;
      matches++;
      _firstPick = null;
      _secondPick = null; // board is immediately playable again
      if (isComplete) _finishedAt = DateTime.now();
      return TapResult.matched;
    }

    mistakes++;
    _secondPick = card; // locks the board until hideMismatch()
    return TapResult.mismatched;
  }

  /// Turn the two wrong cards back over. The screen calls this after a pause
  /// long enough for the player to actually look at them.
  void hideMismatch() {
    _firstPick?.isFaceUp = false;
    _secondPick?.isFaceUp = false;
    _firstPick = null;
    _secondPick = null;
  }

  /// Score = what you found, minus what you got wrong, minus a little for
  /// time, plus a bonus for playing on a harder setting.
  ///
  ///   found      : 100 points per matched pair
  ///   mistakes   : -20 points each
  ///   time       : -2 points per 5 seconds, CAPPED at -100
  ///   difficulty : +0 / +50 / +100
  ///
  /// The time cap matters for our users: a player who needs four minutes
  /// instead of one still keeps most of their score. We are measuring memory,
  /// not speed. The score can never go below zero.
  int get score {
    if (matches == 0) return 0;

    final found = matches * 100;
    final mistakePenalty = mistakes * 20;
    final timePenalty = min(100, (elapsed.inSeconds ~/ 5) * 2);

    final total = found - mistakePenalty - timePenalty + config.difficultyBonus;
    return total < 0 ? 0 : total;
  }

  /// Package the finished game into the shared model that every game returns.
  GameResult toResult() => GameResult(
    gameType: GameType.memoryMatch,
    difficulty: config.difficulty,
    score: score,
    durationSeconds: elapsed.inSeconds,
    completed: isComplete,
    mistakes: mistakes,
    playedAt: DateTime.now(),
  );
}
