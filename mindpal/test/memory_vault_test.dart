import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mindpal/models/vault_memory.dart';
import 'package:mindpal/services/memory_vault_service.dart';
import 'package:mindpal/storage/local_storage.dart';
import 'package:mindpal/storage/media/media_store.dart';

void main() {
  group('VaultMemory', () {
    test('survives a round trip through JSON', () {
      final original = VaultMemory(
        id: 7,
        title: "Ajay's birthday",
        story: 'Cake at home.',
        date: DateTime(2026, 3, 14),
        personName: 'Ajay',
        relationship: 'Son',
        category: MemoryCategory.family,
        photoRef: '123.jpg',
        videoRef: '124.mp4',
        isDemo: true,
        createdAt: DateTime(2026, 9, 22, 10, 30),
      );

      final copy = VaultMemory.fromMap(original.toMap());

      expect(copy.id, 7);
      expect(copy.title, "Ajay's birthday");
      expect(copy.story, 'Cake at home.');
      expect(copy.date, DateTime(2026, 3, 14));
      expect(copy.personName, 'Ajay');
      expect(copy.relationship, 'Son');
      expect(copy.category, MemoryCategory.family);
      expect(copy.photoRef, '123.jpg');
      expect(copy.videoRef, '124.mp4');
      expect(copy.isDemo, isTrue);
      expect(copy.createdAt, DateTime(2026, 9, 22, 10, 30));
    });

    test('tolerates missing and unknown fields from an older save', () {
      final memory = VaultMemory.fromMap({'id': 1, 'title': 'Old', 'category': 'nope'});

      expect(memory.title, 'Old');
      expect(memory.story, '');
      expect(memory.date, isNull);
      expect(memory.category, MemoryCategory.other);
      expect(memory.hasPhoto, isFalse);
      expect(memory.hasVideo, isFalse);
    });

    test('personLabel reads naturally', () {
      final base = VaultMemory(id: 1, title: 't', createdAt: _epoch);
      expect(base.personLabel, '');
      expect(base.copyWith(personName: 'Ajay').personLabel, 'Ajay');
      expect(
        base.copyWith(personName: 'Ajay', relationship: 'Son').personLabel,
        'Ajay, son',
      );
    });

    test('copyWith can clear media and date explicitly', () {
      final full = VaultMemory(
        id: 1,
        title: 't',
        createdAt: _epoch,
        date: DateTime(2020),
        photoRef: 'p.jpg',
        videoRef: 'v.mp4',
      );

      final cleared = full.copyWith(clearDate: true, clearPhoto: true, clearVideo: true);

      expect(cleared.date, isNull);
      expect(cleared.hasPhoto, isFalse);
      expect(cleared.hasVideo, isFalse);
      // And a plain copyWith leaves them alone.
      expect(full.copyWith(title: 'x').photoRef, 'p.jpg');
    });
  });

  group('MemoryVaultService', () {
    late InMemoryStorage storage;
    late InMemoryMediaStore media;
    late MemoryVaultService service;

    setUp(() async {
      storage = InMemoryStorage();
      await storage.init();
      media = InMemoryMediaStore();
      service = MemoryVaultService(storage, media: media);
      await service.init();
    });

    VaultMemory draft(String title) =>
        VaultMemory(id: 0, title: title, createdAt: DateTime.now());

    test('starts empty and persists what is committed', () async {
      expect(await service.loadAll(), isEmpty);

      final list = await service.commit(
        const [],
        MemoryDraft(memory: draft('First')),
      );

      expect(list.single.title, 'First');
      expect(list.single.id, 1);

      // A fresh service over the same storage sees it: it was saved.
      final again = MemoryVaultService(storage, media: InMemoryMediaStore());
      expect((await again.loadAll()).single.title, 'First');
    });

    test('writes new media to the media store and the ref to the record', () async {
      final photo = Uint8List.fromList([1, 2, 3]);

      final list = await service.commit(
        const [],
        MemoryDraft(
          memory: draft('With photo'),
          newPhoto: PendingMedia(bytes: photo, extension: 'jpg'),
        ),
      );

      final saved = list.single;
      expect(saved.hasPhoto, isTrue);
      expect(saved.photoRef, endsWith('.jpg'));
      expect(await service.readMedia(saved.photoRef!), photo);
      expect(media.count, 1);
    });

    test('replacing a photo releases the old bytes', () async {
      var list = await service.commit(
        const [],
        MemoryDraft(
          memory: draft('Photo'),
          newPhoto: PendingMedia(bytes: Uint8List.fromList([1]), extension: 'jpg'),
        ),
      );
      final oldRef = list.single.photoRef!;

      list = await service.commit(
        list,
        MemoryDraft(
          memory: list.single,
          newPhoto: PendingMedia(bytes: Uint8List.fromList([2]), extension: 'png'),
        ),
      );

      expect(list.single.photoRef, isNot(oldRef));
      expect(await service.readMedia(oldRef), isNull);
      expect(media.count, 1);
    });

    test('removing a photo clears the ref and deletes the bytes', () async {
      var list = await service.commit(
        const [],
        MemoryDraft(
          memory: draft('Photo'),
          newPhoto: PendingMedia(bytes: Uint8List.fromList([1]), extension: 'jpg'),
        ),
      );

      list = await service.commit(
        list,
        MemoryDraft(memory: list.single, removePhoto: true),
      );

      expect(list.single.hasPhoto, isFalse);
      expect(media.count, 0);
    });

    test('deleting a memory deletes its media too', () async {
      final list = await service.commit(
        const [],
        MemoryDraft(
          memory: draft('Both'),
          newPhoto: PendingMedia(bytes: Uint8List.fromList([1]), extension: 'jpg'),
          newVideo: PendingMedia(bytes: Uint8List.fromList([2]), extension: 'mp4'),
        ),
      );
      expect(media.count, 2);

      final after = await service.remove(list, list.single);

      expect(after, isEmpty);
      expect(media.count, 0);
      expect(await service.loadAll(), isEmpty);
    });

    test('newest memory comes first', () async {
      var list = await service.commit(const [], MemoryDraft(memory: draft('Older')));
      await Future<void>.delayed(const Duration(milliseconds: 5));
      list = await service.commit(list, MemoryDraft(memory: draft('Newer')));

      expect(list.first.title, 'Newer');
      expect((await service.loadAll()).first.title, 'Newer');
    });

    test('demo memories are tagged and deletable like any other', () async {
      final list = await service.addDemoMemories(const []);

      expect(list, hasLength(2));
      expect(list.every((memory) => memory.isDemo), isTrue);

      final after = await service.remove(list, list.first);
      expect(after, hasLength(1));
    });
  });

  group('extensionOf', () {
    test('lower-cases and validates', () {
      expect(extensionOf('IMG_2041.JPG', fallback: 'jpg'), 'jpg');
      expect(extensionOf('clip.mp4', fallback: 'mp4'), 'mp4');
      expect(extensionOf('no-extension', fallback: 'jpg'), 'jpg');
      expect(extensionOf('trailing.', fallback: 'jpg'), 'jpg');
      expect(extensionOf('weird.j p g', fallback: 'jpg'), 'jpg');
      expect(extensionOf(null, fallback: 'mp4'), 'mp4');
    });
  });
}

final _epoch = DateTime.utc(2020);
