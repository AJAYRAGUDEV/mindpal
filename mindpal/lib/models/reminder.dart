import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../theme/app_theme.dart';

/// How often a reminder repeats.
///
/// Day 3 deliberately stops at Once and Daily. Weekly and monthly recurrence
/// need a much bigger model (which weekdays? which date? what about the 31st
/// in February?) and a much busier form.
enum ReminderRepeat {
  once('Once'),
  daily('Daily');

  const ReminderRepeat(this.label);

  final String label;

  static ReminderRepeat fromName(String? name) => ReminderRepeat.values
      .firstWhere((value) => value.name == name, orElse: () => once);

  /// The translated label; [label] stays as the English fallback.
  String localisedLabel(AppStrings strings) => switch (this) {
    ReminderRepeat.once => strings.repeatOnce,
    ReminderRepeat.daily => strings.repeatDaily,
  };
}

/// What kind of reminder this is. Purely a label chosen by the user or their
/// caregiver — the app never interprets it or gives advice based on it.
enum ReminderCategory {
  dailyActivity(
    label: 'Daily Activity',
    icon: Icons.wb_sunny_rounded,
    color: AppColors.primary,
  ),
  meal(
    label: 'Meal',
    icon: Icons.restaurant_rounded,
    color: AppColors.reminder,
  ),
  appointment(
    label: 'Appointment',
    icon: Icons.event_rounded,
    color: AppColors.activity,
  ),
  medicine(
    label: 'Medicine',
    icon: Icons.medication_rounded,
    color: Color(0xFFB3261E),
  ),
  personal(
    label: 'Personal',
    icon: Icons.person_rounded,
    color: AppColors.memory,
  ),
  other(
    label: 'Other',
    icon: Icons.push_pin_rounded,
    color: Color(0xFF455A64),
  );

  const ReminderCategory({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  static ReminderCategory fromName(String? name) => ReminderCategory.values
      .firstWhere((value) => value.name == name, orElse: () => other);

  /// The translated label. [label] stays as the English fallback so the enum
  /// is still usable from code with no BuildContext (logs, notifications).
  String localisedLabel(AppStrings strings) => switch (this) {
    ReminderCategory.dailyActivity => strings.catDailyActivity,
    ReminderCategory.meal => strings.catMeal,
    ReminderCategory.appointment => strings.catAppointment,
    ReminderCategory.medicine => strings.catMedicine,
    ReminderCategory.personal => strings.catPersonal,
    ReminderCategory.other => strings.catOther,
  };
}

/// One reminder.
///
/// Immutable, like UserProfile and GameResult — you never change a Reminder,
/// you build a new one with [copyWith].
class Reminder {
  const Reminder({
    required this.id,
    required this.title,
    required this.category,
    required this.hour,
    required this.minute,
    required this.repeat,
    required this.createdAt,
    this.notes = '',
    this.completedOn,
  });

  /// Unique, and small enough to double as the Android notification id.
  /// See ReminderService._nextId for how it is chosen.
  final int id;

  final String title;
  final ReminderCategory category;

  /// The clock time, stored as two numbers rather than a DateTime.
  ///
  /// "Take medicine at 8am every day" is not a moment in time — it is a time
  /// of day that recurs. Storing a DateTime would force us to decide *which*
  /// 8am, and then keep moving it forward every night.
  final int hour; // 0-23
  final int minute; // 0-59

  final ReminderRepeat repeat;
  final String notes;

  /// The day this was last marked done, as 'yyyy-MM-dd', or null.
  ///
  /// This single field handles both repeat types:
  ///   * a DAILY reminder is done today only if this equals today's date,
  ///     so tomorrow it is automatically pending again;
  ///   * a ONCE reminder is done as soon as this is set at all.
  ///
  /// The alternative — a bool plus a nightly "reset all reminders" job — is
  /// more code and breaks if the app is not opened that day.
  final String? completedOn;

  final DateTime createdAt;

  /// 'yyyy-MM-dd' for a given day. Comparing these strings is how we ask
  /// "same calendar day?" without worrying about hours or time zones.
  static String dayKey(DateTime day) {
    final month = day.month.toString().padLeft(2, '0');
    final date = day.day.toString().padLeft(2, '0');
    return '${day.year}-$month-$date';
  }

  bool isCompletedOn(DateTime day) {
    final done = completedOn;
    if (done == null) return false;
    if (repeat == ReminderRepeat.once) return true;
    return done == dayKey(day);
  }

  /// This reminder's moment on a particular day.
  DateTime scheduledOn(DateTime day) =>
      DateTime(day.year, day.month, day.day, hour, minute);

  /// The next time this reminder is due, counting from [from].
  ///
  /// If today's time has already gone by, it is tomorrow. This is what makes
  /// a date picker unnecessary.
  DateTime nextOccurrenceAfter(DateTime from) {
    final today = scheduledOn(from);
    if (today.isAfter(from)) return today;
    return today.add(const Duration(days: 1));
  }

  /// Its time has passed today and it was not ticked off.
  ///
  /// Deliberately calm: "missed" is a status, not a failure. The user can
  /// still complete a missed reminder.
  bool isMissedAt(DateTime now) =>
      !isCompletedOn(now) && scheduledOn(now).isBefore(now);

  /// Minutes since midnight — used to sort the list into time order.
  int get minutesOfDay => hour * 60 + minute;

  /// "10:00 AM". Built by hand rather than with intl so it never depends on
  /// a BuildContext, which lets the model be unit-tested on its own.
  String get formattedTime {
    final period = hour < 12 ? 'AM' : 'PM';
    final twelveHour = hour % 12 == 0 ? 12 : hour % 12;
    return '$twelveHour:${minute.toString().padLeft(2, '0')} $period';
  }

  TimeOfDay get timeOfDay => TimeOfDay(hour: hour, minute: minute);

  Reminder copyWith({
    String? title,
    ReminderCategory? category,
    int? hour,
    int? minute,
    ReminderRepeat? repeat,
    String? notes,
  }) {
    return Reminder(
      id: id,
      title: title ?? this.title,
      category: category ?? this.category,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      repeat: repeat ?? this.repeat,
      notes: notes ?? this.notes,
      completedOn: completedOn,
      createdAt: createdAt,
    );
  }

  /// copyWith cannot clear a nullable field (passing null means "leave it
  /// alone"), so completion gets two small explicit methods instead. Easier
  /// to read than the usual sentinel-value trick.
  Reminder markCompletedOn(DateTime day) => Reminder(
    id: id,
    title: title,
    category: category,
    hour: hour,
    minute: minute,
    repeat: repeat,
    notes: notes,
    completedOn: dayKey(day),
    createdAt: createdAt,
  );

  Reminder clearCompletion() => Reminder(
    id: id,
    title: title,
    category: category,
    hour: hour,
    minute: minute,
    repeat: repeat,
    notes: notes,
    completedOn: null,
    createdAt: createdAt,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'category': category.name,
    'hour': hour,
    'minute': minute,
    'repeat': repeat.name,
    'notes': notes,
    'completedOn': completedOn,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Reminder.fromMap(Map<String, dynamic> map) => Reminder(
    id: (map['id'] as num?)?.toInt() ?? 0,
    title: map['title'] as String? ?? '',
    category: ReminderCategory.fromName(map['category'] as String?),
    hour: (map['hour'] as num?)?.toInt() ?? 9,
    minute: (map['minute'] as num?)?.toInt() ?? 0,
    repeat: ReminderRepeat.fromName(map['repeat'] as String?),
    notes: map['notes'] as String? ?? '',
    completedOn: map['completedOn'] as String?,
    createdAt:
        DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
  );
}
