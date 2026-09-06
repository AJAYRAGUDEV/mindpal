import 'package:flutter/material.dart';

import '../models/game_result.dart';
import '../models/reminder.dart';
import '../theme/app_theme.dart';
import 'memory_aid_service.dart';

/// What tapping a suggestion should do.
enum SuggestionAction {
  /// Send [AiSuggestion.prompt] to the companion as if the user typed it.
  ask,

  /// Leave the chat and open a part of the app.
  openGames,
  openReminders,
  openMemoryAid,
}

/// One chip offered above the chat box.
class AiSuggestion {
  const AiSuggestion({
    required this.label,
    required this.icon,
    required this.action,
    this.prompt = '',
    this.color = AppColors.primary,
  });

  /// Shown on the chip.
  final String label;

  final IconData icon;
  final SuggestionAction action;

  /// The question to ask, for [SuggestionAction.ask].
  final String prompt;

  final Color color;
}

/// Builds the suggestion chips from what the user has actually saved.
///
/// Deterministic on purpose. Calling Gemini to decide which buttons to draw
/// would cost a request, need a network, and add latency before the user has
/// typed anything — for a decision that is a handful of if-statements.
///
/// The rule that matters: **never suggest a question the app cannot answer.**
/// Offering "Who is Rahul?" to someone with an empty vault teaches them the
/// assistant is broken. Every chip below is only produced when the data behind
/// it exists.
class AiSuggestionService {
  const AiSuggestionService();

  /// At most this many chips. More than four is a wall of choices, which is
  /// the opposite of helpful for the user this app is for.
  static const int maxSuggestions = 4;

  List<AiSuggestion> suggestionsFor({
    required MemoryAidData data,
    required List<Reminder> reminders,
    required List<GameResult> history,
    required DateTime now,
  }) {
    final suggestions = <AiSuggestion>[];

    // 1. An empty vault gets one job, not a menu.
    if (data.isEmpty) {
      return const [
        AiSuggestion(
          label: 'Save your first person',
          icon: Icons.person_add_alt_1_rounded,
          action: SuggestionAction.openMemoryAid,
          color: AppColors.activity,
        ),
        AiSuggestion(
          label: "Let's play a memory game",
          icon: Icons.videogame_asset_rounded,
          action: SuggestionAction.openGames,
        ),
      ];
    }

    // 2. People: name a real one, because a question about a real person is
    //    the clearest possible demonstration that this works.
    if (data.people.isNotEmpty) {
      final person = data.people.first.name.trim();
      suggestions.add(
        person.isEmpty
            ? const AiSuggestion(
                label: 'Tell me about my saved people',
                icon: Icons.people_alt_rounded,
                action: SuggestionAction.ask,
                prompt: 'Tell me about my family',
                color: AppColors.activity,
              )
            : AiSuggestion(
                label: 'Who is $person?',
                icon: Icons.person_rounded,
                action: SuggestionAction.ask,
                prompt: 'Who is $person?',
                color: AppColors.activity,
              ),
      );
    }

    // 3. Places.
    if (data.places.isNotEmpty) {
      suggestions.add(
        const AiSuggestion(
          label: 'What places have I saved?',
          icon: Icons.place_rounded,
          action: SuggestionAction.ask,
          prompt: 'What places have I saved?',
        ),
      );
    }

    // 4. Reminders — only when there is something left to do today.
    final pending = reminders
        .where((reminder) => !reminder.isCompletedOn(now))
        .length;
    if (pending > 0) {
      suggestions.add(
        const AiSuggestion(
          label: 'What are my reminders today?',
          icon: Icons.alarm_rounded,
          action: SuggestionAction.openReminders,
          color: AppColors.reminder,
        ),
      );
    }

    // 5. Games — only offered when nothing has been finished today. Nagging
    //    someone who has already done their activity is not assistance.
    final playedToday = history
        .where((result) => result.isOnSameDayAs(now) && result.completed)
        .length;
    if (playedToday == 0) {
      suggestions.add(
        const AiSuggestion(
          label: "Let's play a memory game",
          icon: Icons.videogame_asset_rounded,
          action: SuggestionAction.openGames,
          color: AppColors.memory,
        ),
      );
    } else if (suggestions.length < maxSuggestions) {
      suggestions.add(
        const AiSuggestion(
          label: "Tell me about today's activity",
          icon: Icons.emoji_events_rounded,
          action: SuggestionAction.openGames,
          color: AppColors.memory,
        ),
      );
    }

    // 6. Notes, only if there is room left.
    if (data.notes.isNotEmpty && suggestions.length < maxSuggestions) {
      suggestions.add(
        const AiSuggestion(
          label: 'What notes have I written?',
          icon: Icons.sticky_note_2_rounded,
          action: SuggestionAction.ask,
          prompt: 'What notes have I written?',
          color: AppColors.memory,
        ),
      );
    }

    return suggestions.take(maxSuggestions).toList();
  }

  /// The single line shown on the Home dashboard.
  ///
  /// Same rules, one result. Returns null when there is nothing worth saying,
  /// which is better than inventing an errand for the user.
  AiSuggestion? dashboardSuggestion({
    required MemoryAidData data,
    required List<Reminder> reminders,
    required List<GameResult> history,
    required DateTime now,
  }) {
    final all = suggestionsFor(
      data: data,
      reminders: reminders,
      history: history,
      now: now,
    );
    return all.isEmpty ? null : all.first;
  }
}
