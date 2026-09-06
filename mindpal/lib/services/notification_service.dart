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

  /// Schedules (or re-schedules) this reminder's alarm.
  ///
  /// Implementations must cancel any existing alarm for the same reminder
  /// first, so calling this twice never produces two notifications.
  Future<void> schedule(Reminder reminder);

  /// Removes the alarm for a reminder id.
  Future<void> cancel(int reminderId);

  Future<void> cancelAll();
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
  Future<void> schedule(Reminder reminder) async {
    debugPrint('(no-op) would schedule "${reminder.title}" '
        'at ${reminder.formattedTime}');
  }

  @override
  Future<void> cancel(int reminderId) async {
    debugPrint('(no-op) would cancel reminder $reminderId');
  }

  @override
  Future<void> cancelAll() async {}
}
