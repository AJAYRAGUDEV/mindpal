import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/identifiable.dart';
import '../utils/app_exception.dart';
import 'local_storage.dart';

/// Saves and loads a list of anything, as JSON, under one storage key.
///
/// The `<T>` is a *type parameter* — a blank that gets filled in when you use
/// the class. `JsonListStore<Person>` is a store of people; the exact same
/// code becomes a store of places when you write `JsonListStore<Place>`.
/// This is called a generic, and it is how you write one implementation
/// instead of three near-identical ones.
///
/// `<T extends Identifiable>` is a constraint: T can be any type, as long as
/// that type has an `id`. That is what lets [update] and [remove] find the
/// right item.
///
/// Two more things are passed in, because the store cannot know them:
/// [toMap] and [fromMap] — how to turn a T into plain JSON data and back.
/// Those are FUNCTIONS stored in variables. Dart treats functions as values
/// you can pass around, exactly like numbers or strings.
///
/// Like ReminderService on Day 3, this class is stateless: every method takes
/// the current list and returns a new one. It never holds the list itself, so
/// there is only ever one copy in the app.
class JsonListStore<T extends Identifiable> {
  JsonListStore({
    required this.storage,
    required this.key,
    required this.toMap,
    required this.fromMap,
    required this.label,
  });

  final LocalStorage storage;

  /// The key this list is saved under, e.g. 'people_v1'.
  final String key;

  final Map<String, dynamic> Function(T item) toMap;
  final T Function(Map<String, dynamic> map) fromMap;

  /// Singular, lowercase, used in error messages: "could not save your person".
  final String label;

  Future<List<T>> loadAll() async {
    final raw = storage.readString(key);
    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((item) => fromMap(item as Map<String, dynamic>))
          .toList();
    } catch (error, stackTrace) {
      // Same rule as everywhere else in this app: bad saved data must never
      // stop the app opening. Note we log the ERROR, never the data itself —
      // this list may hold family names and phone numbers.
      debugPrint('Could not read "$key": $error\n$stackTrace');
      return [];
    }
  }

  /// Adds one item, giving it a fresh id.
  ///
  /// [create] is a function that takes the new id and builds the item:
  ///
  ///     await store.add(people, (id) => Person(id: id, name: 'Ravi', ...));
  ///
  /// Passing a builder rather than a finished object is what lets the store
  /// own id assignment — the caller cannot accidentally reuse an id.
  Future<List<T>> add(List<T> current, T Function(int id) create) async {
    final item = create(nextId(current));
    final updated = [...current, item];
    await persist(updated);
    return updated;
  }

  Future<List<T>> update(List<T> current, T item) async {
    final updated = [
      for (final existing in current)
        if (existing.id == item.id) item else existing,
    ];
    await persist(updated);
    return updated;
  }

  Future<List<T>> remove(List<T> current, int id) async {
    // `where` builds a new list without that one item and leaves every other
    // item exactly as it was.
    final updated = current.where((item) => item.id != id).toList();
    await persist(updated);
    return updated;
  }

  /// Ids start at 1 and are one more than the highest in use.
  int nextId(List<T> current) {
    var highest = 0;
    for (final item in current) {
      if (item.id > highest) highest = item.id;
    }
    return highest + 1;
  }

  Future<void> persist(List<T> items) async {
    try {
      await storage.writeString(
        key,
        jsonEncode(items.map(toMap).toList()),
      );
    } catch (error) {
      throw AppException(
        'We could not save your $label. Please try again.',
        cause: error,
      );
    }
  }
}
