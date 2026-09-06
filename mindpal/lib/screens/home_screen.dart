import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../l10n/language_scope.dart';
import '../models/game_result.dart';
import '../models/reminder.dart';
import '../models/user_profile.dart';
import '../theme/app_sizes.dart';
import '../theme/app_theme.dart';
import '../utils/date_formats.dart';
import '../widgets/section_title.dart';
import 'main_shell.dart' show AppTab;

/// Elder Mode home.
///
/// Rebuilt on Day 5 around one idea: an elderly user opening this app should
/// see four large things they can do, and two short facts about their day.
/// The previous version had three description cards plus three buttons, which
/// said a lot but offered little.
///
/// It stays a StatelessWidget: it owns nothing and renders exactly what it is
/// given. All four counts come from MainShell.
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.profile,
    required this.reminders,
    required this.gameHistory,
    required this.onQuickAction,
    required this.onOpenAssistant,
  });

  final UserProfile profile;

  /// Read-only here; MainShell owns the list.
  final List<Reminder> reminders;
  final List<GameResult> gameHistory;

  final ValueChanged<int> onQuickAction;
  final VoidCallback onOpenAssistant;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final strings = LanguageScope.of(context);

    final completedToday = gameHistory
        .where((result) => result.isOnSameDayAs(now) && result.completed)
        .length;

    final remindersToday = reminders.length;
    final remindersDone = reminders
        .where((reminder) => reminder.isCompletedOn(now))
        .length;
    final remindersLeft = remindersToday - remindersDone;

    final upcoming = _upcomingReminders(now);

    return ListView(
      padding: const EdgeInsets.all(AppSizes.pagePadding),
      children: [
        _Greeting(profile: profile, now: now, strings: strings),
        const SizedBox(height: AppSizes.gapLarge),

        // The four things you can do. Nothing else competes with them.
        _BigActionButton(
          icon: Icons.videogame_asset_rounded,
          label: strings.playAGame,
          color: AppColors.activity,
          onPressed: () => onQuickAction(AppTab.mindPal),
        ),
        const SizedBox(height: AppSizes.gap),
        _BigActionButton(
          icon: Icons.photo_album_rounded,
          label: strings.myMemories,
          color: AppColors.memory,
          onPressed: () => onQuickAction(AppTab.memory),
        ),
        const SizedBox(height: AppSizes.gap),
        _BigActionButton(
          icon: Icons.alarm_rounded,
          label: strings.myReminders,
          color: AppColors.reminder,
          onPressed: () => onQuickAction(AppTab.reminders),
        ),
        const SizedBox(height: AppSizes.gap),
        _BigActionButton(
          icon: Icons.question_answer_rounded,
          label: strings.memoryAssistant,
          color: AppColors.primary,
          onPressed: onOpenAssistant,
        ),

        const SizedBox(height: AppSizes.gapLarge),
        SectionTitle(strings.todaysActivity),
        const SizedBox(height: AppSizes.gap),
        _SummaryCard(
          icon: Icons.psychology_rounded,
          color: AppColors.activity,
          text: completedToday == 0
              ? strings.noActivityYet
              : '$completedToday ${strings.activitiesCompleted}',
          onTap: () => onQuickAction(AppTab.mindPal),
        ),

        const SizedBox(height: AppSizes.gapLarge),
        SectionTitle(strings.upcoming),
        const SizedBox(height: AppSizes.gap),
        if (remindersToday == 0)
          _SummaryCard(
            icon: Icons.alarm_off_rounded,
            color: AppColors.textSecondary,
            text: strings.noRemindersToday,
            onTap: () => onQuickAction(AppTab.reminders),
          )
        else if (upcoming.isEmpty)
          _SummaryCard(
            icon: Icons.check_circle_rounded,
            color: const Color(0xFF1B5E20),
            text: remindersLeft == 0
                ? strings.allDoneToday
                : '$remindersLeft ${strings.remindersRemaining}',
            onTap: () => onQuickAction(AppTab.reminders),
          )
        else
          for (final reminder in upcoming) ...[
            _UpcomingRow(
              reminder: reminder,
              onTap: () => onQuickAction(AppTab.reminders),
            ),
            const SizedBox(height: AppSizes.gap),
          ],

        const SizedBox(height: AppSizes.gapLarge),
      ],
    );
  }

  /// The next two reminders still due today, soonest first.
  ///
  /// Only two: a long list on the home screen is the clutter this redesign is
  /// trying to remove. The Reminders tab has the full list.
  List<Reminder> _upcomingReminders(DateTime now) {
    final due = reminders
        .where(
          (reminder) =>
              !reminder.isCompletedOn(now) &&
              reminder.scheduledOn(now).isAfter(now),
        )
        .toList()
      ..sort((a, b) => a.minutesOfDay.compareTo(b.minutesOfDay));

    return due.take(2).toList();
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({
    required this.profile,
    required this.now,
    required this.strings,
  });

  final UserProfile profile;
  final DateTime now;
  final AppStrings strings;

  /// The decision (morning / afternoon / evening) is made here; the words come
  /// from the string table, so the greeting is translated.
  String get _greeting {
    if (now.hour < 12) return strings.greetingMorning;
    if (now.hour < 17) return strings.greetingAfternoon;
    return strings.greetingEvening;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$_greeting,', style: textTheme.headlineSmall),
        Text(
          profile.hasName ? profile.name.trim() : strings.friend,
          style: textTheme.displaySmall?.copyWith(color: AppColors.primaryDark),
        ),
        const SizedBox(height: AppSizes.gapSmall),
        Row(
          children: [
            const Icon(
              Icons.calendar_today_outlined,
              size: 22,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: AppSizes.gapSmall),
            Expanded(
              child: Text(formatFullDate(now), style: textTheme.bodyMedium),
            ),
          ],
        ),
      ],
    );
  }
}

/// A very large, single-purpose button. Icon block on the left, words next to
/// it, nothing else on the row.
class _BigActionButton extends StatelessWidget {
  const _BigActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onPressed,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radius),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppSizes.radius),
          child: Container(
            height: 96,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSizes.radius),
              border: Border.all(color: color, width: 2.5),
            ),
            child: Row(
              children: [
                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, size: 34, color: Colors.white),
                ),
                const SizedBox(width: AppSizes.gap),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 32,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.icon,
    required this.color,
    required this.text,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppSizes.radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radius),
        child: Container(
          constraints: const BoxConstraints(minHeight: AppSizes.minTouchTarget),
          padding: const EdgeInsets.all(AppSizes.cardPadding),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSizes.radius),
            border: Border.all(color: AppColors.border, width: 1.5),
          ),
          child: Row(
            children: [
              Icon(icon, size: 34, color: color),
              const SizedBox(width: AppSizes.gap),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UpcomingRow extends StatelessWidget {
  const _UpcomingRow({required this.reminder, required this.onTap});

  final Reminder reminder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppSizes.radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radius),
        child: Container(
          padding: const EdgeInsets.all(AppSizes.cardPadding),
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
                  color: reminder.category.color,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  reminder.category.icon,
                  size: 30,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: AppSizes.gap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reminder.title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      reminder.formattedTime,
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
        ),
      ),
    );
  }
}
