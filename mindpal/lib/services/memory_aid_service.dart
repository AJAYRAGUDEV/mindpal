import '../models/memory_note.dart';
import '../models/person.dart';
import '../models/place.dart';
import '../storage/json_list_store.dart';
import '../storage/local_storage.dart';

/// Everything held in the Memory Aid section, loaded together.
///
/// A tiny holder class so one `await` can fetch all three lists and one
/// setState can store them.
class MemoryAidData {
  const MemoryAidData({
    this.people = const [],
    this.places = const [],
    this.notes = const [],
  });

  final List<Person> people;
  final List<Place> places;
  final List<MemoryNote> notes;

  bool get isEmpty => people.isEmpty && places.isEmpty && notes.isEmpty;

  MemoryAidData copyWith({
    List<Person>? people,
    List<Place>? places,
    List<MemoryNote>? notes,
  }) => MemoryAidData(
    people: people ?? this.people,
    places: places ?? this.places,
    notes: notes ?? this.notes,
  );
}

/// One search result, whatever kind of thing it came from.
enum SearchResultKind { person, place, note }

class SearchResult {
  const SearchResult({
    required this.kind,
    required this.id,
    required this.title,
    required this.subtitle,
  });

  final SearchResultKind kind;
  final int id;
  final String title;
  final String subtitle;
}

/// The Memory Aid section's data layer.
///
/// It owns three [JsonListStore]s. Notice how little code this is: the storing,
/// loading, id assignment and error handling all live in the generic store, so
/// this class only has to say *what* is stored and *where*.
class MemoryAidService {
  MemoryAidService(LocalStorage storage)
    : people = JsonListStore<Person>(
        storage: storage,
        key: 'people_v1',
        label: 'person',
        toMap: (person) => person.toMap(),
        fromMap: Person.fromMap,
      ),
      places = JsonListStore<Place>(
        storage: storage,
        key: 'places_v1',
        label: 'place',
        toMap: (place) => place.toMap(),
        fromMap: Place.fromMap,
      ),
      notes = JsonListStore<MemoryNote>(
        storage: storage,
        key: 'notes_v1',
        label: 'note',
        toMap: (note) => note.toMap(),
        fromMap: MemoryNote.fromMap,
      );

  final JsonListStore<Person> people;
  final JsonListStore<Place> places;
  final JsonListStore<MemoryNote> notes;

  Future<MemoryAidData> loadAll() async {
    return MemoryAidData(
      people: await people.loadAll(),
      places: await places.loadAll(),
      notes: await notes.loadAll(),
    );
  }

  /// Plain local text search across everything.
  ///
  /// No index, no database query, no server — just `contains` over lists that
  /// will hold tens of items, not millions. For this app that is the right
  /// amount of engineering: it is instant, it needs no internet, and there is
  /// nothing to keep in sync.
  ///
  /// Personal Memories will be added as a fourth source here once that model
  /// exists; nothing else about this method will need to change.
  List<SearchResult> search(MemoryAidData data, String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return const [];

    return [
      for (final person in data.people)
        if (person.searchText.contains(needle))
          SearchResult(
            kind: SearchResultKind.person,
            id: person.id,
            title: person.name,
            subtitle: person.relationship.isEmpty
                ? 'Person'
                : person.relationship,
          ),
      for (final place in data.places)
        if (place.searchText.contains(needle))
          SearchResult(
            kind: SearchResultKind.place,
            id: place.id,
            title: place.name,
            subtitle: place.description.isEmpty ? 'Place' : place.description,
          ),
      for (final note in data.notes)
        if (note.searchText.contains(needle))
          SearchResult(
            kind: SearchResultKind.note,
            id: note.id,
            title: note.title,
            subtitle: note.preview.isEmpty ? 'Note' : note.preview,
          ),
    ];
  }
}
