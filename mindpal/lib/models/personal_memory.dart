import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'identifiable.dart';

/// What kind of thing a personal memory is.
///
/// person / place / note already exist as their own models and screens. They
/// are listed here because the Memory Vault is meant to eventually present all
/// seven kinds in one place; the three existing ones keep their own storage
/// and keep working exactly as they do now.
enum MemoryKind {
  person(label: 'Person', icon: Icons.people_alt_rounded, color: AppColors.activity),
  place(label: 'Place', icon: Icons.place_rounded, color: AppColors.primary),
  note(label: 'Note', icon: Icons.sticky_note_2_rounded, color: AppColors.memory),
  photo(label: 'Photo', icon: Icons.photo_rounded, color: AppColors.reminder),
  video(label: 'Video', icon: Icons.videocam_rounded, color: Color(0xFF00838F)),
  voice(label: 'Voice', icon: Icons.mic_rounded, color: Color(0xFFAD1457)),
  event(label: 'Event', icon: Icons.event_rounded, color: Color(0xFF455A64));

  const MemoryKind({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  /// True for the kinds that need a file on disk. Those are not implemented:
  /// they need a media picker, which needs a real device to build against.
  bool get needsFile =>
      this == MemoryKind.photo ||
      this == MemoryKind.video ||
      this == MemoryKind.voice;

  static MemoryKind fromName(String? name) => MemoryKind.values.firstWhere(
    (kind) => kind.name == name,
    orElse: () => MemoryKind.note,
  );
}

/// A single item in the Personal Memory Vault.
///
/// FOUNDATION ONLY. This model is complete and stores/loads correctly, but no
/// screen creates one yet, because photo, video and voice all require a media
/// picker that cannot be built or tested without an Android device.
///
/// The important architectural decision is recorded here so it is not lost:
///
///   **The media file is NOT stored in the database. Only its path is.**
///
/// Why: SharedPreferences (and any JSON store) holds text. Putting a 4 MB
/// photo in it would mean base64-encoding it, which inflates it by a third,
/// and then re-reading and re-parsing every photo in the vault on every single
/// app launch — because the whole list is one string. The app would get slower
/// with every memory added. Storing a path keeps each record a few hundred
/// bytes, and the photo is read only when it is actually shown.
///
/// The cost of that choice, which must be handled when media is implemented:
/// a path can go stale. The file may be deleted, or moved, or live in a cache
/// directory the OS clears. So any screen showing media has to cope with the
/// file being gone, rather than assuming a saved path is still valid.
class PersonalMemory implements Identifiable {
  const PersonalMemory({
    required this.id,
    required this.kind,
    required this.title,
    required this.createdAt,
    this.description = '',
    this.filePath,
    this.eventDate,
    this.reminderEnabled = false,
    this.reminderHour,
    this.reminderMinute,
    this.reminderRepeat = MemoryReminderRepeat.once,
  });

  @override
  final int id;

  final MemoryKind kind;
  final String title;
  final String description;

  /// Path to a photo, video or voice file on this device. Null for text-only
  /// kinds. Never a URL — nothing in this app is uploaded.
  final String? filePath;

  /// For [MemoryKind.event]: the day the memory is about, which may be long
  /// before [createdAt].
  final DateTime? eventDate;

  final DateTime createdAt;

  // -- reminder attached to this memory ------------------------------------
  // Stored here rather than as a Reminder so that deleting the memory deletes
  // its reminder with it. The scheduling itself will go through the same
  // NotificationService the reminders use — one notification system, not two.

  final bool reminderEnabled;
  final int? reminderHour;
  final int? reminderMinute;
  final MemoryReminderRepeat reminderRepeat;

  /// Notification ids must not collide with the reminder ids, which start at 1
  /// and count up. Offsetting memory notifications into their own range keeps
  /// the two systems from cancelling each other's alarms.
  static const int notificationIdOffset = 100000;

  int get notificationId => notificationIdOffset + id;

  bool get hasFile => filePath != null && filePath!.trim().isNotEmpty;

  String get searchText => '$title $description'.toLowerCase();

  Map<String, dynamic> toMap() => {
    'id': id,
    'kind': kind.name,
    'title': title,
    'description': description,
    'filePath': filePath,
    'eventDate': eventDate?.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'reminderEnabled': reminderEnabled,
    'reminderHour': reminderHour,
    'reminderMinute': reminderMinute,
    'reminderRepeat': reminderRepeat.name,
  };

  factory PersonalMemory.fromMap(Map<String, dynamic> map) => PersonalMemory(
    id: (map['id'] as num?)?.toInt() ?? 0,
    kind: MemoryKind.fromName(map['kind'] as String?),
    title: map['title'] as String? ?? '',
    description: map['description'] as String? ?? '',
    filePath: map['filePath'] as String?,
    eventDate: DateTime.tryParse(map['eventDate'] as String? ?? ''),
    createdAt:
        DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
    reminderEnabled: map['reminderEnabled'] as bool? ?? false,
    reminderHour: (map['reminderHour'] as num?)?.toInt(),
    reminderMinute: (map['reminderMinute'] as num?)?.toInt(),
    reminderRepeat: MemoryReminderRepeat.fromName(
      map['reminderRepeat'] as String?,
    ),
  );
}

/// How often a memory reminder repeats.
///
/// Weekly is included here — unlike the reminder system, which stops at daily —
/// because "revisit this photo every Sunday" is the natural use, and having the
/// value in the model now means adding it later touches only the scheduler.
enum MemoryReminderRepeat {
  once('Once'),
  daily('Daily'),
  weekly('Weekly');

  const MemoryReminderRepeat(this.label);

  final String label;

  static MemoryReminderRepeat fromName(String? name) =>
      MemoryReminderRepeat.values.firstWhere(
        (value) => value.name == name,
        orElse: () => MemoryReminderRepeat.once,
      );
}
