import 'identifiable.dart';

/// Someone important to the user.
///
/// Immutable, like every other saved model in this app.
class Person implements Identifiable {
  const Person({
    required this.id,
    required this.name,
    required this.relationship,
    required this.createdAt,
    this.phone = '',
    this.imagePath,
  });

  @override
  final int id;

  final String name;

  /// "Son", "Daughter", "Doctor", "Neighbour" — free text, not a fixed list,
  /// because family words differ hugely between languages and cultures.
  final String relationship;

  final String phone;

  /// Path to a photo on this device. Always null for now — the photo picker
  /// arrives with the media work. The field exists already so that adding it
  /// later does not change the saved data format.
  final String? imagePath;

  final DateTime createdAt;

  /// First letter, used for the circle avatar when there is no photo.
  String get initial =>
      name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();

  /// Everything the search box should look through, lowercased once here so
  /// the search itself stays a simple `contains`.
  String get searchText => '$name $relationship $phone'.toLowerCase();

  Person copyWith({
    String? name,
    String? relationship,
    String? phone,
    String? imagePath,
  }) => Person(
    id: id,
    name: name ?? this.name,
    relationship: relationship ?? this.relationship,
    phone: phone ?? this.phone,
    imagePath: imagePath ?? this.imagePath,
    createdAt: createdAt,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'relationship': relationship,
    'phone': phone,
    'imagePath': imagePath,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Person.fromMap(Map<String, dynamic> map) => Person(
    id: (map['id'] as num?)?.toInt() ?? 0,
    name: map['name'] as String? ?? '',
    relationship: map['relationship'] as String? ?? '',
    phone: map['phone'] as String? ?? '',
    imagePath: map['imagePath'] as String?,
    createdAt:
        DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
  );
}
