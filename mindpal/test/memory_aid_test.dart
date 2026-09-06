import 'package:flutter_test/flutter_test.dart';
import 'package:mindpal/models/memory_note.dart';
import 'package:mindpal/models/person.dart';
import 'package:mindpal/models/place.dart';
import 'package:mindpal/services/memory_aid_service.dart';
import 'package:mindpal/storage/local_storage.dart';

Future<MemoryAidService> _newService([InMemoryStorage? shared]) async {
  final storage = shared ?? InMemoryStorage();
  await storage.init();
  return MemoryAidService(storage);
}

Person _person(int id, String name, String relationship, {String phone = ''}) =>
    Person(
      id: id,
      name: name,
      relationship: relationship,
      phone: phone,
      createdAt: DateTime(2026, 1, 1),
    );

void main() {
  group('JsonListStore (through the people store)', () {
    test('assigns ids starting at 1 and never repeats one in use', () async {
      final service = await _newService();

      var people = await service.people.add(
        const [],
        (id) => _person(id, 'Ravi', 'Son'),
      );
      people = await service.people.add(
        people,
        (id) => _person(id, 'Meena', 'Daughter'),
      );

      expect(people.map((p) => p.id).toList(), [1, 2]);
    });

    test('data survives a restart', () async {
      final storage = InMemoryStorage();
      final service = await _newService(storage);

      await service.people.add(const [], (id) => _person(id, 'Ravi', 'Son'));

      // A brand-new service on the SAME storage: what happens when the app is
      // closed and reopened.
      final reopened = MemoryAidService(storage);
      final loaded = await reopened.people.loadAll();

      expect(loaded.single.name, 'Ravi');
      expect(loaded.single.relationship, 'Son');
    });

    test('update changes one item and leaves the rest alone', () async {
      final service = await _newService();

      var people = await service.people.add(
        const [],
        (id) => _person(id, 'Ravi', 'Son'),
      );
      people = await service.people.add(
        people,
        (id) => _person(id, 'Meena', 'Daughter'),
      );

      people = await service.people.update(
        people,
        people.first.copyWith(phone: '9876543210'),
      );

      expect(people.first.phone, '9876543210');
      expect(people.last.phone, ''); // untouched
      expect(people.length, 2);
    });

    test('remove deletes only the requested item', () async {
      final service = await _newService();

      var people = await service.people.add(const [], (id) => _person(id, 'A', ''));
      people = await service.people.add(people, (id) => _person(id, 'B', ''));
      people = await service.people.add(people, (id) => _person(id, 'C', ''));

      people = await service.people.remove(people, 2);

      expect(people.map((p) => p.name).toList(), ['A', 'C']);
    });

    test('the three stores use separate keys and do not overwrite each other',
        () async {
      final storage = InMemoryStorage();
      final service = await _newService(storage);

      await service.people.add(const [], (id) => _person(id, 'Ravi', 'Son'));
      await service.places.add(
        const [],
        (id) => Place(id: id, name: 'Home', createdAt: DateTime(2026, 1, 1)),
      );
      await service.notes.add(
        const [],
        (id) => MemoryNote(
          id: id,
          title: 'Bank',
          content: 'Account details',
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        ),
      );

      final data = await service.loadAll();
      expect(data.people.length, 1);
      expect(data.places.length, 1);
      expect(data.notes.length, 1);
    });

    test('corrupt saved data gives an empty list, not a crash', () async {
      final storage = InMemoryStorage();
      await storage.init();
      await storage.writeString('people_v1', 'not json at all');

      expect(await MemoryAidService(storage).people.loadAll(), isEmpty);
    });
  });

  group('models', () {
    test('a note records when it was changed', () {
      final created = DateTime(2026, 1, 1);
      final note = MemoryNote(
        id: 1,
        title: 'Bank',
        content: 'Old',
        createdAt: created,
        updatedAt: created,
      );

      final edited = note.copyWith(content: 'New');

      expect(edited.createdAt, created); // unchanged
      expect(edited.updatedAt.isAfter(created), isTrue);
    });

    test('a long note is shortened for the list card', () {
      final note = MemoryNote(
        id: 1,
        title: 'Long',
        content: 'x' * 200,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      expect(note.preview.length, 93); // 90 characters plus '...'
      expect(note.preview.endsWith('...'), isTrue);
    });

    test('a person with no name still has an avatar letter', () {
      expect(_person(1, '', '').initial, '?');
      expect(_person(1, 'ravi', 'Son').initial, 'R');
    });
  });

  group('search', () {
    test('finds matches across people, places and notes', () async {
      final service = await _newService();
      final data = MemoryAidData(
        people: [_person(1, 'Priya', 'Daughter')],
        places: [
          Place(
            id: 1,
            name: 'Priya Hospital',
            createdAt: DateTime(2026, 1, 1),
          ),
        ],
        notes: [
          MemoryNote(
            id: 1,
            title: 'My Daughter',
            content: "Priya's birthday is September 12",
            createdAt: DateTime(2026, 1, 1),
            updatedAt: DateTime(2026, 1, 1),
          ),
        ],
      );

      final results = service.search(data, 'priya');

      expect(results.length, 3);
      expect(
        results.map((r) => r.kind).toSet(),
        {
          SearchResultKind.person,
          SearchResultKind.place,
          SearchResultKind.note,
        },
      );
    });

    test('search ignores capital letters', () async {
      final service = await _newService();
      final data = MemoryAidData(people: [_person(1, 'Ravi', 'Son')]);

      expect(service.search(data, 'RAVI').length, 1);
      expect(service.search(data, 'ravi').length, 1);
    });

    test('an empty query returns nothing rather than everything', () async {
      final service = await _newService();
      final data = MemoryAidData(people: [_person(1, 'Ravi', 'Son')]);

      expect(service.search(data, ''), isEmpty);
      expect(service.search(data, '   '), isEmpty);
    });

    test('search also looks at relationship and phone', () async {
      final service = await _newService();
      final data = MemoryAidData(
        people: [_person(1, 'Ravi', 'Son', phone: '9876543210')],
      );

      expect(service.search(data, 'son').length, 1);
      expect(service.search(data, '98765').length, 1);
      expect(service.search(data, 'nothing here'), isEmpty);
    });
  });
}
