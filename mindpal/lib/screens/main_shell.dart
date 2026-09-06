import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../l10n/language_scope.dart';
import '../models/game_result.dart';
import '../models/reminder.dart';
import '../models/user_profile.dart';
import '../services/ai_service.dart';
import '../services/game_history_service.dart';
import '../services/memory_aid_service.dart';
import '../services/profile_service.dart';
import '../services/reminder_service.dart';
import '../theme/app_sizes.dart';
import '../theme/app_theme.dart';
import '../utils/app_exception.dart';
import '../widgets/app_error_view.dart';
import 'home_screen.dart';
import 'companion/ai_companion_screen.dart';
import 'memory/memory_hub_screen.dart';
import 'mindpal_screen.dart';
import 'profile_screen.dart';
import 'reminders/add_reminder_screen.dart';
import 'reminders/reminder_details_screen.dart';
import 'reminders/reminders_screen.dart';

/// Named tab indexes.
///
/// Home's quick actions need to say "open the Reminders tab". Naming the
/// numbers here means no screen ever hard-codes a bare `2`.
class AppTab {
  const AppTab._();

  static const int home = 0;
  static const int mindPal = 1;
  static const int reminders = 2;
  static const int memory = 3;
  static const int profile = 4;

  /// Titles are no longer constants: they depend on the chosen language, so
  /// they are looked up from the string table at build time instead.
  static List<String> titlesFor(AppStrings strings) => [
    strings.titleHome,
    strings.titleGames,
    strings.titleReminders,
    strings.titleMemory,
    strings.titleProfile,
  ];
}

/// The frame that holds every screen.
///
/// This is the ONE place that owns shared app state on Day 1 (the loaded
/// profile). Screens receive data from here and send changes back here.
/// This pattern is called "lifting state up" — it is plain Flutter, no
/// state-management package required.
class MainShell extends StatefulWidget {
  const MainShell({
    super.key,
    required this.profileService,
    required this.reminderService,
    required this.memoryAidService,
    required this.gameHistoryService,
    required this.aiService,
    this.storageHealthy = true,
  });

  final ProfileService profileService;
  final ReminderService reminderService;
  final MemoryAidService memoryAidService;
  final GameHistoryService gameHistoryService;
  final AiService aiService;

  /// False when real disk storage failed to open and we fell back to memory.
  final bool storageHealthy;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = AppTab.home;

  UserProfile _profile = UserProfile.empty;

  /// The one copy of the reminder list in the whole app. Both RemindersScreen
  /// and (from the next step) HomeScreen read it from here.
  List<Reminder> _reminders = const [];

  /// Activity History — what was played and when. Never interpreted as any
  /// kind of cognitive assessment.
  List<GameResult> _gameHistory = const [];

  bool _isLoading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final profile = await widget.profileService.load();
      final reminders = await widget.reminderService.loadAll();
      final history = await widget.gameHistoryService.loadAll();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _reminders = reminders;
        _gameHistory = history;
        _isLoading = false;
      });

      // Saved reminders are the source of truth; the OS alarms are only a
      // mirror of them. Android can lose scheduled alarms (reinstall, some
      // battery savers), so we re-arm them from storage on every launch.
      await widget.reminderService.rescheduleAll(reminders);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadError = 'We could not open your saved details.';
        _isLoading = false;
      });
    }
  }

  /// Passed down to ProfileScreen. Any AppException travels back up to the
  /// profile screen, which is the screen that can show it to the user.
  Future<void> _saveProfile(UserProfile profile) async {
    await widget.profileService.save(profile);
    if (!mounted) return;
    setState(() => _profile = profile);
  }

  void _openTab(int index) => setState(() => _currentIndex = index);

  // ------------------------------------------------------------- reminders

  /// Opens the form, and saves whatever comes back.
  ///
  /// AddReminderScreen does not save anything itself — it pops a Reminder and
  /// this method decides what happens to it. Same pattern the games use to
  /// return a GameResult.
  Future<void> _addReminder() async {
    final draft = await Navigator.of(
      context,
    ).push<Reminder>(MaterialPageRoute(builder: (_) => const AddReminderScreen()));

    if (!mounted || draft == null) return;

    await _runReminderAction(
      () => widget.reminderService.add(_reminders, draft),
      successMessage: 'Reminder saved.',
    );
  }

  /// Opens the details screen and carries out whatever it decided.
  ///
  /// The details screen can return four different outcomes, so it returns a
  /// small result object rather than four different signals.
  Future<void> _openReminderDetails(Reminder reminder) async {
    final result = await Navigator.of(context).push<ReminderDetailsResult>(
      MaterialPageRoute(
        builder: (_) => ReminderDetailsScreen(reminder: reminder),
      ),
    );
    if (!mounted || result == null) return;

    switch (result.action) {
      case ReminderAction.completed:
        await _toggleReminderComplete(reminder.id, true);
      case ReminderAction.uncompleted:
        await _toggleReminderComplete(reminder.id, false);
      case ReminderAction.edited:
        // update() cancels the old alarm and schedules the new one, which is
        // what stops an edited time ringing twice.
        await _runReminderAction(
          () => widget.reminderService.update(_reminders, result.reminder!),
          successMessage: 'Reminder updated.',
        );
      case ReminderAction.deleted:
        await _runReminderAction(
          () => widget.reminderService.remove(_reminders, reminder.id),
          successMessage: 'Reminder deleted.',
        );
    }
  }

  Future<void> _toggleReminderComplete(int id, bool completed) {
    return _runReminderAction(
      () => widget.reminderService.setCompleted(
        _reminders,
        id,
        completed: completed,
        day: DateTime.now(),
      ),
    );
  }

  /// One error path for every reminder action.
  ///
  /// Each service method returns the NEW list, so all this has to do is store
  /// it. Writing the try/catch once here means add, edit, delete and complete
  /// all fail in the same predictable way.
  Future<void> _runReminderAction(
    Future<List<Reminder>> Function() action, {
    String? successMessage,
  }) async {
    try {
      final updated = await action();
      if (!mounted) return;
      setState(() => _reminders = updated);
      if (successMessage != null) _showMessage(successMessage);
    } on AppException catch (error) {
      if (!mounted) return;
      _showMessage(error.message, isError: true);
    } catch (_) {
      if (!mounted) return;
      _showMessage('Something went wrong. Please try again.', isError: true);
    }
  }

  // ------------------------------------------------------- activity history

  /// Called when a game screen pops with its result.
  Future<void> _recordGameResult(GameResult result) async {
    try {
      final updated = await widget.gameHistoryService.record(
        _gameHistory,
        result,
      );
      if (!mounted) return;
      setState(() => _gameHistory = updated);
    } catch (_) {
      // A game that was played but could not be filed is not worth an error
      // dialog — the user has already had the experience.
      if (mounted) _showMessage('Could not save that activity.', isError: true);
    }
  }

  /// The ONE chat surface. Everything that opens the companion — the floating
  /// button, Home's card, a suggestion chip — comes through here, so there is
  /// never a second chatbot implementation to keep in step.
  Future<void> _openCompanion() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AiCompanionScreen(
          memoryAidService: widget.memoryAidService,
          aiService: widget.aiService,
          reminders: _reminders,
          gameHistory: _gameHistory,
          onOpenGames: () => _openTab(AppTab.mindPal),
          onOpenReminders: () => _openTab(AppTab.reminders),
          onOpenMemoryAid: () => _openTab(AppTab.memory),
        ),
      ),
    );
    // The companion reads the vault when it opens; coming back may mean the
    // user added something through it, so refresh the counts Home shows.
    if (mounted) await _loadData();
  }

  void _showMessage(String text, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: isError ? AppColors.error : AppColors.primaryDark,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_loadError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('MindPal')),
        body: AppErrorView(message: _loadError!, onRetry: _loadData),
      );
    }

    // Reading the strings here makes MainShell rebuild automatically whenever
    // the language changes — that is what LanguageScope's updateShouldNotify
    // arranges for us.
    final strings = LanguageScope.of(context);
    final titles = AppTab.titlesFor(strings);

    // IndexedStack builds all five screens once and keeps them alive, so
    // switching tabs never loses scroll position or half-typed text.
    final screens = [
      HomeScreen(
        profile: _profile,
        reminders: _reminders,
        gameHistory: _gameHistory,
        onQuickAction: _openTab,
        onOpenAssistant: _openCompanion,
      ),
      MindPalScreen(
        onGameFinished: _recordGameResult,
        memoryAidService: widget.memoryAidService,
        onOpenMemoryAid: () => _openTab(AppTab.memory),
        aiService: widget.aiService,
      ),
      RemindersScreen(
        reminders: _reminders,
        onAddReminder: _addReminder,
        onToggleComplete: _toggleReminderComplete,
        onOpenReminder: _openReminderDetails,
      ),
      MemoryHubScreen(service: widget.memoryAidService),
      ProfileScreen(profile: _profile, onSave: _saveProfile),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(titles[_currentIndex])),
      // Reachable from every tab. Placed above the navigation bar rather than
      // over it, so it never covers a destination.
      floatingActionButton: _CompanionButton(onPressed: _openCompanion),
      body: Column(
        children: [
          if (!widget.storageHealthy) const _StorageWarningBanner(),
          Expanded(
            child: IndexedStack(index: _currentIndex, children: screens),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _openTab,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home, color: AppColors.primaryDark),
            label: strings.navHome,
          ),
          NavigationDestination(
            icon: const Icon(Icons.psychology_outlined),
            selectedIcon: const Icon(
              Icons.psychology,
              color: AppColors.primaryDark,
            ),
            label: strings.navGames,
          ),
          NavigationDestination(
            icon: const Icon(Icons.alarm_outlined),
            selectedIcon: const Icon(Icons.alarm, color: AppColors.primaryDark),
            label: strings.navReminders,
          ),
          NavigationDestination(
            icon: const Icon(Icons.photo_album_outlined),
            selectedIcon: const Icon(
              Icons.photo_album,
              color: AppColors.primaryDark,
            ),
            label: strings.navMemory,
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person, color: AppColors.primaryDark),
            label: strings.navProfile,
          ),
        ],
      ),
    );
  }
}

/// Honest, visible degradation: the app still works, but the user is told
/// their changes will not survive a restart.
class _StorageWarningBanner extends StatelessWidget {
  const _StorageWarningBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.reminder,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.pagePadding,
        vertical: 12,
      ),
      child: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.white),
          SizedBox(width: AppSizes.gapSmall),
          Expanded(
            child: Text(
              'Saving is unavailable right now. Changes will be lost when you '
              'close the app.',
              style: TextStyle(fontSize: 17, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

/// The always-available way into the Memory Companion.
///
/// An extended FAB with a WORD on it, not a bare icon. A lone symbol in a
/// circle is one of the least discoverable controls in Material Design, and
/// this app is for people who read the label.
class _CompanionButton extends StatelessWidget {
  const _CompanionButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: onPressed,
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      extendedPadding: const EdgeInsets.symmetric(horizontal: 22),
      icon: const Icon(Icons.chat_bubble_rounded, size: 28),
      label: const Text(
        'Ask',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
      ),
    );
  }
}
