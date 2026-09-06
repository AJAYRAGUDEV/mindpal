import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/reminder.dart';
import '../storage/local_storage.dart';
import '../utils/app_exception.dart';
import 'notification_service.dart';

/// Everything the app does to reminders.
///
/// The service is STATELESS: it does not hold the list. Each method takes the
/// current list, does its work, and returns the new list. MainShell keeps the
/// list and calls setState with whatever comes back.
///
/// Why stateless? Because there is then exactly one copy of the list in the
/// app (MainShell's), and it is impossible for the screen and the service to
/// disagree about what the reminders are.
///
/// The other job of this class is keeping storage and notifications in step.
/// Nothing outside can save a reminder without its alarm being updated too,
/// which is what stops an edited reminder ringing at both the old and the new
/// time.
class ReminderService {
  /// Positional, like ProfileService on Day 1. A named parameter cannot be an
  /// initializing formal for a private field (`required this._storage` is not
  /// legal Dart — named parameters may not start with an underscore), which is
  /// what the prefer_initializing_formals lint was pointing at.
  ReminderService(this._storage, this._notifications);

  final LocalStorage _storage;
  final NotificationService _notifications;

  static const String _key = 'reminders_v1';

  // ---------------------------------------------------------------- reading

  Future<List<Reminder>> loadAll() async {
    final raw = _storage.readString(_key);
    if (raw == null || raw.isEmpty) return [];

    try {
      // The whole list is stored as ONE JSON string under one key. That is
      // why LocalStorage never needed a "save a list" method.
      final decoded = jsonDecode(raw) as List<dynamic>;
      final reminders = decoded
          .map((item) => Reminder.fromMap(item as Map<String, dynamic>))
          .toList();
      return _sorted(reminders);
    } catch (error, stackTrace) {
      // Same rule as the profile on Day 1: bad data must never stop the app
      // from opening. Worst case the user sees an empty list.
      debugPrint('Could not read reminders: $error\n$stackTrace');
      return [];
    }
  }

  /// Re-schedules every reminder's alarm.
  ///
  /// Android forgets scheduled alarms when the app is reinstalled, and can
  /// drop them in other situations too. Running this at startup makes the
  /// saved list the source of truth and the alarms merely a mirror of it.
  Future<void> rescheduleAll(List<Reminder> reminders) async {
    if (!_notifications.isSupported) return;
    try {
      await _notifications.cancelAll();
      for (final reminder in reminders) {
        await _notifications.schedule(reminder);
      }
    } catch (error) {
      debugPrint('Could not reschedule reminders: $error');
    }
  }

  // ---------------------------------------------------------------- writing

  Future<List<Reminder>> add(List<Reminder> current, Reminder draft) async {
    final reminder = Reminder(
      id: _nextId(current),
      title: draft.title.trim(),
      category: draft.category,
      hour: draft.hour,
      minute: draft.minute,
      repeat: draft.repeat,
      notes: draft.notes.trim(),
      createdAt: DateTime.now(),
    );

    final updated = _sorted([...current, reminder]);
    await _persist(updated);
    await _safeSchedule(reminder);
    return updated;
  }

  Future<List<Reminder>> update(
    List<Reminder> current,
    Reminder reminder,
  ) async {
    final updated = _sorted([
      for (final item in current) if (item.id == reminder.id) reminder else item,
    ]);
    await _persist(updated);

    // Cancel first, then schedule. If the time changed, this is what stops
    // the old alarm from also firing.
    await _safeCancel(reminder.id);
    await _safeSchedule(reminder);
    return updated;
  }

  Future<List<Reminder>> remove(List<Reminder> current, int id) async {
    // `where` builds a new list without that one item, leaving every other
    // reminder untouched.
    final updated = current.where((reminder) => reminder.id != id).toList();
    await _persist(updated);
    await _safeCancel(id);
    return updated;
  }

  /// Ticks a reminder off (or un-ticks it) for a particular day.
  ///
  /// The alarm is NOT cancelled when a daily reminder is completed — it must
  /// still ring tomorrow. Completion and scheduling are separate ideas.
  Future<List<Reminder>> setCompleted(
    List<Reminder> current,
    int id, {
    required bool completed,
    required DateTime day,
  }) async {
    final updated = [
      for (final reminder in current)
        if (reminder.id == id)
          (completed ? reminder.markCompletedOn(day) : reminder.clearCompletion())
        else
          reminder,
    ];
    await _persist(updated);
    return updated;
  }

  // ---------------------------------------------------------------- queries

  /// Reminders that belong to [day], in time order.
  ///
  /// Every reminder shows every day: a daily one by definition, and a "once"
  /// one until it is done. A completed "once" reminder drops out.
  List<Reminder> forDay(List<Reminder> reminders, DateTime day) {
    return _sorted([
      for (final reminder in reminders)
        if (reminder.repeat == ReminderRepeat.daily ||
            !reminder.isCompletedOn(day))
          reminder,
    ]);
  }

  int completedCount(List<Reminder> reminders, DateTime day) =>
      reminders.where((reminder) => reminder.isCompletedOn(day)).length;

  /// The next reminder still due today, or null if none are left.
  Reminder? nextUpcoming(List<Reminder> reminders, DateTime now) {
    for (final reminder in _sorted(reminders)) {
      if (reminder.isCompletedOn(now)) continue;
      if (reminder.scheduledOn(now).isAfter(now)) return reminder;
    }
    return null;
  }

  // ---------------------------------------------------------------- helpers

  /// Ids start at 1 and are one higher than the highest in use.
  ///
  /// They must be small whole numbers because Android uses the same value as
  /// the notification id, and that is a 32-bit int — a timestamp would
  /// overflow it. Reusing the id of a deleted reminder is safe because
  /// [remove] always cancels that alarm first.
  int _nextId(List<Reminder> current) {
    var highest = 0;
    for (final reminder in current) {
      if (reminder.id > highest) highest = reminder.id;
    }
    return highest + 1;
  }

  List<Reminder> _sorted(List<Reminder> reminders) {
    final copy = [...reminders];
    copy.sort((a, b) => a.minutesOfDay.compareTo(b.minutesOfDay));
    return copy;
  }

  Future<void> _persist(List<Reminder> reminders) async {
    try {
      final encoded = jsonEncode(
        reminders.map((reminder) => reminder.toMap()).toList(),
      );
      await _storage.writeString(_key, encoded);
    } catch (error) {
      throw AppException(
        'We could not save your reminder. Please try again.',
        cause: error,
      );
    }
  }

  /// Notification failures must never lose the user's data.
  ///
  /// The reminder is already saved by the time these run. If the alarm cannot
  /// be set (permission denied, unsupported platform), we log it and carry on
  /// — the reminder still exists and still shows in the list.
  Future<void> _safeSchedule(Reminder reminder) async {
    try {
      await _notifications.schedule(reminder);
    } catch (error) {
      debugPrint('Could not schedule "${reminder.title}": $error');
    }
  }

  Future<void> _safeCancel(int id) async {
    try {
      await _notifications.cancel(id);
    } catch (error) {
      debugPrint('Could not cancel reminder $id: $error');
    }
  }
}
