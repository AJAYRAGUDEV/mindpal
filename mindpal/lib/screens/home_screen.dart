import 'package:flutter/material.dart';

import '../content/pack_library.dart';
import '../l10n/app_strings.dart';
import '../l10n/language_scope.dart';
import '../models/game_result.dart';
import '../models/game_settings.dart';
import '../models/game_type.dart';
import '../models/reminder.dart';
import '../models/user_profile.dart';
import '../theme/app_sizes.dart';
import '../theme/app_theme.dart';
import '../utils/date_formats.dart';
import '../widgets/section_title.dart';
import 'main_shell.dart' show AppTab;

/// Elder Mode home, now led by games.
///
/// The order on this screen is the product decision: playing is what MindPal is
/// for, so Play games is the largest thing here, Continue playing sits directly
/// under it, and the games themselves are listed with what they are and how hard
/// they are set. Memories, reminders and the family tools follow in a smaller
/// section — still one tap away, no longer competing for the same attention.
///
/// **Why the game rows here open the Games tab rather than starting a game.**
/// Launching a game means choosing a pack, building its tiles, pushing a route
/// and filing the result afterwards. That lives in MindPalScreen. Duplicating it
/// here would be a second place for a launch bug to hide, so these rows say
/// "Open" and do exactly that. The Play button is in the one place that owns it.
///
/// It stays a StatelessWidget: it owns nothing and renders exactly what it is
/// given. Every count comes from MainShell.
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.profile,
    required this.reminders,
    required this.gameHistory,
    required this.gameSettings,
    required this.onQuickAction,
    required this.onOpenAssistant,
  });

  final UserProfile profile;

  /// Read-only here; MainShell owns the list.
  final List<Reminder> reminders;
  final List<GameResult> gameHistory;

  /// For the difficulty shown on the game rows and the pack named below them.
  final GameSettings gameSettings;

  final ValueChanged<int> onQuickAction;
  final VoidCallback onOpenAssistant;

  /// The games offered on Home, in the order they are offered.
  ///
  /// The cultural three first, then the one built from the player's own photos.
  /// Sequence Recall and Memory Moment are in the Games tab; four rows is
  /// already the most this screen can carry without becoming a list.
  static const List<(GameType, String)> _featured = [
    (
      GameType.memoryMatch,
      'Match pairs of instruments, foods and handmade things.',
    ),
    (
      GameType.folkStorySequence,
      'Hear a short story, then put its scenes in order.',
    ),
    (GameType.oddOneOut, 'Find the one that does not belong with the others.'),
    (GameType.familyPhotoMatch, 'Match pairs made from your own photos.'),
  ];

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
    final last = _lastPlayed;

    return ListView(
      padding: const EdgeInsets.all(AppSizes.pagePadding),
      children: [
        _Greeting(profile: profile, now: now, strings: strings),
        const SizedBox(height: AppSizes.gapLarge),

        // The one biggest thing on the screen.
        _BigActionButton(
          icon: Icons.videogame_asset_rounded,
          label: strings.playAGame,
          color: AppColors.activity,
          onPressed: () => onQuickAction(AppTab.mindPal),
        ),

        if (last != null) ...[
          const SizedBox(height: AppSizes.gap),
          _ContinueRow(
            result: last,
            onTap: () => onQuickAction(AppTab.mindPal),
          ),
        ],

        const SizedBox(height: AppSizes.gapLarge),
        const SectionTitle('Games'),
        const SizedBox(height: AppSizes.gap),
        for (final (gameType, description) in _featured) ...[
          _GameRow(
            gameType: gameType,
            description: description,
            difficultyLabel: gameSettings.difficulty.label,
            onTap: () => onQuickAction(AppTab.mindPal),
          ),
          const SizedBox(height: AppSizes.gapSmall),
        ],
        const SizedBox(height: 4),
        _PackLine(
          packTitle: packFor(gameSettings.packId).title,
          onTap: () => onQuickAction(AppTab.mindPal),
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

        // Everything that is not a game, kept together and smaller.
        const SizedBox(height: AppSizes.gapLarge),
        const SectionTitle('Also here'),
        const SizedBox(height: AppSizes.gap),
        _SmallActionRow(
          icon: Icons.photo_album_rounded,
          label: strings.myMemories,
          color: AppColors.memory,
          onTap: () => onQuickAction(AppTab.memory),
        ),
        const SizedBox(height: AppSizes.gapSmall),
        _SmallActionRow(
          icon: Icons.alarm_rounded,
          label: strings.myReminders,
          color: AppColors.reminder,
          onTap: () => onQuickAction(AppTab.reminders),
        ),
        const SizedBox(height: AppSizes.gapSmall),
        _SmallActionRow(
          icon: Icons.people_alt_rounded,
          label: 'People who help me',
          color: AppColors.primary,
          onTap: () => onQuickAction(AppTab.profile),
        ),
        const SizedBox(height: AppSizes.gapSmall),
        _SmallActionRow(
          icon: Icons.question_answer_rounded,
          label: strings.memoryAssistant,
          color: AppColors.primaryDark,
          onTap: onOpenAssistant,
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

  /// The most recent session, finished or not. Null before anything is played.
  GameResult? get _lastPlayed {
    if (gameHistory.isEmpty) return null;
    final sorted = [...gameHistory]
      ..sort((a, b) => b.playedAt.compareTo(a.playedAt));
    return sorted.first;
  }

  /// The next two reminders still due today, soonest first.
  ///
  /// Only two: a long list on the home screen is the clutter this design is
  /// trying to avoid. The Reminders tab has the full list.
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

/// "Continue playing Cultural Memory Match".
class _ContinueRow extends StatelessWidget {
  const _ContinueRow({required this.result, required this.onTap});

  final GameResult result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Continue playing ${result.gameType.label}',
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(AppSizes.radius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSizes.radius),
          child: Container(
            constraints: const BoxConstraints(
              minHeight: AppSizes.minTouchTarget,
            ),
            padding: const EdgeInsets.all(AppSizes.cardPadding),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSizes.radius),
              border: Border.all(color: AppColors.primary, width: 2),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.play_circle_fill_rounded,
                  size: 40,
                  color: AppColors.primary,
                ),
                const SizedBox(width: AppSizes.gap),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Continue playing',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryDark,
                        ),
                      ),
                      Text(
                        result.gameType.label,
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 30,
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

/// One game: what it is called, what it is, and how hard it is set.
class _GameRow extends StatelessWidget {
  const _GameRow({
    required this.gameType,
    required this.description,
    required this.difficultyLabel,
    required this.onTap,
  });

  final GameType gameType;
  final String description;
  final String difficultyLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${gameType.label}. $description Difficulty $difficultyLabel.',
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSizes.radius),
          child: Container(
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
                    color: gameType.color,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(gameType.icon, size: 30, color: Colors.white),
                ),
                const SizedBox(width: AppSizes.gap),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        gameType.label,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        description,
                        style: const TextStyle(
                          fontSize: 16,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Difficulty: $difficultyLabel',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 28,
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

/// Which cultural pack the games are using, and a way to change it.
class _PackLine extends StatelessWidget {
  const _PackLine({required this.packTitle, required this.onTap});

  final String packTitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            const Icon(
              Icons.public_rounded,
              size: 22,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: AppSizes.gapSmall),
            Expanded(
              child: Text(
                'Pictures from: $packTitle',
                style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const Text(
              'Change',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One of the non-game destinations: smaller than the Play button, still a
/// comfortable touch target and still labelled in words.
class _SmallActionRow extends StatelessWidget {
  const _SmallActionRow({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSizes.radius),
          child: Container(
            constraints: const BoxConstraints(
              minHeight: AppSizes.minTouchTarget,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSizes.radius),
              border: Border.all(color: AppColors.border, width: 1.5),
            ),
            child: Row(
              children: [
                Icon(icon, size: 30, color: color),
                const SizedBox(width: AppSizes.gap),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 26,
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
