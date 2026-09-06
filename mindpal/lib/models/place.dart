import 'identifiable.dart';

/// A place the user should be able to recall — home, the hospital, the temple.
///
/// No GPS, no map, no coordinates. This is a written reminder of a place, not
/// a navigation feature, and it works with no internet and no location
/// permission.
class Place implements Identifiable {
  const Place({
    required this.id,
    required this.name,
    required this.createdAt,
    this.description = '',
    this.address = '',
  });

  @override
  final int id;

  final String name;

  /// What it is, in the user's own words: "Where I live with Meena".
  final String description;

  final String address;

  final DateTime createdAt;

  String get searchText => '$name $description $address'.toLowerCase();

  Place copyWith({String? name, String? description, String? address}) => Place(
    id: id,
    name: name ?? this.name,
    description: description ?? this.description,
    address: address ?? this.address,
    createdAt: createdAt,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'description': description,
    'address': address,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Place.fromMap(Map<String, dynamic> map) => Place(
    id: (map['id'] as num?)?.toInt() ?? 0,
    name: map['name'] as String? ?? '',
    description: map['description'] as String? ?? '',
    address: map['address'] as String? ?? '',
    createdAt:
        DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
  );
}
