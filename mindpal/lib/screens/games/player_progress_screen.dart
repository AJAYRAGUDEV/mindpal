import 'package:flutter/material.dart';

import '../../content/pack_library.dart';
import '../../models/game_result.dart';
import '../../models/game_type.dart';
import '../../theme/app_sizes.dart';
import '../../theme/app_theme.dart';
import '../../utils/date_formats.dart';
import '../../widgets/section_title.dart';

/// What the player has played.
///
/// **What this screen deliberately is not.** There is no chart of scores over
/// time, no percentage, no "improving" or "declining", no stage, no comparison
/// with anyone else, and no interpretation of any kind. Those would all be a
/// cognitive assessment produced by a game, which this app must never present —
/// and a trend line drawn from four sessions of a matching game would be noise
/// dressed up as a diagnosis.
///
/// What it does show is a record of what happened: which games, which pack,
/// which level, when, and the plain counts. That is genuinely useful to a
/// player ("did I play today?") and to a family member, and it is all true.
class PlayerProgressScreen extends StatelessWidget {
  const PlayerProgressScreen({super.key, required this.history});

  final List<GameResult> history;

  @override
  Widget build(BuildContext context) {
    final finished = [
      for (final result in history)
        if (result.completed) result,
    ]..sort((a, b) => b.playedAt.compareTo(a.playedAt));

    // Kept separate, not mixed in and not hidden. Starting a game and stopping
    // is a normal thing to do, and it is not a failure to be tallied against
    // anyone — it is simply a different kind of entry.
    final unfinished = [
      for (final result in history)
        if (!result.completed) result,
    ]..sort((a, b) => b.playedAt.compareTo(a.playedAt));

    final gamesEnjoyed = <GameType>{
      for (final result in finished) result.gameType,
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Your progress')),
      body: SafeArea(
        child: history.isEmpty
            ? const _Empty()
            : ListView(
                padding: const EdgeInsets.all(AppSizes.pagePadding),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _Tally(
                          number: '${finished.length}',
                          label: finished.length == 1
                              ? 'game finished'
                              : 'games finished',
                          icon: Icons.check_circle_rounded,
                          color: const Color(0xFF1B5E20),
                        ),
                      ),
                      const SizedBox(width: AppSizes.gap),
                      Expanded(
                        child: _Tally(
                          number: '${gamesEnjoyed.length}',
                          label: gamesEnjoyed.length == 1
                              ? 'different game'
                              : 'different games',
                          icon: Icons.videogame_asset_rounded,
                          color: AppColors.activity,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSizes.gapLarge),

                  const SectionTitle('Games you finished'),
                  const SizedBox(height: AppSizes.gap),
                  if (finished.isEmpty)
                    const _Note(
                      'No finished games yet. Every game counts as finished '
                      'once you reach the end of it.',
                    )
                  else
                    for (final result in finished) ...[
                      _SessionCard(result: result),
                      const SizedBox(height: AppSizes.gapSmall),
                    ],

                  if (unfinished.isNotEmpty) ...[
                    const SizedBox(height: AppSizes.gapLarge),
                    const SectionTitle('Games you started'),
                    const SizedBox(height: AppSizes.gap),
                    const _Note(
                      'These were stopped part way through. That is perfectly '
                      'fine — they are kept separately so the list above is '
                      'only the games you saw through to the end.',
                    ),
                    const SizedBox(height: AppSizes.gap),
                    for (final result in unfinished) ...[
                      _SessionCard(result: result),
                      const SizedBox(height: AppSizes.gapSmall),
                    ],
                  ],
                  const SizedBox(height: AppSizes.gapLarge),
                ],
              ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSizes.pagePadding),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.videogame_asset_outlined,
            size: 88,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: AppSizes.gap),
          Text(
            'Nothing here yet',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: AppSizes.gapSmall),
          const Text(
            'Play a game and it will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 19, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _Tally extends StatelessWidget {
  const _Tally({
    required this.number,
    required this.label,
    required this.icon,
    required this.color,
  });

  final String number;
  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radius),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      child: Column(
        children: [
          Icon(icon, size: 34, color: color),
          const SizedBox(height: 6),
          Text(
            number,
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// One session, as facts.
class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.result});

  final GameResult result;

  @override
  Widget build(BuildContext context) {
    final pack = packById(result.packId);

    return Container(
      padding: const EdgeInsets.all(AppSizes.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radius),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: result.gameType.color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  result.gameType.icon,
                  size: 26,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: AppSizes.gap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.gameType.label,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '${result.difficulty.label}'
                      '${pack == null ? "" : " — ${pack.title}"}',
                      style: const TextStyle(
                        fontSize: 16,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.gapSmall),
          Text(
            formatFullDate(result.playedAt),
            style: const TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSizes.gapSmall),
          Wrap(
            spacing: AppSizes.gap,
            runSpacing: 4,
            children: [
              if (result.correct > 0) _Fact('Right: ${result.correct}'),
              _Fact('Tries that missed: ${result.mistakes}'),
              if (result.hintsUsed > 0) _Fact('Hints: ${result.hintsUsed}'),
              _Fact('Time: ${result.formattedDuration}'),
              _Fact('Score: ${result.score}'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 17,
        height: 1.4,
        color: AppColors.textSecondary,
      ),
    );
  }
}
