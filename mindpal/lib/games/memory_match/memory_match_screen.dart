import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/difficulty.dart';
import '../../models/game_result.dart';
import '../../theme/app_sizes.dart';
import '../../widgets/game_message_banner.dart';
import '../../widgets/game_result_panel.dart';
import '../../widgets/game_stat_bar.dart';
import 'memory_card.dart';
import 'memory_match_config.dart';
import 'memory_match_game.dart';
import 'widgets/memory_card_tile.dart';

/// The Memory Match screen.
///
/// It owns three things and nothing else:
///   * the game object (the rules live in memory_match_game.dart),
///   * two timers,
///   * the current feedback message.
///
/// Every rule question ("did that match?", "what is my score?") is answered by
/// [MemoryMatchGame]. This file only draws and schedules.
class MemoryMatchScreen extends StatefulWidget {
  const MemoryMatchScreen({super.key, required this.difficulty});

  final Difficulty difficulty;

  @override
  State<MemoryMatchScreen> createState() => _MemoryMatchScreenState();
}

class _MemoryMatchScreenState extends State<MemoryMatchScreen> {
  /// How long two wrong cards stay visible. Generous on purpose — the usual
  /// 700ms in commercial games is far too fast for our users to register.
  static const Duration _mismatchPause = Duration(milliseconds: 1400);

  late MemoryMatchGame _game;

  /// Redraws the clock once a second while playing.
  Timer? _clockTimer;

  /// Turns the two wrong cards back over after [_mismatchPause].
  Timer? _hideTimer;

  String _message = 'Tap any two cards to find a matching pair.';
  MessageTone _tone = MessageTone.neutral;

  @override
  void initState() {
    super.initState();
    _startNewGame();
  }

  @override
  void dispose() {
    // Timers keep firing after the screen is gone unless you cancel them.
    // A timer that calls setState on a disposed widget crashes the app —
    // this is the most common bug in any screen that uses Timer.
    _clockTimer?.cancel();
    _hideTimer?.cancel();
    super.dispose();
  }

  void _startNewGame() {
    _hideTimer?.cancel();
    _clockTimer?.cancel();
    setState(() {
      _game = MemoryMatchGame(
        config: MemoryMatchConfig.forDifficulty(widget.difficulty),
      );
      _message = 'Tap any two cards to find a matching pair.';
      _tone = MessageTone.neutral;
    });
  }

  void _ensureClockRunning() {
    if (_clockTimer != null) return;
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      // Nothing to update except the displayed time, but setState is how we
      // ask Flutter to redraw with the new value from _game.elapsed.
      if (mounted && !_game.isComplete) setState(() {});
    });
  }

  void _handleTap(MemoryCard card) {
    final outcome = _game.tap(card);
    if (outcome == TapResult.ignored) return;

    _ensureClockRunning();

    switch (outcome) {
      case TapResult.firstCardRevealed:
        setState(() {
          _message = 'Now find its pair.';
          _tone = MessageTone.neutral;
        });

      case TapResult.matched:
        setState(() {
          _message = _game.isComplete
              ? 'All pairs found!'
              : 'Good match! ${_game.config.pairCount - _game.matches} to go.';
          _tone = MessageTone.positive;
        });
        if (_game.isComplete) _clockTimer?.cancel();

      case TapResult.mismatched:
        setState(() {
          _message = 'Try again. Remember where those two were.';
          _tone = MessageTone.negative;
        });
        // The board is locked by the game itself until we call hideMismatch.
        _hideTimer = Timer(_mismatchPause, () {
          if (!mounted) return;
          setState(() {
            _game.hideMismatch();
            _message = 'Tap two cards to find a pair.';
            _tone = MessageTone.neutral;
          });
        });

      case TapResult.ignored:
        break; // already handled above
    }
  }

  /// Hands the finished game back to whoever pushed this screen.
  /// (Step 10 will save it; today the hub just shows it in a snackbar.)
  void _leaveWithResult() {
    Navigator.of(context).pop<GameResult>(_game.toResult());
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = _game.elapsed;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Memory Match'),
        // Replaces the default back arrow so leaving still returns the result
        // instead of throwing the game away.
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back to games',
          onPressed: _leaveWithResult,
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.pagePadding),
          child: Column(
            children: [
              GameStatBar(
                stats: [
                  GameStat('Matches', '${_game.matches}/${_game.config.pairCount}'),
                  GameStat('Moves', '${_game.moves}'),
                  GameStat('Time', _formatElapsed(elapsed)),
                ],
              ),
              const SizedBox(height: AppSizes.gap),
              if (!_game.isComplete) ...[
                GameMessageBanner(message: _message, tone: _tone),
                const SizedBox(height: AppSizes.gap),
              ],
              Expanded(
                child: _game.isComplete
                    ? GameResultPanel(
                        result: _game.toResult(),
                        headline: 'All pairs found!',
                        onPlayAgain: _startNewGame,
                        onBackToGames: _leaveWithResult,
                      )
                    : _buildBoard(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds a grid that always fits the space it is given, so the player never
  /// has to scroll a memory board (scrolling would hide cards they need to
  /// remember).
  Widget _buildBoard() {
    const spacing = 12.0;
    final columns = _game.config.columns;
    final rows = _game.config.rows;

    return LayoutBuilder(
      builder: (context, constraints) {
        final cellWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        final cellHeight =
            (constraints.maxHeight - spacing * (rows - 1)) / rows;

        // During the very first layout pass these can be zero or negative.
        final aspectRatio = (cellWidth <= 0 || cellHeight <= 0)
            ? 1.0
            : cellWidth / cellHeight;

        return GridView.count(
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: columns,
          mainAxisSpacing: spacing,
          crossAxisSpacing: spacing,
          childAspectRatio: aspectRatio,
          children: [
            for (var index = 0; index < _game.cards.length; index++)
              MemoryCardTile(
                // A ValueKey tied to the card's id keeps Flutter matching each
                // widget to the same card across rebuilds.
                key: ValueKey(_game.cards[index].id),
                card: _game.cards[index],
                position: index + 1,
                onTap: () => _handleTap(_game.cards[index]),
              ),
          ],
        );
      },
    );
  }

  String _formatElapsed(Duration elapsed) {
    final minutes = elapsed.inMinutes;
    final seconds = elapsed.inSeconds % 60;
    if (minutes == 0) return '${seconds}s';
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
