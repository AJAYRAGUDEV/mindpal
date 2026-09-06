import 'dart:convert';

/// The user's profile.
///
/// This class is "immutable": every field is final, so you never change a
/// UserProfile — you create a new one with [copyWith]. That makes bugs like
/// "who modified this object?" impossible.
class UserProfile {
  const UserProfile({
    this.name = '',
    this.preferredLanguage = 'English',
    this.caregiverName = '',
  });

  final String name;
  final String preferredLanguage;
  final String caregiverName;

  /// A brand-new user who has not filled anything in yet.
  static const UserProfile empty = UserProfile();

  bool get hasName => name.trim().isNotEmpty;

  /// What the Home screen greets the user with.
  String get displayName => hasName ? name.trim() : 'Friend';

  UserProfile copyWith({
    String? name,
    String? preferredLanguage,
    String? caregiverName,
  }) {
    return UserProfile(
      name: name ?? this.name,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      caregiverName: caregiverName ?? this.caregiverName,
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'preferredLanguage': preferredLanguage,
    'caregiverName': caregiverName,
  };

  /// Every field falls back to a default. If we add a field on Day 3, old
  /// saved profiles still load instead of crashing — a free migration.
  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      name: map['name'] as String? ?? '',
      preferredLanguage: map['preferredLanguage'] as String? ?? 'English',
      caregiverName: map['caregiverName'] as String? ?? '',
    );
  }

  String toJson() => jsonEncode(toMap());

  factory UserProfile.fromJson(String source) =>
      UserProfile.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
