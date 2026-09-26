import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../theme/app_theme.dart';
import 'identifiable.dart';

/// What a memory is about. Fixed, short, and chosen by tapping — an elderly
/// user should never have to type a category.
enum MemoryCategory {
  family(label: 'Family', icon: Icons.family_restroom_rounded, color: AppColors.activity),
  friends(label: 'Friends', icon: Icons.group_rounded, color: Color(0xFF00838F)),
  places(label: 'Places', icon: Icons.place_rounded, color: AppColors.primary),
  events(label: 'Events', icon: Icons.celebration_rounded, color: AppColors.reminder),
  childhood(label: 'Childhood', icon: Icons.child_care_rounded, color: Color(0xFFAD1457)),
  other(label: 'Other', icon: Icons.auto_awesome_rounded, color: AppColors.memory);

  const MemoryCategory({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  static MemoryCategory fromName(String? name) => MemoryCategory.values
      .firstWhere((value) => value.name == name, orElse: () => MemoryCategory.other);

  /// The translated label; [label] remains the English fallback.
  String localisedLabel(AppStrings strings) => switch (this) {
    MemoryCategory.family => strings.catFamily,
    MemoryCategory.friends => strings.catFriends,
    MemoryCategory.places => strings.catPlaces,
    MemoryCategory.events => strings.catEvents,
    MemoryCategory.childhood => strings.catChildhood,
    MemoryCategory.other => strings.catOther,
  };
}

/// One item in the Memory Vault: a moment worth keeping and revisiting.
///
/// "Ajay's birthday", with the photo from that day and two lines about it.
/// Not a fact to be quizzed on — the People, Places and Notes lists do that —
/// but something to look at and remember.
///
/// **The media file is NOT stored in this record. Only a reference is.**
///
/// SharedPreferences (and any JSON store) holds text. A 3 MB photo would have
/// to be base64-encoded into it, inflating it by a third, and the entire vault
/// is one string that is re-read and re-parsed on every launch — so the app
/// would get slower with every memory added. Instead, [photoRef] and
/// [videoRef] are short keys understood by the MediaStore, which keeps the
/// bytes where the platform keeps files: a directory on Android, IndexedDB in
/// the browser. This record stays a few hundred bytes whatever it points to.
///
/// The cost of that choice: a reference can go stale if the file is gone.
/// Every screen that shows media has to cope with that, and does.
class VaultMemory implements Identifiable {
  const VaultMemory({
    required this.id,
    required this.title,
    required this.createdAt,
    this.story = '',
    this.date,
    this.personName = '',
    this.relationship = '',
    this.category = MemoryCategory.other,
    this.photoRef,
    this.videoRef,
    this.isDemo = false,
  });

  @override
  final int id;

  final String title;

  /// A few sentences in the user's own words. Optional but encouraged.
  final String story;

  /// When it happened. Optional: many memories have no exact day.
  final DateTime? date;

  /// Who it is about, if anyone. Free text, not a link to People — a memory
  /// can be about someone the user never saved as a contact.
  final String personName;
  final String relationship;

  final MemoryCategory category;

  /// MediaStore keys. Null when there is no photo / video.
  final String? photoRef;
  final String? videoRef;

  /// True for the sample memories the app can add for a presentation. Shown
  /// with a "Demo" tag so nobody mistakes them for the user's own, and
  /// deletable exactly like any other memory.
  final bool isDemo;

  final DateTime createdAt;

  bool get hasPhoto => photoRef != null && photoRef!.isNotEmpty;
  bool get hasVideo => videoRef != null && videoRef!.isNotEmpty;
  bool get hasPerson => personName.trim().isNotEmpty;

  /// "Ajay, son" / "Ajay" / "".
  String get personLabel {
    if (!hasPerson) return '';
    final rel = relationship.trim();
    return rel.isEmpty ? personName.trim() : '${personName.trim()}, ${rel.toLowerCase()}';
  }

  VaultMemory copyWith({
    int? id,
    String? title,
    String? story,
    DateTime? date,
    bool clearDate = false,
    String? personName,
    String? relationship,
    MemoryCategory? category,
    String? photoRef,
    bool clearPhoto = false,
    String? videoRef,
    bool clearVideo = false,
    bool? isDemo,
    DateTime? createdAt,
  }) => VaultMemory(
    id: id ?? this.id,
    title: title ?? this.title,
    story: story ?? this.story,
    date: clearDate ? null : (date ?? this.date),
    personName: personName ?? this.personName,
    relationship: relationship ?? this.relationship,
    category: category ?? this.category,
    photoRef: clearPhoto ? null : (photoRef ?? this.photoRef),
    videoRef: clearVideo ? null : (videoRef ?? this.videoRef),
    isDemo: isDemo ?? this.isDemo,
    createdAt: createdAt ?? this.createdAt,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'story': story,
    'date': date?.toIso8601String(),
    'personName': personName,
    'relationship': relationship,
    'category': category.name,
    'photoRef': photoRef,
    'videoRef': videoRef,
    'isDemo': isDemo,
    'createdAt': createdAt.toIso8601String(),
  };

  factory VaultMemory.fromMap(Map<String, dynamic> map) => VaultMemory(
    id: (map['id'] as num?)?.toInt() ?? 0,
    title: map['title'] as String? ?? '',
    story: map['story'] as String? ?? '',
    date: DateTime.tryParse(map['date'] as String? ?? ''),
    personName: map['personName'] as String? ?? '',
    relationship: map['relationship'] as String? ?? '',
    category: MemoryCategory.fromName(map['category'] as String?),
    photoRef: map['photoRef'] as String?,
    videoRef: map['videoRef'] as String?,
    isDemo: map['isDemo'] as bool? ?? false,
    createdAt:
        DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
  );
}
