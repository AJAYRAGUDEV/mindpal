import 'package:flutter/material.dart';

import '../models/difficulty.dart';
import '../models/game_type.dart';
import '../theme/app_sizes.dart';
import '../theme/app_theme.dart';

/// One game's card on the hub: icon, name, description, difficulty, Play.
class GameCard extends StatelessWidget {
  const GameCard({
    super.key,
    required this.gameType,
    required this.difficulty,
    required this.onPlay,
    this.enabled = true,
    this.comingSoonLabel = 'Coming soon',
    this.title,
    this.description,
    this.playLabel,
  });

  final GameType gameType;
  final Difficulty difficulty;
  final VoidCallback onPlay;

  /// False while a game is not built yet. The card still shows, so the user
  /// sees what is coming, but the button is clearly inactive.
  final bool enabled;
  final String comingSoonLabel;

  /// Translated text. When null the card falls back to the English strings
  /// carried by GameType — which is still the case for the two older games,
  /// whose names are not localised yet.
  final String? title;
  final String? description;
  final String? playLabel;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: enabled ? gameType.color : AppColors.textSecondary,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(gameType.icon, size: 36, color: Colors.white),
              ),
              const SizedBox(width: AppSizes.gap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title ?? gameType.label, style: textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(
                      description ?? gameType.description,
                      style: textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.gap),
          Row(
            children: [
              _DifficultyChip(difficulty: difficulty),
              const Spacer(),
            ],
          ),
          const SizedBox(height: AppSizes.gap),
          if (enabled)
            FilledButton.icon(
              onPressed: onPlay,
              icon: const Icon(
                Icons.play_arrow_rounded,
                size: AppSizes.iconMedium,
              ),
              label: Text(playLabel ?? 'Play ${gameType.label}'),
            )
          else
            // A disabled FilledButton looks broken. An explicit, calm label is
            // clearer: nothing is wrong, it simply is not ready.
            Container(
              height: AppSizes.buttonHeight,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border, width: 2),
              ),
              child: Text(
                comingSoonLabel,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DifficultyChip extends StatelessWidget {
  const _DifficultyChip({required this.difficulty});

  final Difficulty difficulty;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        'Difficulty: ${difficulty.label}',
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: AppColors.primaryDark,
        ),
      ),
    );
  }
}
