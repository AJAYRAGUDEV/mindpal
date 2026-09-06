import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../l10n/language_scope.dart';
import '../../models/difficulty.dart';
import '../../models/game_result.dart';
import '../../theme/app_sizes.dart';
import '../../theme/app_theme.dart';
import 'odd_one_out_game.dart';
import 'odd_one_out_item.dart';

/// Odd-One-Out.
///
/// Same shape as the personalised game on purpose: progress, one question,
/// large tiles, feedback, then a result. Three games that behave differently
/// would be three things for the user to learn.
class OddOneOutScreen extends StatefulWidget {
  const OddOneOutScreen({super.key, required this.difficulty});

  final Difficulty difficulty;

  @override
  State<OddOneOutScreen> createState() => _OddOneOutScreenState();
}

class _OddOneOutScreenState extends State<OddOneOutScreen> {
  late OddOneOutGame _game;
  bool _showingResult = false;

  @override
  void initState() {
    super.initState();
    _game = OddOneOutGame(
      config: OddOneOutConfig.forDifficulty(widget.difficulty),
    );
  }

  void _restart() {
    setState(() {
      _game = OddOneOutGame(
        config: OddOneOutConfig.forDifficulty(widget.difficulty),
      );
      _showingResult = false;
    });
  }

  void _answer(int index) {
    if (_game.isAnswered) return;
    setState(() => _game.answer(index));
  }

  void _next() => setState(() => _game.next());

  void _showResult() => setState(() => _showingResult = true);

  void _leaveWithResult() =>
      Navigator.of(context).pop<GameResult>(_game.toResult());

  @override
  Widget build(BuildContext context) {
    final strings = LanguageScope.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.oddOneOut),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: strings.backToHome,
          onPressed: _leaveWithResult,
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.pagePadding),
          child: _showingResult
              ? _ResultView(
                  game: _game,
                  strings: strings,
                  onPlayAgain: _restart,
                  onBackHome: _leaveWithResult,
                )
              : _RoundView(
                  game: _game,
                  strings: strings,
                  onAnswer: _answer,
                  onNext: _next,
                  onShowResult: _showResult,
                ),
        ),
      ),
    );
  }
}

class _RoundView extends StatelessWidget {
  const _RoundView({
    required this.game,
    required this.strings,
    required this.onAnswer,
    required this.onNext,
    required this.onShowResult,
  });

  final OddOneOutGame game;
  final AppStrings strings;
  final ValueChanged<int> onAnswer;
  final VoidCallback onNext;
  final VoidCallback onShowResult;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ProgressHeader(game: game, strings: strings),
        const SizedBox(height: AppSizes.gap),

        Text(
          strings.whichIsDifferent,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSizes.gap),

        // The board fills whatever space is left, so it never scrolls.
        Expanded(child: _Board(game: game, onAnswer: onAnswer)),

        if (game.isAnswered) ...[
          const SizedBox(height: AppSizes.gap),
          _Feedback(game: game, strings: strings),
          const SizedBox(height: AppSizes.gap),
          FilledButton.icon(
            onPressed: game.isLastRound ? onShowResult : onNext,
            icon: Icon(
              game.isLastRound
                  ? Icons.emoji_events_rounded
                  : Icons.arrow_forward_rounded,
              size: AppSizes.iconMedium,
            ),
            label: Text(
              game.isLastRound ? strings.seeResult : strings.nextQuestion,
            ),
          ),
        ],
      ],
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({required this.game, required this.strings});

  final OddOneOutGame game;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '${strings.roundLabel} ${game.round} / ${game.config.rounds}',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.primaryDark,
          ),
        ),
        const SizedBox(height: AppSizes.gapSmall),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: game.round / game.config.rounds),
            duration: const Duration(milliseconds: 400),
            builder: (context, value, _) => LinearProgressIndicator(
              value: value,
              minHeight: 14,
              backgroundColor: AppColors.background,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.primary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Board extends StatelessWidget {
  const _Board({required this.game, required this.onAnswer});

  final OddOneOutGame game;
  final ValueChanged<int> onAnswer;

  @override
  Widget build(BuildContext context) {
    const spacing = 12.0;
    final columns = game.config.columns;
    final rows = game.config.rows;

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
            for (var index = 0; index < game.items.length; index++)
              _ItemTile(
                key: ValueKey('${game.round}-$index'),
                item: game.items[index],
                position: index + 1,
                state: _stateFor(index),
                onTap: game.isAnswered ? null : () => onAnswer(index),
              ),
          ],
        );
      },
    );
  }

  _TileState _stateFor(int index) {
    if (!game.isAnswered) return _TileState.waiting;
    if (index == game.oddIndex) return _TileState.correct;
    if (index == game.selectedIndex) return _TileState.chosenWrong;
    return _TileState.dimmed;
  }
}

enum _TileState { waiting, correct, chosenWrong, dimmed }

class _ItemTile extends StatelessWidget {
  const _ItemTile({
    super.key,
    required this.item,
    required this.position,
    required this.state,
    required this.onTap,
  });

  final OddOneOutItem item;
  final int position;
  final _TileState state;
  final VoidCallback? onTap;

  static const Color _green = Color(0xFF1B5E20);

  @override
  Widget build(BuildContext context) {
    final (Color border, Color fill, IconData? mark) = switch (state) {
      _TileState.waiting => (AppColors.border, AppColors.surface, null),
      _TileState.correct => (
        _green,
        const Color(0xFFE3F1E4),
        Icons.check_circle_rounded,
      ),
      _TileState.chosenWrong => (
        AppColors.reminder,
        AppColors.surface,
        Icons.info_outline_rounded,
      ),
      _TileState.dimmed => (AppColors.border, AppColors.background, null),
    };

    return Semantics(
      button: onTap != null,
      // The name is spoken, so a TalkBack user is not asked to identify an
      // unlabelled picture.
      label: 'Item $position, ${item.label}',
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSizes.radius),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(AppSizes.radius),
              border: Border.all(color: border, width: 2.5),
            ),
            child: Stack(
              children: [
                Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(item.icon, size: 58, color: item.category.color),
                          const SizedBox(height: 6),
                          // The word matters as much as the picture.
                          Text(
                            item.label,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (mark != null)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Icon(mark, size: 26, color: border),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Feedback extends StatelessWidget {
  const _Feedback({required this.game, required this.strings});

  final OddOneOutGame game;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final correct = game.wasCorrect;
    final color = correct ? _ItemTile._green : AppColors.reminder;

    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSizes.cardPadding),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSizes.radius),
          border: Border.all(color: color, width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  correct
                      ? Icons.celebration_rounded
                      : Icons.favorite_rounded,
                  size: 26,
                  color: color,
                ),
                const SizedBox(width: AppSizes.gapSmall),
                Expanded(
                  child: Text(
                    correct ? strings.greatJob : strings.niceTry,
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.gapSmall),
            // Always explain WHY, not just whether. "Boat is the only one that
            // is not a thing at home" teaches the grouping; a red cross does
            // not.
            Text(
              '${strings.theAnswerWas}: ${game.items[game.oddIndex].label}. '
              '${game.oddCategory.label} — '
              '${game.majorityCategory.label.toLowerCase()} everywhere else.',
              style: const TextStyle(
                fontSize: 19,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({
    required this.game,
    required this.strings,
    required this.onPlayAgain,
    required this.onBackHome,
  });

  final OddOneOutGame game;
  final AppStrings strings;
  final VoidCallback onPlayAgain;
  final VoidCallback onBackHome;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: AppSizes.gap),
        Center(
          child: Container(
            width: 104,
            height: 104,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.emoji_events_rounded,
              size: 58,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: AppSizes.gapLarge),
        Text(
          strings.wellDone,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.displaySmall,
        ),
        const SizedBox(height: AppSizes.gapSmall),
        Text(
          strings.youCompletedGame,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: AppSizes.gapLarge),
        Center(
          child: Text(
            '${game.correctCount} / ${game.config.rounds}',
            style: const TextStyle(
              fontSize: 56,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryDark,
            ),
          ),
        ),
        const SizedBox(height: AppSizes.gapSmall),
        Center(
          child: Text(
            strings.activityResult,
            style: const TextStyle(
              fontSize: 18,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(height: AppSizes.gapLarge),
        FilledButton.icon(
          onPressed: onPlayAgain,
          icon: const Icon(Icons.replay_rounded, size: AppSizes.iconMedium),
          label: Text(strings.playAgain),
        ),
        const SizedBox(height: AppSizes.gap),
        OutlinedButton.icon(
          onPressed: onBackHome,
          icon: const Icon(Icons.home_rounded, size: AppSizes.iconMedium),
          label: Text(strings.backToHome),
        ),
        const SizedBox(height: AppSizes.gapLarge),
      ],
    );
  }
}
