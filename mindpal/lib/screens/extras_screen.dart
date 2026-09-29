import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../theme/app_sizes.dart';
import '../theme/app_theme.dart';

/// The things that are not the game.
///
/// Reminders, the memory vault and the caregiver tools all still work exactly
/// as they did — they have simply stopped competing with the adventure for the
/// front of the app. **None of them is required to play.** In particular a
/// player never has to link a caregiver, or be linked to one, to start an
/// adventure: that setting now lives in here with everything else optional.
class ExtrasScreen extends StatelessWidget {
  const ExtrasScreen({
    super.key,
    required this.strings,
    required this.onOpenReminders,
    required this.onOpenMemories,
    required this.onOpenProfile,
    required this.onOpenAssistant,
    this.onOpenVoice,
    this.reminderCount = 0,
  });

  final AppStrings strings;
  final VoidCallback onOpenReminders;
  final VoidCallback onOpenMemories;
  final VoidCallback onOpenProfile;
  final VoidCallback onOpenAssistant;

  /// Null in builds with no speech controller at all, in which case the row is
  /// absent rather than opening a screen with nothing on it.
  final VoidCallback? onOpenVoice;

  final int reminderCount;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSizes.pagePadding),
      children: [
        Text('Extras', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        const Text(
          'Everything that is not a game. You do not need any of it to play.',
          style: TextStyle(fontSize: 18, color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSizes.gapLarge),

        _ExtraRow(
          icon: Icons.alarm_rounded,
          label: strings.myReminders,
          detail: reminderCount == 0
              ? 'Nothing set'
              : reminderCount == 1
              ? 'One reminder'
              : '$reminderCount reminders',
          color: AppColors.reminder,
          onTap: onOpenReminders,
        ),
        const SizedBox(height: AppSizes.gap),
        _ExtraRow(
          icon: Icons.photo_album_rounded,
          label: strings.myMemories,
          detail: 'Photos, people, places and notes',
          color: AppColors.memory,
          onTap: onOpenMemories,
        ),
        const SizedBox(height: AppSizes.gap),
        _ExtraRow(
          icon: Icons.question_answer_rounded,
          label: strings.memoryAssistant,
          detail: 'Ask a question. Needs an internet connection.',
          color: AppColors.primary,
          onTap: onOpenAssistant,
        ),
        if (onOpenVoice != null) ...[
          const SizedBox(height: AppSizes.gap),
          _ExtraRow(
            icon: Icons.record_voice_over_rounded,
            label: 'The reading voice',
            detail: 'Choose which voice reads things aloud, and hear it first',
            color: AppColors.activity,
            onTap: onOpenVoice!,
          ),
        ],
        const SizedBox(height: AppSizes.gap),
        _ExtraRow(
          icon: Icons.person_rounded,
          label: strings.titleProfile,
          detail: 'Your name, your language, and people who help you',
          color: AppColors.primaryDark,
          onTap: onOpenProfile,
        ),
        const SizedBox(height: AppSizes.gapLarge),
      ],
    );
  }
}

class _ExtraRow extends StatelessWidget {
  const _ExtraRow({
    required this.icon,
    required this.label,
    required this.detail,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String detail;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label. $detail',
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSizes.radius),
          child: Container(
            constraints: const BoxConstraints(minHeight: 84),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSizes.radius),
              border: Border.all(color: AppColors.border, width: 1.5),
            ),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, size: 30, color: Colors.white),
                ),
                const SizedBox(width: AppSizes.gap),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        detail,
                        style: const TextStyle(
                          fontSize: 16,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    size: 28, color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
