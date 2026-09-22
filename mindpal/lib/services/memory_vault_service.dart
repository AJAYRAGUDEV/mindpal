import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

import '../models/vault_memory.dart';
import '../storage/json_list_store.dart';
import '../storage/local_storage.dart';
import '../storage/media/media_store.dart';

/// A newly chosen photo or video, held in memory until the memory is saved.
///
/// The edit screen does not write media the moment it is picked. If it did,
/// a user who picks a photo and then taps Cancel would leave an orphan file
/// behind. Instead the bytes wait here, and [MemoryVaultService.commit]
/// writes them only when the whole memory is saved.
class PendingMedia {
  const PendingMedia({required this.bytes, required this.extension});

  final Uint8List bytes;
  final String extension;

  int get sizeInBytes => bytes.length;
}

/// What the edit screen hands back: the record, plus any media changes.
class MemoryDraft {
  const MemoryDraft({
    required this.memory,
    this.newPhoto,
    this.removePhoto = false,
    this.newVideo,
    this.removeVideo = false,
  });

  final VaultMemory memory;

  final PendingMedia? newPhoto;
  final bool removePhoto;

  final PendingMedia? newVideo;
  final bool removeVideo;
}

/// The Memory Vault's data layer: records in the JSON store, bytes in the
/// media store, and the rules that keep the two in step.
///
/// The one rule that matters: **a record and its media are changed together
/// or not at all.** Saving a memory with a new photo writes the photo first
/// and the record second, so a record never points at a file that does not
/// exist. Deleting a memory removes the record first and the files second,
/// so a failed file delete leaves an orphan file (harmless) rather than a
/// record pointing at nothing (a broken card).
class MemoryVaultService {
  MemoryVaultService(LocalStorage storage, {MediaStore? media})
    : store = JsonListStore<VaultMemory>(
        storage: storage,
        key: 'memory_vault_v1',
        label: 'memory',
        toMap: (memory) => memory.toMap(),
        fromMap: VaultMemory.fromMap,
      ),
      _media = media ?? createMediaStore();

  final JsonListStore<VaultMemory> store;
  MediaStore _media;

  bool _mediaReady = false;

  /// Opens the media store. Safe to call more than once.
  ///
  /// If the platform store cannot open, the vault carries on with an
  /// in-memory one for this session: text saves still persist, media is
  /// kept until the app closes, and the user is not shown a dead screen.
  Future<void> init() async {
    if (_mediaReady) return;
    try {
      await _media.init();
    } catch (error, stackTrace) {
      debugPrint('Media store failed to open: $error\n$stackTrace');
      _media = InMemoryMediaStore();
      await _media.init();
    }
    _mediaReady = true;
  }

  /// Newest first: the memory just added is the one the user wants to see.
  Future<List<VaultMemory>> loadAll() async {
    final all = await store.loadAll();
    all.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return all;
  }

  /// Applies a draft: writes new media, releases replaced media, then saves
  /// the record. Returns the updated list.
  Future<List<VaultMemory>> commit(
    List<VaultMemory> current,
    MemoryDraft draft,
  ) async {
    await init();
    var memory = draft.memory;

    // Media first, record second (see the class note).
    if (draft.newPhoto != null) {
      final ref = await _media.save(
        bytes: draft.newPhoto!.bytes,
        extension: draft.newPhoto!.extension,
      );
      memory = memory.copyWith(photoRef: ref);
    } else if (draft.removePhoto) {
      memory = memory.copyWith(clearPhoto: true);
    }

    if (draft.newVideo != null) {
      final ref = await _media.save(
        bytes: draft.newVideo!.bytes,
        extension: draft.newVideo!.extension,
      );
      memory = memory.copyWith(videoRef: ref);
    } else if (draft.removeVideo) {
      memory = memory.copyWith(clearVideo: true);
    }

    final isNew = memory.id == 0;
    final existing = isNew
        ? null
        : current.where((item) => item.id == memory.id).firstOrNull;

    final saved = memory;
    final updated = isNew
        ? await store.add(current, (id) => saved.copyWith(id: id))
        : await store.update(current, saved);

    // Only now, with the record safely pointing elsewhere, release the media
    // it used to point at.
    if (existing != null) {
      if (existing.hasPhoto && existing.photoRef != saved.photoRef) {
        await _deleteQuietly(existing.photoRef!);
      }
      if (existing.hasVideo && existing.videoRef != saved.videoRef) {
        await _deleteQuietly(existing.videoRef!);
      }
    }

    return _sorted(updated);
  }

  Future<List<VaultMemory>> remove(
    List<VaultMemory> current,
    VaultMemory memory,
  ) async {
    await init();
    final updated = await store.remove(current, memory.id);
    if (memory.hasPhoto) await _deleteQuietly(memory.photoRef!);
    if (memory.hasVideo) await _deleteQuietly(memory.videoRef!);
    return _sorted(updated);
  }

  Future<Uint8List?> readMedia(String ref) async {
    await init();
    return _media.read(ref);
  }

  Future<VideoPlayerController?> videoController(String ref) async {
    await init();
    return _media.videoController(ref);
  }

  /// Two sample memories for a presentation, tagged so they read as samples.
  ///
  /// Text only: shipping someone's photo as "your family" would be a lie in
  /// exactly the place this app must not lie. The photo and video flow is the
  /// real one — the presenter adds a picture from the device in a few taps.
  /// Both entries delete like any other memory.
  Future<List<VaultMemory>> addDemoMemories(List<VaultMemory> current) async {
    final now = DateTime.now();
    var updated = current;

    updated = await store.add(
      updated,
      (id) => VaultMemory(
        id: id,
        title: "Ajay's birthday",
        story: 'We celebrated Ajay\'s birthday together at home. Everyone '
            'came, and there was a big chocolate cake.',
        date: DateTime(now.year, 3, 14),
        personName: 'Ajay',
        relationship: 'Son',
        category: MemoryCategory.family,
        isDemo: true,
        createdAt: now.subtract(const Duration(minutes: 1)),
      ),
    );

    updated = await store.add(
      updated,
      (id) => VaultMemory(
        id: id,
        title: 'Our trip to Shillong',
        story: 'A cool morning walk by Ward\'s Lake, and tea afterwards at '
            'the little shop near the market.',
        date: DateTime(now.year - 1, 11, 2),
        category: MemoryCategory.places,
        isDemo: true,
        createdAt: now,
      ),
    );

    return _sorted(updated);
  }

  Future<void> _deleteQuietly(String ref) async {
    try {
      await _media.delete(ref);
    } catch (error) {
      // An orphan file is harmless; a failed delete must not fail the save.
      debugPrint('Could not delete media $ref: ${error.runtimeType}');
    }
  }

  List<VaultMemory> _sorted(List<VaultMemory> list) =>
      [...list]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
}
