import 'package:flutter/material.dart';

import '../l10n/language_scope.dart';
import '../models/reminder.dart';
import '../theme/app_sizes.dart';
import '../theme/app_theme.dart';

/// One reminder in the list.
///
/// Shows the category icon, the title, the time, how often it repeats, its
/// status, and one large action button.
class ReminderCard extends StatelessWidget {
  const ReminderCard({
    super.key,
    required this.reminder,
    required this.day,
    required this.onToggleComplete,
    this.onOpenDetails,
  });

  final Reminder reminder;

  /// The day being shown — normally today. Passed in rather than read from
  /// the clock inside, so the widget stays predictable and testable.
  final DateTime day;

  final ValueChanged<bool> onToggleComplete;
  final VoidCallback? onOpenDetails;

  static const Color _doneGreen = Color(0xFF1B5E20);
  static const Color _doneFill = Color(0xFFE3F1E4);

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isDone = reminder.isCompletedOn(day);
    final isMissed = reminder.isMissedAt(day);

    return Container(
      decoration: BoxDecoration(
        color: isDone ? _doneFill : AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radius),
        border: Border.all(
          color: isDone ? _doneGreen : AppColors.border,
          width: isDone ? 2 : 1.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppSizes.radius),
        child: InkWell(
          onTap: onOpenDetails,
          borderRadius: BorderRadius.circular(AppSizes.radius),
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: reminder.category.color,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Icon(
                        reminder.category.icon,
                        size: 34,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: AppSizes.gap),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(reminder.title, style: textTheme.titleLarge),
                          const SizedBox(height: 4),
                          Text(
                            // "10:00 AM  ·  Daily"
                            '${reminder.formattedTime}  ·  ${reminder.repeat.localisedLabel(LanguageScope.of(context))}',
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (reminder.notes.trim().isNotEmpty) ...[
                  const SizedBox(height: AppSizes.gapSmall),
                  Text(reminder.notes, style: textTheme.bodyMedium),
                ],
                const SizedBox(height: AppSizes.gap),
                _StatusRow(isDone: isDone, isMissed: isMissed),
                const SizedBox(height: AppSizes.gap),
                if (isDone)
                  OutlinedButton.icon(
                    onPressed: () => onToggleComplete(false),
                    icon: const Icon(Icons.undo_rounded, size: 26),
                    label: const Text('Undo'),
                  )
                else
                  FilledButton.icon(
                    onPressed: () => onToggleComplete(true),
                    icon: const Icon(Icons.check_rounded, size: 30),
                    label: const Text('Complete'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The status line: Completed / Missed / Due later.
///
/// "Missed" is stated plainly and calmly — no red, no warning triangle, no
/// exclamation mark. A missed reminder is information, not a telling-off, and
/// it can still be completed.
class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.isDone, required this.isMissed});

  final bool isDone;
  final bool isMissed;

  @override
  Widget build(BuildContext context) {
    final (IconData icon, String label, Color color) = switch ((
      isDone,
      isMissed,
    )) {
      (true, _) => (
        Icons.check_circle_rounded,
        'Completed',
        ReminderCard._doneGreen,
      ),
      (false, true) => (
        Icons.history_rounded,
        'Missed — you can still complete it',
        AppColors.reminder,
      ),
      (false, false) => (
        Icons.schedule_rounded,
        'Due later today',
        AppColors.textSecondary,
      ),
    };

    return Row(
      children: [
        Icon(icon, size: 26, color: color),
        const SizedBox(width: AppSizes.gapSmall),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}
