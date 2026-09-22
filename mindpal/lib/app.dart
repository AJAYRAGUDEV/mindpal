import 'package:flutter/material.dart';

import 'l10n/app_language.dart';
import 'l10n/app_strings.dart';
import 'l10n/language_scope.dart';
import 'screens/main_shell.dart';
import 'services/ai_service.dart';
import 'services/game_history_service.dart';
import 'services/language_service.dart';
import 'services/memory_aid_service.dart';
import 'services/memory_vault_service.dart';
import 'models/reminder.dart';
import 'services/notification_service.dart';
import 'services/profile_service.dart';
import 'services/reminder_service.dart';
import 'theme/app_theme.dart';
import 'widgets/responsive_shell.dart';

/// The root widget: language, theme, and the first screen.
///
/// It became a StatefulWidget on Day 5 because the app now owns one piece of
/// state that affects literally every screen — the chosen language. When it
/// changes, everything below rebuilds with new text.
class MindPalApp extends StatefulWidget {
  const MindPalApp({
    super.key,
    required this.profileService,
    required this.reminderService,
    this.notificationService = const _NoNotifications(),
    required this.memoryAidService,
    required this.memoryVaultService,
    required this.gameHistoryService,
    required this.aiService,
    required this.languageService,
    this.initialLanguage = kDefaultLanguage,
    this.storageHealthy = true,
  });

  final ProfileService profileService;
  final ReminderService reminderService;

  /// Only for the two things the shell needs directly: asking permission at
  /// the right moment, and opening the Reminders tab when a notification is
  /// tapped. Scheduling itself stays inside ReminderService.
  final NotificationService notificationService;

  final MemoryAidService memoryAidService;
  final MemoryVaultService memoryVaultService;
  final GameHistoryService gameHistoryService;
  final AiService aiService;
  final LanguageService languageService;

  /// Loaded from storage in main() before the app starts, so the very first
  /// frame is already in the user's language — no flash of English.
  final AppLanguage initialLanguage;

  final bool storageHealthy;

  @override
  State<MindPalApp> createState() => _MindPalAppState();
}

class _MindPalAppState extends State<MindPalApp> {
  late AppLanguage _language = widget.initialLanguage;

  Future<void> _changeLanguage(AppLanguage language) async {
    // Apply immediately so the UI responds at once, then persist. If saving
    // fails the language still works for this session.
    setState(() => _language = language);
    await widget.languageService.save(language);
  }

  @override
  Widget build(BuildContext context) {
    // LanguageScope wraps MaterialApp, so pushed routes and dialogs — which
    // are built underneath MaterialApp's Navigator — can read strings too.
    return LanguageScope(
      strings: AppStrings.forLanguage(_language),
      onLanguageChanged: _changeLanguage,
      child: MaterialApp(
        title: 'MindPal',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),

        // Many elderly users raise the system font size in Android settings.
        // We honour that, but clamp it so the layout never breaks completely.
        // Two wrappers, outermost first:
        //   ResponsiveShell        - phone-shaped frame on a wide window
        //   withClampedTextScaling - honour the OS font size, within limits
        builder: (context, child) => ResponsiveShell(
          child: MediaQuery.withClampedTextScaling(
            minScaleFactor: 1.0,
            maxScaleFactor: 1.6,
            child: child ?? const SizedBox.shrink(),
          ),
        ),

        home: MainShell(
          profileService: widget.profileService,
          reminderService: widget.reminderService,
          notificationService: widget.notificationService,
          memoryAidService: widget.memoryAidService,
          memoryVaultService: widget.memoryVaultService,
          gameHistoryService: widget.gameHistoryService,
          aiService: widget.aiService,
          storageHealthy: widget.storageHealthy,
        ),
      ),
    );
  }
}

/// A const no-op for call sites that do not care about notifications (tests).
/// NoopNotificationService itself is not const-constructible.
class _NoNotifications implements NotificationService {
  const _NoNotifications();

  @override
  bool get isSupported => false;
  @override
  Future<void> init() async {}
  @override
  Future<bool> hasPermission() async => false;
  @override
  Future<bool> requestPermission() async => false;
  @override
  Future<bool> canScheduleExactly() async => false;
  @override
  Future<void> schedule(Reminder reminder, {DateTime? after}) async {}
  @override
  Future<void> cancel(int reminderId) async {}
  @override
  Future<void> cancelAll() async {}
  @override
  Stream<int> get tapped => const Stream.empty();
  @override
  Future<int?> launchReminderId() async => null;
  @override
  Future<void> showTestNotification() async {}
  @override
  Future<int> pendingCount() async => 0;
}
