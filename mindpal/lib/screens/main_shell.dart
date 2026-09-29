import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../l10n/language_scope.dart';
import '../adventure/generation/adventure_generator.dart';
import '../adventure/model/adventure.dart';
import '../adventure/storage/adventure_store.dart';
import '../adventure/ui/adventure_home_screen.dart';
import '../adventure/ui/adventure_library_screens.dart';
import '../content/pack_library.dart';
import '../models/game_result.dart';
import '../models/game_settings.dart';
import '../models/reminder.dart';
import '../models/user_profile.dart';
import '../services/ai_service.dart';
import '../services/game_history_service.dart';
import '../services/game_settings_service.dart';
import '../services/memory_aid_service.dart';
import '../services/memory_vault_service.dart';
import '../services/notification_service.dart';
import '../services/care/care_sync_service.dart';
import '../services/voice/voice_controller.dart';
import '../services/profile_service.dart';
import '../services/reminder_service.dart';
import '../theme/app_sizes.dart';
import '../theme/app_theme.dart';
import '../utils/app_exception.dart';
import '../widgets/app_error_view.dart';
import 'extras_screen.dart';
import 'games/player_progress_screen.dart';
import 'companion/ai_companion_screen.dart';
import 'memory/memory_hub_screen.dart';
import 'mindpal_screen.dart';
import 'profile_screen.dart';
import 'reminders/add_reminder_screen.dart';
import 'reminders/reminder_details_screen.dart';
import 'reminders/reminders_screen.dart';
import 'settings/caregiver_link_screen.dart';
import 'settings/notification_check_screen.dart';

/// Named tab indexes.
///
/// Home's quick actions need to say "open the Reminders tab". Naming the
/// numbers here means no screen ever hard-codes a bare `2`.
/// The four destinations, in the order the app now presents them.
///
/// Festival Quest leads, because playing is what MindPal is for. The older
/// matching and sequencing games are still whole, one tap away under Quick
/// Games. Reminders, the memory vault, the assistant and the caregiver tools
/// have moved into Extras: they all still work, and **none of them is needed
/// to play**.
class AppTab {
  const AppTab._();

  static const int adventure = 0;
  static const int quickGames = 1;
  static const int progress = 2;
  static const int extras = 3;

  /// Kept so older call sites that mean "the games" still read clearly.
  static const int mindPal = quickGames;

  static List<String> titlesFor(AppStrings strings) => [
    'Festival Quest',
    'Quick Games',
    'My Progress',
    'Extras',
  ];
}

/// Which of the Extras is open, or null for the menu.
///
/// A sub-view rather than a pushed route, so these screens keep receiving the
/// live reminder and profile state MainShell owns — pushing them would hand
/// them a snapshot that never updates.
enum ExtrasView { reminders, memories, profile }

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
    required this.notificationService,
    required this.memoryAidService,
    required this.memoryVaultService,
    required this.gameSettingsService,
    required this.adventureStore,
    this.voice,
    this.careSync,
    required this.gameHistoryService,
    required this.aiService,
    this.storageHealthy = true,
  });

  final ProfileService profileService;
  final ReminderService reminderService;
  final NotificationService notificationService;
  final MemoryAidService memoryAidService;
  final MemoryVaultService memoryVaultService;
  final GameSettingsService gameSettingsService;

  /// Adventures, progress and finished runs, all on this device.
  final AdventureStore adventureStore;

  final VoiceController? voice;
  final CareSyncService? careSync;
  final GameHistoryService gameHistoryService;
  final AiService aiService;

  /// False when real disk storage failed to open and we fell back to memory.
  final bool storageHealthy;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  int _currentIndex = AppTab.adventure;

  /// Null means the Extras menu itself.
  ExtrasView? _extrasView;

  AdventureStore get _adventures => widget.adventureStore;
  late final AdventureGenerator _generator = AdventureGenerator();

  UserProfile _profile = UserProfile.empty;

  /// The one copy of the reminder list in the whole app. Both RemindersScreen
  /// and the reminders screen inside Extras read it from here.
  List<Reminder> _reminders = const [];

  /// Activity History — what was played and when. Never interpreted as any
  /// kind of cognitive assessment.
  List<GameResult> _gameHistory = const [];

  /// Sound, movement, spoken instructions, level and chosen pack. Read
  /// synchronously from storage, so games never open with the wrong settings
  /// and then correct themselves a frame later.
  GameSettings _gameSettings = GameSettings.defaults;

  bool _isLoading = true;
  String? _loadError;

  StreamSubscription<int>? _notificationTaps;

  /// Asked once per session at most. Android remembers the answer anyway;
  /// this only stops the explanation dialog appearing twice in one sitting.
  bool _askedForNotifications = false;

  /// Whether reminders will actually ring. Null until checked.
  ReminderAlarmStatus? _alarmStatus;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData();

    // A tap on a reminder notification while the app is running or in the
    // background lands here: go to the Reminders tab, where the reminder is.
    _notificationTaps = widget.notificationService.tapped.listen(
      (_) => _openExtras(ExtrasView.reminders),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notificationTaps?.cancel();
    _generator.dispose();
    super.dispose();
  }

  /// Makes a new adventure, and says plainly when it could not.
  ///
  /// A refusal is never silent and never leaves the player with nothing: the
  /// bundled adventure comes back instead, with the reason.
  Future<Adventure?> _generateAdventure(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: AppSizes.gap),
            Expanded(
              child: Text(
                'Writing you a new adventure...',
                style: TextStyle(fontSize: 19),
              ),
            ),
          ],
        ),
      ),
    );

    final result = await _generator.generate();
    if (!mounted) return null;
    // `context` here is MainShell's own, and `mounted` above is MainShell's
    // State. The dialog is dismissed through the root navigator because it was
    // opened there.
    if (!context.mounted) return null;
    Navigator.of(context, rootNavigator: true).pop();

    if (result.isGenerated) return result.adventure;

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'A new adventure could not be made just now, so the one that comes '
          'with MindPal is ready instead. (${result.problems.first})',
          style: const TextStyle(fontSize: 17),
        ),
        duration: const Duration(seconds: 8),
      ),
    );
    return null;
  }

  String? _extrasTitle(AppStrings strings) => switch (_extrasView) {
    null => null,
    ExtrasView.reminders => strings.titleReminders,
    ExtrasView.memories => strings.titleMemory,
    ExtrasView.profile => strings.titleProfile,
  };

  void _openExtras(ExtrasView? view) => setState(() {
    _currentIndex = AppTab.extras;
    _extrasView = view;
  });

  /// Sync when the app returns to the foreground.
  ///
  /// Not on every resume in practice: CareSyncService keeps a two-minute
  /// floor, so flicking back and forth does not hammer a free-tier server.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _syncCare();
  }

  /// Pulls caregiver reminders and folds them into the live list.
  ///
  /// Never blocks and never shows an error: being offline is the normal
  /// case for this app, and the reminders already on the phone keep working
  /// exactly as they did.
  Future<void> _syncCare({bool force = false}) async {
    final sync = widget.careSync;
    if (sync == null || !sync.isPaired) return;

    final report = await sync.sync(
      _reminders,
      force: force,
      onChanged: (updated) {
        if (mounted) setState(() => _reminders = updated);
      },
    );

    if (!mounted || !report.changedAnything) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          report.total == 1
              ? 'One reminder was updated by someone who helps you.'
              : '${report.total} reminders were updated by someone who '
                    'helps you.',
          style: const TextStyle(fontSize: 18),
        ),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final profile = await widget.profileService.load();
      final gameSettings = widget.gameSettingsService.load();
      final reminders = await widget.reminderService.loadAll();
      final history = await widget.gameHistoryService.loadAll();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _reminders = reminders;
        _gameHistory = history;
        _gameSettings = gameSettings;
        _isLoading = false;
      });

      // Saved reminders are the source of truth; the OS alarms are only a
      // mirror of them. Android can lose scheduled alarms (reinstall, some
      // battery savers), so we re-arm them from storage on every launch.
      await widget.reminderService.rescheduleAll(reminders);

      await _refreshAlarmStatus();

      // Launch sync: forced past the rate limit, because opening the app is
      // exactly when a patient expects to see what changed overnight.
      await _syncCare(force: true);

      // Cold start from a notification tap: open on the Reminders tab.
      final launchedFrom = await widget.notificationService.launchReminderId();
      if (launchedFrom != null && mounted) {
        _openExtras(ExtrasView.reminders);
      }
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

  void _openTab(int index) => setState(() {
    _currentIndex = index;
    if (index != AppTab.extras) _extrasView = null;
  });

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

    // The right moment to ask: the user has just written a reminder and is
    // about to expect it to ring. Asking on first launch, before they know
    // what the app does, gets a reflexive "no".
    await _ensureNotificationPermission();
    if (!mounted) return;

    await _runReminderAction(
      () => widget.reminderService.add(_reminders, draft),
      // WHEN it will ring, not just that it saved.
      //
      // The form asks for a time but not a date, so a time that has already
      // gone by today is scheduled for tomorrow. That is the right behaviour
      // and it used to be invisible: the user set 9:00 at 9:30, waited, and
      // concluded the app was broken.
      successMessage: 'Reminder saved. '
          '${_nextRingDescription(draft, DateTime.now())}',
    );
  }

  /// "It will ring at 8:00 PM." / "It will ring tomorrow at 8:00 AM."
  String _nextRingDescription(Reminder reminder, DateTime now) {
    final next = reminder.nextOccurrenceAfter(now);
    final isTomorrow = next.day != now.day;
    return isTomorrow
        ? 'It will ring tomorrow at ${reminder.formattedTime}.'
        : 'It will ring at ${reminder.formattedTime}.';
  }

  Future<void> _openCaregivers() async {
    final sync = widget.careSync;
    if (sync == null) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CaregiverLinkScreen(
          sync: sync,
          patientName: _profile.name,
          onUnpaired: () async {
            final updated = await sync.unpair(_reminders);
            if (mounted) setState(() => _reminders = updated);
          },
        ),
      ),
    );
    // A new pairing means there may already be reminders waiting.
    if (mounted) await _syncCare(force: true);
  }

  Future<void> _openNotificationCheck() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            NotificationCheckScreen(notifications: widget.notificationService),
      ),
    );
    if (mounted) await _refreshAlarmStatus();
  }

  /// Re-reads the OS state behind the one-line status on the Reminders tab.
  Future<void> _refreshAlarmStatus() async {
    final notifications = widget.notificationService;
    ReminderAlarmStatus status;

    if (!notifications.isSupported) {
      status = ReminderAlarmStatus.unsupported;
    } else if (!await notifications.hasPermission()) {
      status = ReminderAlarmStatus.permissionDenied;
    } else if (await notifications.canScheduleExactly()) {
      status = ReminderAlarmStatus.ringing;
    } else {
      status = ReminderAlarmStatus.ringingInexact;
    }

    if (mounted) setState(() => _alarmStatus = status);
  }

  /// Explains, then asks. Never blocks saving: a denied permission means the
  /// reminder is kept in the list without an alarm, and the user is told.
  Future<void> _ensureNotificationPermission() async {
    final notifications = widget.notificationService;
    if (!notifications.isSupported) return;
    if (await notifications.hasPermission()) return;
    if (_askedForNotifications || !mounted) return;
    _askedForNotifications = true;

    final wantsToAllow = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Let MindPal remind you?',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'To ring at the right time, even when the app is closed, '
              'MindPal needs permission to show notifications. Your phone '
              'will ask next.',
              style: TextStyle(fontSize: 20, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Continue'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Not now'),
            ),
          ],
        ),
      ),
    );
    if (wantsToAllow != true || !mounted) return;

    final granted = await notifications.requestPermission();
    await _refreshAlarmStatus();
    if (!granted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Notifications are off. Your reminders are saved, but they will '
            'not ring until notifications are allowed in phone Settings.',
            style: TextStyle(fontSize: 18),
          ),
          duration: Duration(seconds: 6),
        ),
      );
    }
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

  Future<void> _saveGameSettings(GameSettings settings) async {
    setState(() => _gameSettings = settings);
    await widget.gameSettingsService.save(settings);
  }

  /// Called when a game screen pops with its result.
  Future<void> _recordGameResult(GameResult result) async {
    // Local history first, and the caregiver report second. The record on the
    // phone is the one that matters; the report is a courtesy that must never
    // be the reason a played game goes unrecorded.
    try {
      final updated = await widget.gameHistoryService.record(
        _gameHistory,
        result,
      );
      if (!mounted) return;
      setState(() => _gameHistory = updated);

      await widget.careSync?.reportGameActivity(
        gameLabel: result.gameType.label,
        difficultyLabel: result.difficulty.label,
        packTitle: packById(result.packId)?.title,
        completed: result.completed,
        correct: result.correct,
        mistakes: result.mistakes,
        occurredAt: result.playedAt,
      );
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
          onOpenReminders: () => _openExtras(ExtrasView.reminders),
          onOpenMemoryAid: () => _openExtras(ExtrasView.memories),
          voice: widget.voice,
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
      AdventureHomeScreen(
        store: _adventures,
        voice: widget.voice,
        reducedMotion: _gameSettings.reducedMotion,
        onOpenQuickGames: () => _openTab(AppTab.quickGames),
        onOpenProgress: () => _openTab(AppTab.progress),
        // Absent rather than broken when no backend is configured: the button
        // only appears if there is somewhere for it to ask.
        onGenerate:
            _generator.isConfigured ? _generateAdventure : null,
      ),
      MindPalScreen(
        onGameFinished: _recordGameResult,
        memoryAidService: widget.memoryAidService,
        memoryVaultService: widget.memoryVaultService,
        onOpenMemoryAid: () => _openExtras(ExtrasView.memories),
        aiService: widget.aiService,
        gameHistory: _gameHistory,
        settings: _gameSettings,
        onSettingsChanged: _saveGameSettings,
        voice: widget.voice,
      ),
      AdventureProgressScreen(
        store: _adventures,
        onOpenGameProgress: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PlayerProgressScreen(history: _gameHistory),
          ),
        ),
      ),
      switch (_extrasView) {
        null => ExtrasScreen(
          strings: strings,
          reminderCount: _reminders.length,
          onOpenReminders: () => _openExtras(ExtrasView.reminders),
          onOpenMemories: () => _openExtras(ExtrasView.memories),
          onOpenProfile: () => _openExtras(ExtrasView.profile),
          onOpenAssistant: _openCompanion,
        ),
        ExtrasView.reminders => RemindersScreen(
          reminders: _reminders,
          onAddReminder: _addReminder,
          onToggleComplete: _toggleReminderComplete,
          alarmStatus: _alarmStatus,
          onCheckNotifications: _openNotificationCheck,
          onOpenReminder: _openReminderDetails,
        ),
        ExtrasView.memories => MemoryHubScreen(
          service: widget.memoryAidService,
          vault: widget.memoryVaultService,
        ),
        ExtrasView.profile => ProfileScreen(
          profile: _profile,
          onSave: _saveProfile,
          onOpenCaregivers:
              widget.careSync?.isConfigured == true ? _openCaregivers : null,
        ),
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(_extrasTitle(strings) ?? titles[_currentIndex]),
        leading: _extrasView == null
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Back to Extras',
                onPressed: () => _openExtras(null),
              ),
      ),
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
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore, color: AppColors.primaryDark),
            label: 'Quest',
          ),
          NavigationDestination(
            icon: Icon(Icons.psychology_outlined),
            selectedIcon: Icon(Icons.psychology, color: AppColors.primaryDark),
            label: 'Games',
          ),
          NavigationDestination(
            icon: Icon(Icons.timeline_outlined),
            selectedIcon: Icon(Icons.timeline, color: AppColors.primaryDark),
            label: 'Progress',
          ),
          NavigationDestination(
            icon: Icon(Icons.widgets_outlined),
            selectedIcon: Icon(Icons.widgets, color: AppColors.primaryDark),
            label: 'Extras',
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
