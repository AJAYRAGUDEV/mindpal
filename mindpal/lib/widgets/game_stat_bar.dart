import 'package:flutter/material.dart';

import '../theme/app_sizes.dart';
import '../theme/app_theme.dart';

/// One number shown during play, e.g. ("Moves", "6").
class GameStat {
  const GameStat(this.label, this.value);

  final String label;
  final String value;
}

/// The live scoreboard strip at the top of every game.
///
/// Values are large; labels are small and quiet. A player glancing at this mid
/// game should be able to read the number without reading the word.
class GameStatBar extends StatelessWidget {
  const GameStatBar({super.key, required this.stats});

  final List<GameStat> stats;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radius),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      child: Row(
        children: [
          for (final stat in stats)
            Expanded(
              child: Column(
                children: [
                  Text(
                    stat.value,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    stat.label,
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppColors.textSecondary,
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
