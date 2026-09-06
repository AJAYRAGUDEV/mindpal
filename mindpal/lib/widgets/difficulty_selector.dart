import 'package:flutter/material.dart';

import '../models/difficulty.dart';
import '../theme/app_sizes.dart';
import '../theme/app_theme.dart';

/// Three big buttons: Easy / Medium / Hard.
///
/// Deliberately NOT a dropdown or a slider. A dropdown hides the options until
/// tapped and a slider needs a drag gesture — both are poor choices for our
/// users. Three visible buttons means the choice, and the current answer, are
/// obvious at a glance.
class DifficultySelector extends StatelessWidget {
  const DifficultySelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final Difficulty selected;
  final ValueChanged<Difficulty> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final difficulty in Difficulty.values) ...[
          Expanded(
            child: _DifficultyButton(
              difficulty: difficulty,
              isSelected: difficulty == selected,
              onTap: () => onChanged(difficulty),
            ),
          ),
          if (difficulty != Difficulty.values.last)
            const SizedBox(width: AppSizes.gapSmall),
        ],
      ],
    );
  }
}

class _DifficultyButton extends StatelessWidget {
  const _DifficultyButton({
    required this.difficulty,
    required this.isSelected,
    required this.onTap,
  });

  final Difficulty difficulty;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      // `selected` makes TalkBack announce "Easy, selected" instead of leaving
      // the user to guess which of the three is active.
      selected: isSelected,
      button: true,
      child: Material(
        color: isSelected ? AppColors.primary : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.border,
                width: 2,
              ),
            ),
            child: Text(
              difficulty.label,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
