import 'package:flutter/material.dart';

import '../models/game_result.dart';
import '../theme/app_sizes.dart';
import '../theme/app_theme.dart';

/// The "you finished" screen, shared by all three games.
///
/// Your brief said game-over screens must not be confusing, so this one:
///   * never says "Game Over" or "You lose",
///   * leads with encouragement, not the number,
///   * shows exactly three facts,
///   * offers exactly two large buttons, and no way to get stuck.
class GameResultPanel extends StatelessWidget {
  const GameResultPanel({
    super.key,
    required this.result,
    required this.onPlayAgain,
    required this.onBackToGames,
    this.headline,
    this.subtitle,
    this.icon = Icons.check_rounded,
    this.iconColor = const Color(0xFF1B5E20),
    this.extraStats = const {},
  });

  final GameResult result;
  final VoidCallback onPlayAgain;
  final VoidCallback onBackToGames;

  /// Overrides the default congratulation line.
  final String? headline;

  /// Overrides the default "You finished X on Y" line.
  final String? subtitle;

  /// Sequence Recall ends when the tries run out, and a green tick would read
  /// as "you won". Games can pass a gentler symbol instead.
  final IconData icon;
  final Color iconColor;

  /// Extra game-specific facts, e.g. {'Longest sequence': '5'}.
  final Map<String, String> extraStats;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.gap),
      child: Column(
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: iconColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 56, color: Colors.white),
          ),
          const SizedBox(height: AppSizes.gap),
          Text(
            headline ?? 'Well done!',
            textAlign: TextAlign.center,
            style: textTheme.headlineSmall,
          ),
          const SizedBox(height: AppSizes.gapSmall),
          Text(
            subtitle ??
                'You finished ${result.gameType.label} on '
                    '${result.difficulty.label}.',
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSizes.gapLarge),

          _ResultRow(label: 'Your score', value: '${result.score}', big: true),
          _ResultRow(label: 'Time taken', value: result.formattedDuration),
          _ResultRow(label: 'Mistakes', value: '${result.mistakes}'),
          for (final entry in extraStats.entries)
            _ResultRow(label: entry.key, value: entry.value),

          const SizedBox(height: AppSizes.gapLarge),
          FilledButton.icon(
            onPressed: onPlayAgain,
            icon: const Icon(Icons.replay_rounded, size: AppSizes.iconMedium),
            label: const Text('Play again'),
          ),
          const SizedBox(height: AppSizes.gap),
          OutlinedButton.icon(
            onPressed: onBackToGames,
            icon: const Icon(Icons.grid_view_rounded, size: AppSizes.iconMedium),
            label: const Text('Back to games'),
          ),
          const SizedBox(height: AppSizes.gap),
        ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.label, required this.value, this.big = false});

  final String label;
  final String value;
  final bool big;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 20,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: AppSizes.gap),
          Text(
            value,
            style: TextStyle(
              fontSize: big ? 34 : 22,
              fontWeight: FontWeight.w700,
              color: big ? AppColors.primaryDark : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
