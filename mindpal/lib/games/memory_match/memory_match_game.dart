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
  MemoryMatchGame({
    required this.config,
    List<MemorySymbol>? pool,
    this.packId,
    Random? random,
  }) : _pool = pool ?? kMemorySymbols,
       _random = random ?? Random() {
    _dealCards();
  }

  final MemoryMatchConfig config;

  /// The pictures this board draws from.
  ///
  /// Defaults to the app's own everyday symbols, so every existing caller and
  /// test is unchanged. A cultural pack passes objects from one region, and the
  /// family board passes the user's own photos. The RULES below do not change
  /// between those three — which is the whole reason this is a parameter and
  /// not three copies of the game.
  final List<MemorySymbol> _pool;

  /// Recorded in the result so progress can say which pack was played. Null
  /// means the everyday pictures.
  final String? packId;

  /// The cards actually dealt, so a screen can show what is on the board.
  List<MemorySymbol> get pool => _pool;

  /// Injectable so tests can pass `Random(42)` and get the same board every
  /// time. Real gameplay passes nothing and gets a genuinely shuffled board.
  final Random _random;

  late final List<MemoryCard> cards;

  int moves = 0;
  int matches = 0;
  int mistakes = 0;

  /// The symbol of the pair just found, so the screen can offer its fact.
  /// Null before the first match.
  MemorySymbol? lastMatched;

  DateTime? _startedAt;
  DateTime? _finishedAt;

  /// Total time spent paused, and when the current pause began.
  ///
  /// Without this, pausing would still be charged as playing time. The score's
  /// time penalty is capped and gentle, but "I stopped for ten minutes and it
  /// cost me points" is exactly the kind of quiet unfairness that makes a game
  /// feel hostile.
  Duration _pausedTotal = Duration.zero;
  DateTime? _pausedAt;

  MemoryCard? _firstPick;
  MemoryCard? _secondPick;

  /// True while two non-matching cards are showing. The board ignores taps
  /// during this window so the player cannot flip a third card.
  bool get isWaitingToHide => _secondPick != null;

  bool get isComplete => matches == config.pairCount;

  /// The clock only starts on the first tap, not when the screen opens — the
  /// user should be able to take their time getting settled.
  bool get hasStarted => _startedAt != null;

  bool get isPaused => _pausedAt != null;

  /// Playing time: wall-clock time since the first tap, less any time paused.
  Duration get elapsed {
    final start = _startedAt;
    if (start == null) return Duration.zero;
    final end = _finishedAt ?? DateTime.now();
    final pausedNow = _pausedAt == null
        ? Duration.zero
        : end.difference(_pausedAt!);
    final playing = end.difference(start) - _pausedTotal - pausedNow;
    return playing.isNegative ? Duration.zero : playing;
  }

  void pause() {
    if (_finishedAt != null || _startedAt == null || isPaused) return;
    _pausedAt = DateTime.now();
  }

  void resume() {
    final since = _pausedAt;
    if (since == null) return;
    _pausedTotal += DateTime.now().difference(since);
    _pausedAt = null;
  }

  void _dealCards() {
    // Pick `pairCount` distinct symbols from the pool, in random order.
    //
    // `take` stops early if the pool is smaller than the board asks for, which
    // would silently deal a short board. Callers must check the pool size
    // first (CulturalPack.canFillMatchBoard, and the family game's minimum),
    // and this assert turns a silent short board into a loud failure in debug.
    assert(
      _pool.length >= config.pairCount,
      'Board needs ${config.pairCount} pictures but the pool has '
      '${_pool.length}.',
    );
    final pool = List<MemorySymbol>.from(_pool)..shuffle(_random);
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

    // Compared by pairKey, not by object identity: the two cards of a pair are
    // separate MemoryCard objects that share one symbol.
    if (_firstPick!.symbol.pairKey == card.symbol.pairKey) {
      _firstPick!.isMatched = true;
      card.isMatched = true;
      matches++;
      lastMatched = card.symbol;
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
  ///
  /// [gameType] is a parameter because the family-photo board is the same rules
  /// on different pictures: it must be filed under its own name in progress, so
  /// a caregiver can see "Family Photo Match" rather than a second row of
  /// "Memory Match" they cannot tell apart.
  GameResult toResult({GameType gameType = GameType.memoryMatch}) => GameResult(
    gameType: gameType,
    difficulty: config.difficulty,
    score: score,
    durationSeconds: elapsed.inSeconds,
    completed: isComplete,
    mistakes: mistakes,
    playedAt: DateTime.now(),
    packId: packId,
    correct: matches,
  );
}
