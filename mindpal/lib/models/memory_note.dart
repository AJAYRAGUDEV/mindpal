import 'identifiable.dart';

/// A written note the user wants to keep.
///
/// Named MemoryNote rather than Note because `Note` is a common name that
/// would collide with other classes as the app grows.
class MemoryNote implements Identifiable {
  const MemoryNote({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  final int id;

  final String title;
  final String content;

  final DateTime createdAt;

  /// Set to "now" every time the note is edited. Kept separate from
  /// [createdAt] so the list can be ordered by most-recently-changed while
  /// still showing when a note was first written.
  final DateTime updatedAt;

  String get searchText => '$title $content'.toLowerCase();

  /// A one-line taste of the note for the list card.
  String get preview {
    final flattened = content.replaceAll('\n', ' ').trim();
    if (flattened.length <= 90) return flattened;
    return '${flattened.substring(0, 90)}...';
  }

  /// Note that this always refreshes [updatedAt] — there is no way to edit a
  /// note without recording that it changed.
  MemoryNote copyWith({String? title, String? content}) => MemoryNote(
    id: id,
    title: title ?? this.title,
    content: content ?? this.content,
    createdAt: createdAt,
    updatedAt: DateTime.now(),
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'content': content,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory MemoryNote.fromMap(Map<String, dynamic> map) {
    final created =
        DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now();
    return MemoryNote(
      id: (map['id'] as num?)?.toInt() ?? 0,
      title: map['title'] as String? ?? '',
      content: map['content'] as String? ?? '',
      createdAt: created,
      // Older saved notes may have no updatedAt; fall back to createdAt.
      updatedAt:
          DateTime.tryParse(map['updatedAt'] as String? ?? '') ?? created,
    );
  }
}
