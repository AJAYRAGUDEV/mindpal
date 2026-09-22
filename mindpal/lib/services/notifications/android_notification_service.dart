import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../models/reminder.dart';
import '../notification_service.dart';

/// Real reminders on Android, through the OS alarm system.
///
/// HOW A REMINDER REACHES THE USER. `schedule()` hands the reminder to
/// flutter_local_notifications, which registers it with Android's
/// AlarmManager and writes a copy to its own on-disk list. At the scheduled
/// minute, Android wakes the plugin's ScheduledNotificationReceiver — a
/// broadcast receiver declared in AndroidManifest.xml — which posts the
/// notification. No Dart code runs at that moment, so the app can be in the
/// background, swiped away, or never opened since the phone booted: the
/// alarm belongs to Android, not to the Flutter process.
///
/// REBOOT. Alarms do not survive a reboot on Android. The plugin's
/// ScheduledNotificationBootReceiver listens for BOOT_COMPLETED (permission
/// RECEIVE_BOOT_COMPLETED in the manifest) and re-registers every
/// notification from its on-disk list. Separately, the app re-arms everything
/// from the saved reminder list on each launch (ReminderService.rescheduleAll),
/// so the saved list is always the source of truth.
///
/// TIME ZONE. A reminder is "8:00 PM", a wall-clock time, not an instant.
/// The plugin wants a TZDateTime, so at startup the device's zone is read
/// (flutter_timezone) and every schedule is built in it. Entered in Guwahati,
/// it rings at 8:00 PM Guwahati time, including across DST changes in zones
/// that have them.
///
/// EXACTNESS. Android 12+ throttles alarms unless an app holds an exact-alarm
/// permission. A medicine reminder that fires at 8:11 instead of 8:00 is not
/// a reminder, so the manifest declares USE_EXACT_ALARM (Android 13+, granted
/// at install for alarm/reminder apps, never prompts) and SCHEDULE_EXACT_ALARM
/// for Android 12 only (also granted by default there). If exact scheduling is
/// still refused, the alarm is set inexact rather than not at all.
class AndroidNotificationService implements NotificationService {
  AndroidNotificationService();

  static const String channelId = 'mindpal_reminders';
  static const String channelName = 'MindPal Reminders';
  static const String channelDescription =
      'Reminders you set in MindPal: medicine, meals, appointments.';

  final _plugin = FlutterLocalNotificationsPlugin();
  final _tapController = StreamController<int>.broadcast();

  bool _ready = false;
  bool _exact = false;

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  @override
  bool get isSupported => _ready;

  @override
  Future<void> init() async {
    try {
      // Time zone database, then the device's own zone. If the zone lookup
      // fails the plugin falls back to UTC, which would ring 5½ hours off in
      // India — so the failure is logged loudly rather than swallowed.
      tzdata.initializeTimeZones();
      try {
        final info = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(info.identifier));
      } catch (error) {
        debugPrint('NOTIFICATIONS: could not read the device time zone '
            '(${error.runtimeType}); reminders will use UTC.');
      }

      const settings = InitializationSettings(
        // A white-on-transparent glyph, as Android requires for the status
        // bar. See android/app/src/main/res/drawable/ic_notification.xml.
        android: AndroidInitializationSettings('ic_notification'),
      );
      await _plugin.initialize(
        settings: settings,
        onDidReceiveNotificationResponse: _onTapped,
      );

      // The channel is what the user sees under Settings > Notifications >
      // MindPal. High importance = heads-up with sound. Sound and vibration
      // are enabled here, but the user's own settings for the channel win:
      // if they mute it there, Android keeps it muted and we do not fight it.
      await _android?.createNotificationChannel(
        const AndroidNotificationChannel(
          channelId,
          channelName,
          description: channelDescription,
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
        ),
      );

      _exact = await _android?.canScheduleExactNotifications() ?? false;
      _ready = true;
      debugPrint('NOTIFICATIONS: ready (zone ${tz.local.name}, '
          'exact alarms ${_exact ? 'allowed' : 'not allowed, using inexact'})');
    } catch (error, stackTrace) {
      // Never fatal: the reminder list still works without alarms.
      debugPrint('NOTIFICATIONS: failed to initialise: $error\n$stackTrace');
      _ready = false;
    }
  }

  void _onTapped(NotificationResponse response) {
    final id = int.tryParse(response.payload ?? '');
    if (id != null) _tapController.add(id);
  }

  @override
  Stream<int> get tapped => _tapController.stream;

  @override
  Future<int?> launchReminderId() async {
    if (!_ready) return null;
    try {
      final details = await _plugin.getNotificationAppLaunchDetails();
      if (details?.didNotificationLaunchApp != true) return null;
      return int.tryParse(details?.notificationResponse?.payload ?? '');
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> hasPermission() async {
    if (!_ready) return false;
    return await _android?.areNotificationsEnabled() ?? false;
  }

  @override
  Future<bool> requestPermission() async {
    if (!_ready) return false;
    // Android 13+ shows the system dialog; older versions return true
    // immediately because notifications are on by default there.
    return await _android?.requestNotificationsPermission() ?? false;
  }

  @override
  Future<bool> canScheduleExactly() async => _ready && _exact;

  @override
  Future<void> schedule(Reminder reminder, {DateTime? after}) async {
    if (!_ready) return;

    // Cancel first. Same id = same PendingIntent, so Android would replace
    // it anyway, but being explicit is what the interface promises.
    await _plugin.cancel(id: reminder.id);

    final from = after ?? DateTime.now();
    final next = reminder.nextOccurrenceAfter(from);
    final when = tz.TZDateTime.from(next, tz.local);

    final body = reminder.notes.trim().isEmpty
        ? '${reminder.category.label} · ${reminder.formattedTime}'
        : reminder.notes.trim();

    await _plugin.zonedSchedule(
      id: reminder.id,
      title: reminder.title,
      body: body,
      scheduledDate: when,
      payload: reminder.id.toString(),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.reminder,
          // No custom sound: the device's own notification sound, which the
          // user already knows and has chosen the volume for.
          playSound: true,
          enableVibration: true,
          // Long notes are shown in full when the notification is expanded.
          styleInformation: BigTextStyleInformation(body),
          ticker: reminder.title,
          // Tapping opens the app and dismisses the notification.
          autoCancel: true,
        ),
      ),
      androidScheduleMode: _exact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      // A daily reminder repeats at the same wall-clock time every day; a
      // once-only reminder fires at its next occurrence and is then done.
      matchDateTimeComponents: reminder.repeat == ReminderRepeat.daily
          ? DateTimeComponents.time
          : null,
    );

    debugPrint('NOTIFICATIONS: scheduled #${reminder.id} for $when '
        '(${reminder.repeat.name}, ${_exact ? 'exact' : 'inexact'})');
  }

  @override
  Future<void> cancel(int reminderId) async {
    if (!_ready) return;
    await _plugin.cancel(id: reminderId);
  }

  @override
  Future<void> cancelAll() async {
    if (!_ready) return;
    await _plugin.cancelAll();
  }
}
