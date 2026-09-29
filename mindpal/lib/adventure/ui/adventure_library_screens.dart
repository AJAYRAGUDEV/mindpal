import 'package:flutter/material.dart';

import '../../theme/app_sizes.dart';
import '../../theme/app_theme.dart';
import '../../utils/date_formats.dart';
import '../../widgets/confirm_dialog.dart';
import '../engine/adventure_state.dart';
import '../model/adventure.dart';
import '../storage/adventure_store.dart';

/// Every adventure on the device, ready to play with or without a connection.
class SavedAdventuresScreen extends StatefulWidget {
  const SavedAdventuresScreen({
    super.key,
    required this.store,
    required this.onPlay,
  });

  final AdventureStore store;

  /// [resume] is null for a fresh start.
  final void Function(Adventure adventure, AdventureState? resume) onPlay;

  @override
  State<SavedAdventuresScreen> createState() => _SavedAdventuresScreenState();
}

class _SavedAdventuresScreenState extends State<SavedAdventuresScreen> {
  @override
  Widget build(BuildContext context) {
    final library = widget.store.library();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Saved Adventures')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSizes.pagePadding),
          children: [
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.cloud_off_rounded,
                    size: 22, color: AppColors.textSecondary),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Everything here is stored on this device and plays with '
                    'no internet at all.',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.gap),

            for (final adventure in library) ...[
              _AdventureCard(
                adventure: adventure,
                progress: widget.store.progressFor(adventure.id),
                endingsSeen: widget.store.endingsSeenFor(adventure.id),
                onPlay: (resume) {
                  Navigator.of(context).pop();
                  widget.onPlay(adventure, resume);
                },
                onDelete: adventure.source == AdventureSource.bundled
                    ? null
                    : () => _delete(adventure),
              ),
              const SizedBox(height: AppSizes.gap),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _delete(Adventure adventure) async {
    final confirmed = await confirmDestructiveAction(
      context,
      title: 'Remove "${adventure.title}"?',
      message:
          'It will be deleted from this device, along with how far you got. '
          'The adventure that comes with MindPal is never removed.',
      confirmLabel: 'Remove',
    );
    if (!confirmed) return;

    await widget.store.deleteAdventure(adventure.id);
    if (mounted) setState(() {});
  }
}

class _AdventureCard extends StatelessWidget {
  const _AdventureCard({
    required this.adventure,
    required this.progress,
    required this.endingsSeen,
    required this.onPlay,
    required this.onDelete,
  });

  final Adventure adventure;
  final AdventureState? progress;
  final Set<String> endingsSeen;
  final void Function(AdventureState? resume) onPlay;

  /// Null for the bundled adventure, which cannot be removed — it is what
  /// makes offline play a promise.
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final started = progress != null && !progress!.isFinished;

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
          Text(
            adventure.title,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text(
            '${adventure.culturalNote.festival} — '
            '${adventure.culturalNote.region}',
            style: const TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSizes.gapSmall),

          Row(
            children: [
              Icon(
                adventure.source == AdventureSource.bundled
                    ? Icons.inventory_2_rounded
                    : Icons.auto_awesome_rounded,
                size: 20,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  adventure.source.label,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),

          // How many of the endings this player has seen — the reason to play
          // it again, and the only "collectible" in the game.
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.flag_rounded,
                  size: 20, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${endingsSeen.length} of ${adventure.endings.length} '
                  'endings seen',
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSizes.gap),
          if (started) ...[
            FilledButton.icon(
              onPressed: () => onPlay(progress),
              icon: const Icon(Icons.play_arrow_rounded, size: 26),
              label: const Text('Carry on'),
            ),
            const SizedBox(height: AppSizes.gapSmall),
            OutlinedButton.icon(
              onPressed: () => onPlay(null),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, AppSizes.buttonHeight),
              ),
              icon: const Icon(Icons.replay_rounded, size: 24),
              label: const Text('Start again from the beginning'),
            ),
          ] else
            FilledButton.icon(
              onPressed: () => onPlay(null),
              icon: const Icon(Icons.play_arrow_rounded, size: 26),
              label: const Text('Play'),
            ),

          if (onDelete != null) ...[
            const SizedBox(height: AppSizes.gapSmall),
            OutlinedButton.icon(
              onPressed: onDelete,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error, width: 1.5),
                minimumSize: const Size(0, 52),
              ),
              icon: const Icon(Icons.delete_outline_rounded, size: 22),
              label: const Text('Remove from this device'),
            ),
          ],
        ],
      ),
    );
  }
}

/// My Progress: adventures finished, endings discovered, and nothing else.
///
/// The same rule as everywhere else in MindPal — these are facts about what was
/// played, never a measure of the person. No score, no trend, nothing medical.
class AdventureProgressScreen extends StatelessWidget {
  const AdventureProgressScreen({
    super.key,
    required this.store,
    this.onOpenGameProgress,
  });

  final AdventureStore store;

  /// Opens the record for the quick games. They are a separate history with
  /// separate rules, so they get their own screen rather than being mixed in
  /// with adventures here.
  final VoidCallback? onOpenGameProgress;

  @override
  Widget build(BuildContext context) {
    final runs = store.runs();
    final library = store.library();

    final endingsSeen = <String>{for (final run in runs) run.endingId};
    final totalEndings = library.fold<int>(
      0,
      (sum, adventure) => sum + adventure.endings.length,
    );

    return ListView(
      padding: const EdgeInsets.all(AppSizes.pagePadding),
      children: [
        Text(
          'My Progress',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: AppSizes.gap),

        Row(
          children: [
            Expanded(
              child: _Tally(
                number: '${runs.length}',
                label: runs.length == 1
                    ? 'adventure finished'
                    : 'adventures finished',
                icon: Icons.emoji_events_rounded,
                color: const Color(0xFF1B5E20),
              ),
            ),
            const SizedBox(width: AppSizes.gap),
            Expanded(
              child: _Tally(
                number: '${endingsSeen.length}/$totalEndings',
                label: 'endings discovered',
                icon: Icons.flag_rounded,
                color: AppColors.activity,
              ),
            ),
          ],
        ),

        const SizedBox(height: AppSizes.gapLarge),
        Text(
          'Endings you have found',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppSizes.gapSmall),
        for (final adventure in library) ...[
          _EndingsRow(
            adventure: adventure,
            seen: store.endingsSeenFor(adventure.id),
          ),
          const SizedBox(height: AppSizes.gapSmall),
        ],

        const SizedBox(height: AppSizes.gapLarge),
        Text(
          'Adventures you finished',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppSizes.gapSmall),
        if (runs.isEmpty)
          const Text(
            'None yet. Start one from Festival Quest.',
            style: TextStyle(fontSize: 18, color: AppColors.textSecondary),
          )
        else
          for (final run in runs) ...[
            _RunCard(run: run),
            const SizedBox(height: AppSizes.gapSmall),
          ],
        if (onOpenGameProgress != null) ...[
          const SizedBox(height: AppSizes.gapLarge),
          OutlinedButton.icon(
            onPressed: onOpenGameProgress,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, AppSizes.buttonHeight),
            ),
            icon: const Icon(Icons.videogame_asset_rounded, size: 26),
            label: const Text('Quick game progress'),
          ),
        ],
        const SizedBox(height: AppSizes.gapLarge),
      ],
    );
  }
}

class _EndingsRow extends StatelessWidget {
  const _EndingsRow({required this.adventure, required this.seen});

  final Adventure adventure;
  final Set<String> seen;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radius),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            adventure.title,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          for (final ending in adventure.endings)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Icon(
                    seen.contains(ending.id)
                        ? Icons.check_circle_rounded
                        : Icons.help_outline_rounded,
                    size: 22,
                    color: seen.contains(ending.id)
                        ? const Color(0xFF1B5E20)
                        : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      // An ending not yet reached is not spoiled.
                      seen.contains(ending.id)
                          ? ending.title
                          : 'Not found yet',
                      style: TextStyle(
                        fontSize: 17,
                        color: seen.contains(ending.id)
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _RunCard extends StatelessWidget {
  const _RunCard({required this.run});

  final AdventureRun run;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radius),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            run.title,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            run.endingTitle,
            style: const TextStyle(
              fontSize: 17,
              color: AppColors.primaryDark,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            formatFullDate(run.finishedAt),
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: AppSizes.gap,
            runSpacing: 4,
            children: [
              Text('Clues found: ${run.cluesFound}', style: _fact),
              if (run.styleName.isNotEmpty)
                Text('Arrangement: ${run.styleName}', style: _fact),
              Text('Coins left: ${run.coinsLeft}', style: _fact),
              if (run.hintsUsed > 0)
                Text('Hints: ${run.hintsUsed}', style: _fact),
            ],
          ),
        ],
      ),
    );
  }

  static const TextStyle _fact = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );
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
          Icon(icon, size: 32, color: color),
          const SizedBox(height: 6),
          FittedBox(
            child: Text(
              number,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
