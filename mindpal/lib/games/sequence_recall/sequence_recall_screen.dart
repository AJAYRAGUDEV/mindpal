import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/difficulty.dart';
import '../../models/game_result.dart';
import '../../theme/app_sizes.dart';
import '../../widgets/game_message_banner.dart';
import '../../widgets/game_result_panel.dart';
import '../../widgets/game_stat_bar.dart';
import 'sequence_pad.dart';
import 'sequence_recall_config.dart';
import 'sequence_recall_game.dart';
import 'widgets/sequence_pad_tile.dart';

/// Which part of the round we are in.
///
/// A game that shows something, then waits, then judges, needs a name for
/// "what is happening right now" — otherwise you end up with a tangle of
/// booleans like `isShowing && !isPaused && !isDone`. One enum replaces all
/// of them, and makes illegal combinations impossible.
enum SequencePhase {
  /// The sequence is lighting up. Pads are not tappable.
  showing,

  /// The player's turn.
  recalling,

  /// Showing feedback between rounds. Pads are not tappable.
  pausing,

  /// Out of tries. The result panel is showing.
  finished,
}

class SequenceRecallScreen extends StatefulWidget {
  const SequenceRecallScreen({super.key, required this.difficulty});

  final Difficulty difficulty;

  @override
  State<SequenceRecallScreen> createState() => _SequenceRecallScreenState();
}

class _SequenceRecallScreenState extends State<SequenceRecallScreen> {
  late SequenceRecallGame _game;

  SequencePhase _phase = SequencePhase.showing;
  String _message = 'Watch carefully.';
  MessageTone _tone = MessageTone.neutral;

  /// Which pad is currently lit, or null. This is the only piece of "how the
  /// game looks" state — the rules class knows nothing about it.
  int? _litPad;

  /// Cancellation token for the playback loop.
  ///
  /// `_playSequence` is an async loop with `await` gaps in it. If the player
  /// restarts mid-playback, the OLD loop is still suspended and will wake up
  /// and light pads for a game that no longer exists. Every loop captures the
  /// run id it started with and gives up as soon as `_runId` moves on.
  /// This is a standard pattern any time you await inside a widget.
  int _runId = 0;

  Timer? _pauseTimer;
  Timer? _flashTimer;

  @override
  void initState() {
    super.initState();
    _game = SequenceRecallGame(
      config: SequenceRecallConfig.forDifficulty(widget.difficulty),
    );
    // Plain assignment, not setState: the first build has not happened yet.
    _beginRound(isInitial: true);
  }

  @override
  void dispose() {
    _runId++; // any suspended playback loop will bail out on wake
    _pauseTimer?.cancel();
    _flashTimer?.cancel();
    super.dispose();
  }

  void _beginRound({bool advance = false, bool isInitial = false}) {
    if (advance) _game.advanceRound();
    _game.startRound();

    void apply() {
      _phase = SequencePhase.showing;
      _litPad = null;
      _message = 'Watch carefully.';
      _tone = MessageTone.neutral;
    }

    if (isInitial) {
      apply();
    } else {
      setState(apply);
    }

    _playSequence();
  }

  /// Lights the pads one at a time, then hands control to the player.
  Future<void> _playSequence() async {
    final runId = ++_runId;

    // A breath before the sequence starts, so the player is looking.
    await Future.delayed(const Duration(milliseconds: 800));

    for (final padIndex in _game.sequence) {
      if (!mounted || runId != _runId) return;
      setState(() => _litPad = padIndex);

      await Future.delayed(
        Duration(milliseconds: _game.config.highlightMillis),
      );
      if (!mounted || runId != _runId) return;
      setState(() => _litPad = null);

      // The dark gap is what separates one pad from the next.
      await Future.delayed(Duration(milliseconds: _game.config.gapMillis));
    }

    if (!mounted || runId != _runId) return;
    setState(() {
      _phase = SequencePhase.recalling;
      _message = 'Your turn. Tap them in the same order.';
      _tone = MessageTone.neutral;
    });
  }

  /// Briefly lights the pad the player just pressed, so a tap always produces
  /// visible confirmation.
  void _flash(int padIndex) {
    _flashTimer?.cancel();
    setState(() => _litPad = padIndex);
    _flashTimer = Timer(const Duration(milliseconds: 220), () {
      if (mounted) setState(() => _litPad = null);
    });
  }

  void _handlePadTap(int padIndex) {
    if (_phase != SequencePhase.recalling) return;

    _flash(padIndex);
    final outcome = _game.submitTap(padIndex);

    switch (outcome) {
      case SequenceTapResult.correct:
        setState(() {
          _message = 'Good. ${_game.progress} of ${_game.sequence.length}.';
          _tone = MessageTone.positive;
        });

      case SequenceTapResult.roundComplete:
        setState(() {
          _phase = SequencePhase.pausing;
          _message = 'Correct! That was ${_game.sequence.length} in a row.';
          _tone = MessageTone.positive;
        });
        _pauseThen(
          const Duration(milliseconds: 1500),
          () => _beginRound(advance: true),
        );

      case SequenceTapResult.wrong:
        if (_game.isOver) {
          setState(() => _phase = SequencePhase.finished);
        } else {
          setState(() {
            _phase = SequencePhase.pausing;
            _message =
                "Not quite. Let's try that round once more "
                '(${_game.triesRemaining} left).';
            _tone = MessageTone.negative;
          });
          _pauseThen(const Duration(milliseconds: 1900), _beginRound);
        }
    }
  }

  void _pauseThen(Duration delay, VoidCallback action) {
    _pauseTimer?.cancel();
    _pauseTimer = Timer(delay, () {
      if (mounted) action();
    });
  }

  void _restart() {
    _runId++;
    _pauseTimer?.cancel();
    _flashTimer?.cancel();
    setState(() {
      _game = SequenceRecallGame(
        config: SequenceRecallConfig.forDifficulty(widget.difficulty),
      );
    });
    _beginRound();
  }

  void _leaveWithResult() {
    Navigator.of(context).pop<GameResult>(_game.toResult());
  }

  @override
  Widget build(BuildContext context) {
    final isFinished = _phase == SequencePhase.finished;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sequence Recall'),
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
                  GameStat('Round', '${_game.round}'),
                  GameStat('Length', '${_game.sequence.length}'),
                  GameStat('Tries left', '${_game.triesRemaining}'),
                ],
              ),
              const SizedBox(height: AppSizes.gap),
              if (!isFinished) ...[
                GameMessageBanner(message: _message, tone: _tone),
                const SizedBox(height: AppSizes.gap),
              ],
              Expanded(
                child: isFinished ? _buildResult() : _buildPads(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResult() {
    final result = _game.toResult();
    return GameResultPanel(
      result: result,
      // No green tick here: the game ended because the tries ran out, and a
      // "you won" symbol after a wrong answer is exactly the kind of mixed
      // message that confuses people.
      icon: Icons.emoji_events_outlined,
      iconColor: const Color(0xFF8F5000),
      headline: _game.roundsCompleted > 0 ? 'Well played!' : 'Good try!',
      subtitle: _game.roundsCompleted > 0
          ? 'You remembered ${_game.roundsCompleted} '
                '${_game.roundsCompleted == 1 ? "round" : "rounds"} correctly.'
          : 'Have another go — it gets easier with practice.',
      extraStats: {
        'Rounds passed': '${_game.roundsCompleted}',
        'Longest sequence': '${_game.longestSequence}',
      },
      onPlayAgain: _restart,
      onBackToGames: _leaveWithResult,
    );
  }

  Widget _buildPads() {
    const spacing = 14.0;
    final columns = _game.config.columns;
    final padCount = _game.config.padCount;
    final rows = (padCount / columns).ceil();
    final canTap = _phase == SequencePhase.recalling;

    return LayoutBuilder(
      builder: (context, constraints) {
        final cellWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        final cellHeight =
            (constraints.maxHeight - spacing * (rows - 1)) / rows;
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
            for (var index = 0; index < padCount; index++)
              SequencePadTile(
                key: ValueKey(index),
                pad: kSequencePads[index],
                isLit: _litPad == index,
                isEnabled: canTap,
                onTap: () => _handlePadTap(index),
              ),
          ],
        );
      },
    );
  }
}
