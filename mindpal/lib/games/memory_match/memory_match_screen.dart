import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../models/difficulty.dart';
import '../../models/game_result.dart';
import '../../models/game_settings.dart';
import '../../models/game_type.dart';
import '../../services/voice/voice_controller.dart';
import '../../theme/app_sizes.dart';
import '../../theme/app_theme.dart';
import '../../widgets/game_message_banner.dart';
import '../../widgets/game_result_panel.dart';
import '../../widgets/game_stat_bar.dart';
import '../widgets/game_feedback.dart';
import '../widgets/game_shell.dart';
import 'memory_card.dart';
import 'memory_match_config.dart';
import 'memory_match_game.dart';
import 'memory_symbol.dart';
import 'widgets/memory_card_tile.dart';

/// The Memory Match screen, for all three boards it can show.
///
/// One screen serves the everyday pictures, a cultural pack and the player's own
/// family photos, because they are the same game: only the pictures on the cards
/// differ. Three near-identical screens would have been three places to fix the
/// next layout bug.
///
/// It owns three things and nothing else: the game object, two timers, and the
/// current feedback message. Every rule question is answered by
/// [MemoryMatchGame].
class MemoryMatchScreen extends StatefulWidget {
  const MemoryMatchScreen({
    super.key,
    required this.difficulty,
    this.config,
    this.pool,
    this.packId,
    this.gameType = GameType.memoryMatch,
    this.title = 'Memory Match',
    this.images = const {},
    this.notes = const [],
    this.factsAreUnchecked = false,
    this.settings = GameSettings.defaults,
    this.voice,
  });

  final Difficulty difficulty;

  /// Overrides the board size for this difficulty. The family-photo board uses
  /// it, because how many pairs there are depends on how many photos the player
  /// picked. Null uses the difficulty's own table.
  final MemoryMatchConfig? config;

  /// The pictures to play with. Null falls back to the app's everyday symbols.
  final List<MemorySymbol>? pool;

  /// Written into the saved result, so progress can name the pack played.
  final String? packId;

  /// Which game this is filed as. The family board is the same rules under a
  /// different name, and a caregiver needs to be able to tell them apart.
  final GameType gameType;

  final String title;

  /// Photo bytes by MediaStore ref, read before the board is dealt so no tile
  /// does file I/O mid-game. A ref missing from this map shows its icon.
  final Map<String, Uint8List> images;

  final List<GameNote> notes;

  /// True when this board's facts come from a pack nobody has reviewed. Every
  /// fact is then shown with that said next to it.
  final bool factsAreUnchecked;

  final GameSettings settings;
  final VoiceController? voice;

  @override
  State<MemoryMatchScreen> createState() => _MemoryMatchScreenState();
}

class _MemoryMatchScreenState extends State<MemoryMatchScreen> {
  /// How long two wrong cards stay visible. Generous on purpose — the usual
  /// 700ms in commercial games is far too fast for our users to register.
  /// Reduced motion shortens the fade, not this: this is reading time.
  static const Duration _mismatchPause = Duration(milliseconds: 1400);

  late MemoryMatchGame _game;

  /// Redraws the clock once a second while playing.
  Timer? _clockTimer;

  /// Turns the two wrong cards back over after [_mismatchPause].
  Timer? _hideTimer;

  String _message = '';
  MessageTone _tone = MessageTone.neutral;

  /// The fact belonging to the pair just found, shown under the message.
  String? _fact;

  GameFeedback get _feedback => GameFeedback(widget.settings);

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

  String get _openingMessage => 'Tap any two cards to find a matching pair.';

  void _startNewGame() {
    _hideTimer?.cancel();
    _clockTimer?.cancel();
    _clockTimer = null;
    setState(() {
      _game = MemoryMatchGame(
        config:
            widget.config ??
            MemoryMatchConfig.forDifficulty(widget.difficulty),
        pool: widget.pool,
        packId: widget.packId,
      );
      _message = _openingMessage;
      _tone = MessageTone.neutral;
      _fact = null;
    });
  }

  void _ensureClockRunning() {
    if (_clockTimer != null) return;
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      // Nothing to update except the displayed time, but setState is how we
      // ask Flutter to redraw with the new value from _game.elapsed.
      if (mounted && !_game.isComplete && !_game.isPaused) setState(() {});
    });
  }

  /// Stops the clock counting while the shell's pause overlay is up.
  void _handlePause(bool paused) {
    setState(() => paused ? _game.pause() : _game.resume());
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
          _fact = null;
        });

      case TapResult.matched:
        _game.isComplete ? _feedback.finished() : _feedback.good();
        setState(() {
          _message = _game.isComplete
              ? 'All pairs found!'
              : 'Good match! ${_game.config.pairCount - _game.matches} to go.';
          _tone = MessageTone.positive;
          // Offered only after the pair is found. A fact shown any earlier
          // would be a hint about a card still face down.
          final matched = _game.lastMatched;
          _fact = matched != null && matched.hasFact ? matched.fact : null;
        });
        if (_game.isComplete) _clockTimer?.cancel();

      case TapResult.mismatched:
        _feedback.notYet();
        setState(() {
          _message = 'Try again. Remember where those two were.';
          _tone = MessageTone.negative;
          _fact = null;
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
  void _leaveWithResult() {
    Navigator.of(context).pop<GameResult>(
      _game.toResult(gameType: widget.gameType),
    );
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = _game.elapsed;

    return GameShell(
      title: widget.title,
      instructions:
          'Tap a card to turn it over, then tap another to find its pair. '
          'There is no time limit.',
      notes: widget.notes,
      settings: widget.settings,
      voice: widget.voice,
      onExit: _leaveWithResult,
      onRestart: _startNewGame,
      onPausedChanged: _handlePause,
      child: GameBoardLayout(
        header: Column(
          children: [
            GameStatBar(
              stats: [
                GameStat(
                  'Matches',
                  '${_game.matches}/${_game.config.pairCount}',
                ),
                GameStat('Moves', '${_game.moves}'),
                GameStat('Time', _formatElapsed(elapsed)),
              ],
            ),
            if (!_game.isComplete) ...[
              const SizedBox(height: AppSizes.gap),
              GameMessageBanner(message: _message, tone: _tone),
              if (_fact != null) ...[
                const SizedBox(height: AppSizes.gapSmall),
                _FactCard(fact: _fact!, unchecked: widget.factsAreUnchecked),
              ],
            ],
          ],
        ),
        board: _game.isComplete
            ? GameResultPanel(
                result: _game.toResult(gameType: widget.gameType),
                headline: 'All pairs found!',
                onPlayAgain: _startNewGame,
                onBackToGames: _leaveWithResult,
              )
            : _buildBoard(),
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
                image: _imageFor(_game.cards[index]),
                reducedMotion: widget.settings.reducedMotion,
                onTap: () => _handleTap(_game.cards[index]),
              ),
          ],
        );
      },
    );
  }

  /// The photo for a card, or null when this is an icon card or the file has
  /// gone missing since the board was built.
  Uint8List? _imageFor(MemoryCard card) {
    final ref = card.symbol.imageRef;
    if (ref == null) return null;
    return widget.images[ref];
  }

  String _formatElapsed(Duration elapsed) {
    final minutes = elapsed.inMinutes;
    final seconds = elapsed.inSeconds % 60;
    if (minutes == 0) return '${seconds}s';
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

/// One short fact about the pair just found.
///
/// When the pack it came from has not been reviewed, that is printed right
/// here — not in a settings screen the player will never open. Someone reading
/// a sentence about their own culture is entitled to know whether anybody has
/// checked it.
class _FactCard extends StatelessWidget {
  const _FactCard({required this.fact, required this.unchecked});

  final String fact;
  final bool unchecked;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.lightbulb_outline_rounded,
                size: 24,
                color: AppColors.primary,
              ),
              const SizedBox(width: AppSizes.gapSmall),
              Expanded(
                child: Text(
                  fact,
                  style: const TextStyle(
                    fontSize: 18,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          if (unchecked) ...[
            const SizedBox(height: 6),
            const Text(
              'Not checked by a reviewer yet.',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}
