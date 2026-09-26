import 'package:flutter/material.dart';

import '../../l10n/language_scope.dart';
import '../../models/reminder.dart';
import '../../theme/app_sizes.dart';
import '../../theme/app_theme.dart';
import '../../utils/date_formats.dart';
import '../../widgets/reminder_card.dart';
import '../../widgets/section_title.dart';

/// Today's reminders.
///
/// Stateless, like HomeScreen: it draws the list it is given and reports taps
/// upward. MainShell owns the actual data.
class RemindersScreen extends StatelessWidget {
  const RemindersScreen({
    super.key,
    required this.reminders,
    required this.onAddReminder,
    required this.onToggleComplete,
    this.onOpenReminder,
    this.alarmStatus,
    this.onCheckNotifications,
  });

  final List<Reminder> reminders;
  final VoidCallback onAddReminder;

  /// (reminder id, should it be complete?)
  final void Function(int id, bool completed) onToggleComplete;

  final ValueChanged<Reminder>? onOpenReminder;

  /// One short line about whether these reminders will actually ring, or
  /// null while that is still being worked out. A reminder list that quietly
  /// does nothing at the appointed time is worse than no list at all, so the
  /// app says which of the two it is.
  final ReminderAlarmStatus? alarmStatus;

  /// Opens the "are reminders working?" screen.
  final VoidCallback? onCheckNotifications;

  @override
  Widget build(BuildContext context) {
    final strings = LanguageScope.of(context);
    final now = DateTime.now();
    final completed = reminders
        .where((reminder) => reminder.isCompletedOn(now))
        .length;

    return ListView(
      padding: const EdgeInsets.all(AppSizes.pagePadding),
      children: [
        Text(
          strings.todaysReminders,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            const Icon(
              Icons.calendar_today_outlined,
              size: 22,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: AppSizes.gapSmall),
            Expanded(
              child: Text(
                formatFullDate(now),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
        if (alarmStatus != null) ...[
          const SizedBox(height: AppSizes.gapSmall),
          _AlarmStatusLine(
            status: alarmStatus!,
            onTap: onCheckNotifications,
          ),
        ],
        const SizedBox(height: AppSizes.gapLarge),

        // The big obvious button sits ABOVE the list, not hidden in a floating
        // action button in the corner. A FAB is a small circle with no words —
        // exactly the kind of control our users do not recognise.
        FilledButton.icon(
          onPressed: onAddReminder,
          icon: const Icon(Icons.add_rounded, size: 34),
          label: const Text('Add Reminder'),
        ),
        const SizedBox(height: AppSizes.gapLarge),

        if (reminders.isEmpty)
          const _EmptyState()
        else ...[
          _ProgressSummary(completed: completed, total: reminders.length),
          const SizedBox(height: AppSizes.gapLarge),
          const SectionTitle('Your reminders'),
          const SizedBox(height: AppSizes.gap),
          for (final reminder in reminders) ...[
            ReminderCard(
              reminder: reminder,
              day: now,
              onToggleComplete: (isComplete) =>
                  onToggleComplete(reminder.id, isComplete),
              onOpenDetails: onOpenReminder == null
                  ? null
                  : () => onOpenReminder!(reminder),
            ),
            const SizedBox(height: AppSizes.gap),
          ],
        ],
        const SizedBox(height: AppSizes.gap),
      ],
    );
  }
}

/// "2 of 4 completed" with a thick progress bar.
class _ProgressSummary extends StatelessWidget {
  const _ProgressSummary({required this.completed, required this.total});

  final int completed;
  final int total;

  @override
  Widget build(BuildContext context) {
    // Guard against dividing by zero when there are no reminders.
    final fraction = total == 0 ? 0.0 : completed / total;
    final allDone = total > 0 && completed == total;

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
            "Today's progress",
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSizes.gapSmall),
          Text(
            '$completed of $total completed',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryDark,
            ),
          ),
          const SizedBox(height: AppSizes.gap),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: fraction,
              // A default progress bar is 4 pixels tall. That is invisible to
              // an eye that struggles with fine detail.
              minHeight: 16,
              backgroundColor: AppColors.background,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.primary,
              ),
            ),
          ),
          if (allDone) ...[
            const SizedBox(height: AppSizes.gap),
            const Row(
              children: [
                Icon(
                  Icons.celebration_rounded,
                  color: Color(0xFF1B5E20),
                  size: 28,
                ),
                SizedBox(width: AppSizes.gapSmall),
                Expanded(
                  child: Text(
                    'Everything done for today.',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1B5E20),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: AppSizes.gap),
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: AppColors.reminder,
            borderRadius: BorderRadius.circular(26),
          ),
          child: const Icon(
            Icons.alarm_outlined,
            size: 50,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: AppSizes.gapLarge),
        Text(
          'No reminders yet',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: AppSizes.gapSmall),
        Text(
          'Use the button above to add your first one — '
          'a medicine, a meal, or an appointment.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

/// Whether reminders will ring, and why not when they will not.
enum ReminderAlarmStatus {
  /// Android, permission granted, exact alarms available.
  ringing(
    Icons.notifications_active_rounded,
    'These will ring on time, even if the app is closed.',
    AppColors.primaryDark,
  ),

  /// Android, permission granted, but the OS will not promise the minute.
  ringingInexact(
    Icons.notifications_rounded,
    'These will ring, though your phone may delay them by a few minutes.',
    AppColors.primaryDark,
  ),

  /// Android, notifications switched off for the app.
  permissionDenied(
    Icons.notifications_off_rounded,
    'Notifications are off, so these will not ring. Turn them on in '
        'phone Settings.',
    AppColors.reminder,
  ),

  /// Web. A browser cannot wake a closed page at 8 PM.
  unsupported(
    Icons.info_outline_rounded,
    'This is the web version, so reminders are shown here but will not '
        'ring. The Android app rings.',
    AppColors.textSecondary,
  );

  const ReminderAlarmStatus(this.icon, this.message, this.color);

  final IconData icon;
  final String message;
  final Color color;
}

class _AlarmStatusLine extends StatelessWidget {
  const _AlarmStatusLine({required this.status, this.onTap});

  final ReminderAlarmStatus status;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(status.icon, size: 22, color: status.color),
        const SizedBox(width: AppSizes.gapSmall),
        Expanded(
          child: Text(
            status.message,
            style: TextStyle(fontSize: 16, color: status.color),
          ),
        ),
        if (onTap != null)
          Icon(Icons.chevron_right_rounded, size: 24, color: status.color),
      ],
    );

    if (onTap == null) return row;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.radius),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: row,
      ),
    );
  }
}
