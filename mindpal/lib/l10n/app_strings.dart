import 'app_language.dart';
import 'translations.dart';

/// Every user-facing string in the translated parts of the app.
///
/// Why a plain Map instead of a localisation package (intl_utils,
/// easy_localization, flutter_gen)?
///   * Those need .arb files plus a code-generation step in the build. That is
///     one more thing that can break, and harder to follow while learning.
///   * This is about sixty lines, has no build step, and is directly testable.
///   * It can be swapped for the official system later without touching any
///     screen, because screens only ever call `strings.somethingLabel`.
///
/// What it does NOT do, honestly: plural rules ("1 reminder" vs "2 reminders"
/// handled properly per language), gendered forms, or right-to-left layout.
/// None of the NER languages here are right-to-left, and the app has very few
/// plurals, so this is a reasonable trade for now — not a permanent answer.
///
/// Each getter is typed, so a misspelled key is a compile error rather than a
/// blank label at runtime.
class AppStrings {
  const AppStrings({required this.language, required this.values});

  /// Builds the strings for a language, using its translation table.
  factory AppStrings.forLanguage(AppLanguage language) => AppStrings(
    language: language,
    values: kTranslations[language.code] ?? const {},
  );

  final AppLanguage language;

  /// This language's table. Public only because a named constructor parameter
  /// cannot initialise a private field — see the same note on ReminderService.
  final Map<String, String> values;

  /// The fallback chain: chosen language -> English -> the key itself.
  ///
  /// A missing translation therefore shows readable English, never a blank
  /// space and never a crash. The last step (returning the key) only happens
  /// if a key is missing from English too, which makes that bug obvious on
  /// screen instead of silent.
  String _t(String key) => values[key] ?? kEnglishStrings[key] ?? key;

  // ------------------------------------------------------------ navigation
  String get navHome => _t('nav_home');
  String get navGames => _t('nav_games');
  String get navReminders => _t('nav_reminders');
  String get navMemory => _t('nav_memory');
  String get navProfile => _t('nav_profile');

  String get titleHome => _t('title_home');
  String get titleGames => _t('title_games');
  String get titleReminders => _t('title_reminders');
  String get titleMemory => _t('title_memory');
  String get titleProfile => _t('title_profile');

  // ------------------------------------------------------------------ home
  String get greetingMorning => _t('greeting_morning');
  String get greetingAfternoon => _t('greeting_afternoon');
  String get greetingEvening => _t('greeting_evening');
  String get friend => _t('friend');

  String get todaysOverview => _t('todays_overview');
  String get quickActions => _t('quick_actions');

  String get cognitiveActivity => _t('cognitive_activity');
  String get cognitiveActivityMessage => _t('cognitive_activity_message');
  String get todaysReminders => _t('todays_reminders');
  String get todaysRemindersMessage => _t('todays_reminders_message');
  String get memoryAssistance => _t('memory_assistance');
  String get memoryAssistanceMessage => _t('memory_assistance_message');

  String get playMindPal => _t('play_mindpal');
  String get viewReminders => _t('view_reminders');
  String get memoryAid => _t('memory_aid');

  // ---------------------------------------------------------------- common
  String get save => _t('save');
  String get cancel => _t('cancel');
  String get delete => _t('delete');
  String get tryAgain => _t('try_again');

  // ------------------------------------------------------- home / elder
  String get memoryAssistant => _t('memory_assistant');
  String get playAGame => _t('play_a_game');
  String get myMemories => _t('my_memories');
  String get myReminders => _t('my_reminders');
  String get todaysActivity => _t('todays_activity');
  String get upcoming => _t('upcoming');
  String get noActivityYet => _t('no_activity_yet');
  String get noRemindersToday => _t('no_reminders_today');
  String get activitiesCompleted => _t('activities_completed');
  String get remindersRemaining => _t('reminders_remaining');
  String get allDoneToday => _t('all_done_today');

  // ------------------------------------------------ personalized game
  String get personalizedGame => _t('personalized_game');
  String get personalizedGameDescription => _t('personalized_game_description');
  String get playPersonalizedGame => _t('play_personalized_game');
  String get letsRemember => _t('lets_remember');
  String get greatJob => _t('great_job');
  String get niceTry => _t('nice_try');
  String get theAnswerWas => _t('the_answer_was');
  String get nextQuestion => _t('next_question');
  String get seeResult => _t('see_result');
  String get wellDone => _t('well_done');
  String get activityResult => _t('activity_result');
  String get youCompletedGame => _t('you_completed_game');
  String get playAgain => _t('play_again');
  String get backToHome => _t('back_to_home');
  String get createdFromMemories => _t('created_from_memories');
  String get needMoreMemories => _t('need_more_memories');
  String get needMoreMemoriesHint => _t('need_more_memories_hint');
  String get addMemories => _t('add_memories');

  // ------------------------------------------------------- odd one out
  String get oddOneOut => _t('odd_one_out');
  String get oddOneOutDescription => _t('odd_one_out_description');
  String get playOddOneOut => _t('play_odd_one_out');
  String get whichIsDifferent => _t('which_is_different');
  String get roundLabel => _t('round_label');

  // -------------------------------------------------------------- language
  String get chooseLanguage => _t('choose_language');
  String get chooseLanguageSubtitle => _t('choose_language_subtitle');
  String get appLanguage => _t('app_language');
  String get translationPending => _t('translation_pending');
  String get translationDraft => _t('translation_draft');
  String get viewCapabilities => _t('view_capabilities');
  String get capabilityTitle => _t('capability_title');
  String get selected => _t('selected');
}

/// The complete list of keys, in English. This is the source of truth: every
/// other language is checked against it in the tests, so a translation can
/// never silently go missing.
const Map<String, String> kEnglishStrings = {
  'nav_home': 'Home',
  'nav_games': 'MindPal',
  'nav_reminders': 'Reminders',
  'nav_memory': 'Memory',
  'nav_profile': 'Profile',

  'title_home': 'MindPal',
  'title_games': 'MindPal Games',
  'title_reminders': 'Reminders',
  'title_memory': 'Memory Aid',
  'title_profile': 'My Profile',

  'greeting_morning': 'Good morning',
  'greeting_afternoon': 'Good afternoon',
  'greeting_evening': 'Good evening',
  'friend': 'Friend',

  'todays_overview': "Today's Overview",
  'quick_actions': 'Quick Actions',

  'cognitive_activity': 'Cognitive Activity',
  'cognitive_activity_message':
      'No activity yet today. A short game keeps the mind active.',
  'todays_reminders': "Today's Reminders",
  'todays_reminders_message': 'Reminders you add will be listed here.',
  'memory_assistance': 'Memory Assistance',
  'memory_assistance_message':
      'Keep people, places and notes you want to remember.',

  'play_mindpal': 'Play MindPal',
  'view_reminders': 'View Reminders',
  'memory_aid': 'Memory Aid',

  'save': 'Save',
  'cancel': 'Cancel',
  'delete': 'Delete',
  'try_again': 'Try again',

  'memory_assistant': 'Memory Assistant',
  'play_a_game': 'Play a game',
  'my_memories': 'My memories',
  'my_reminders': 'My reminders',
  'todays_activity': 'Today\'s activity',
  'upcoming': 'Upcoming',
  'no_activity_yet': 'No activity yet today',
  'no_reminders_today': 'No reminders for today',
  'activities_completed': 'activities completed',
  'reminders_remaining': 'reminders remaining',
  'all_done_today': 'All done for today',

  'personalized_game': 'Memory Moment',
  'personalized_game_description': 'Questions made from your own saved memories.',
  'play_personalized_game': 'Play Memory Moment',
  'lets_remember': 'Let us remember together',
  'great_job': 'Great job!',
  'nice_try': 'Nice try. Let us keep going.',
  'the_answer_was': 'The answer was',
  'next_question': 'Next question',
  'see_result': 'See result',
  'well_done': 'Well done!',
  'activity_result': 'Activity Result',
  'you_completed_game': 'You completed the game',
  'play_again': 'Play again',
  'back_to_home': 'Back to home',
  'created_from_memories': 'This game was created from your saved memories.',
  'need_more_memories': 'We need a few more memories',
  'need_more_memories_hint': 'Add more people or places to create personalized games.',
  'add_memories': 'Add memories',

  'odd_one_out': 'Odd One Out',
  'odd_one_out_description': 'Find the picture that does not belong.',
  'play_odd_one_out': 'Play Odd One Out',
  'which_is_different': 'Which one is different?',
  'round_label': 'Round',

  'choose_language': 'Choose your language',
  'choose_language_subtitle':
      'MindPal will use this language across the app.',
  'app_language': 'App language',
  'translation_pending':
      'Translation coming soon. English will be shown for now.',
  'translation_draft': 'Translated — awaiting review by a native speaker.',
  'view_capabilities': 'What works in each language?',
  'capability_title': 'Language capabilities',
  'selected': 'Selected',
};
