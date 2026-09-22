import 'package:flutter/foundation.dart';

import '../models/reminder.dart';

/// The contract for "tell the user about a reminder at a certain time".
///
/// This mirrors LocalStorage from Day 1 exactly: an abstract class that the
/// rest of the app talks to, with the platform-specific work hidden behind it.
///
/// Why bother, when there is only one real implementation?
///   * Notifications do not exist on the web, so testing in Chrome needs a
///     do-nothing version that keeps the app running.
///   * A user can deny permission. The app must still work.
///   * Unit tests must never schedule a real alarm on your phone.
///
/// The real implementation is AndroidNotificationService, chosen at compile
/// time by notifications/notification_service_factory.dart.
abstract class NotificationService {
  /// Called once at startup. Must never throw — a phone that cannot schedule
  /// notifications is still a phone that can show a reminder list.
  Future<void> init();

  /// False on web, and on any platform we have not wired up.
  bool get isSupported;

  /// Whether the OS has granted permission to post notifications.
  Future<bool> hasPermission();

  /// Asks the user. Returns what they chose. Safe to call when already
  /// granted; Android simply returns true without showing anything.
  Future<bool> requestPermission();

  /// Whether the OS will fire the alarm at the exact minute, as opposed to
  /// "around then". Used only to tell the user the truth about timing.
  Future<bool> canScheduleExactly();

  /// Schedules (or re-schedules) this reminder's alarm.
  ///
  /// Implementations must cancel any existing alarm for the same reminder
  /// first, so calling this twice never produces two notifications.
  ///
  /// [after] is the earliest moment the alarm may fire; it defaults to now.
  /// A daily reminder ticked off before its time today is re-armed with
  /// `after: end of today`, so it stays quiet today and rings tomorrow.
  Future<void> schedule(Reminder reminder, {DateTime? after});

  /// Removes the alarm for a reminder id.
  Future<void> cancel(int reminderId);

  Future<void> cancelAll();

  /// Fires with the reminder id when the user taps a notification while the
  /// app is running or in the background. The shell listens and opens the
  /// Reminders tab.
  Stream<int> get tapped;

  /// If the app was launched cold by tapping a notification, the id of that
  /// reminder; otherwise null. Read once at startup.
  Future<int?> launchReminderId();

  /// Posts a notification immediately, for the "is this thing on?" button.
  ///
  /// Deliberately separate from [schedule]: it proves the channel, the
  /// permission, the icon and the sound in one tap, with no waiting and no
  /// alarm involved. If this rings but a reminder does not, the problem is
  /// scheduling; if this does not ring either, the problem is permission or
  /// the channel. That split is most of the diagnosis.
  ///
  /// Throws on failure rather than swallowing it, so the screen can say what
  /// went wrong.
  Future<void> showTestNotification();

  /// How many alarms the OS currently holds for this app. The honest answer
  /// to "did it actually schedule anything?".
  Future<int> pendingCount();
}

/// A notification service that does nothing, successfully.
///
/// Used on the web, and as a fallback if the real one fails to start. Every
/// method returns a sensible "no" rather than throwing, so no calling code
/// needs a special case for "notifications are unavailable".
///
/// This is the Null Object pattern: instead of passing null and checking for
/// it everywhere, you pass a harmless object that answers every question.
class NoopNotificationService implements NotificationService {
  @override
  bool get isSupported => false;

  @override
  Future<void> init() async {
    debugPrint('Notifications are not available on this platform.');
  }

  @override
  Future<bool> hasPermission() async => false;

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<bool> canScheduleExactly() async => false;

  @override
  Future<void> schedule(Reminder reminder, {DateTime? after}) async {
    debugPrint('(no-op) would schedule "${reminder.title}" '
        'at ${reminder.formattedTime}');
  }

  @override
  Future<void> cancel(int reminderId) async {
    debugPrint('(no-op) would cancel reminder $reminderId');
  }

  @override
  Future<void> cancelAll() async {}

  @override
  Stream<int> get tapped => const Stream.empty();

  @override
  Future<int?> launchReminderId() async => null;

  @override
  Future<void> showTestNotification() async {
    throw UnsupportedError('Notifications are not available on this platform.');
  }

  @override
  Future<int> pendingCount() async => 0;
}
