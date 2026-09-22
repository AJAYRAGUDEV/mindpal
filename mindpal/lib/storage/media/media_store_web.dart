import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';
import 'package:web/web.dart' as web;

import 'media_store.dart';

MediaStore createPlatformMediaStore() => IndexedDbMediaStore();

/// Browser media storage: IndexedDB.
///
/// The browser has no filesystem the app may write to, and localStorage is
/// the wrong tool — a ~5 MB cap, strings only, and synchronous. IndexedDB is
/// what browsers provide for exactly this: large binary values, persistent
/// across reloads, scoped to the site. A phone photo is 2-4 MB; a short video
/// 20-50 MB; IndexedDB holds gigabytes on most browsers.
///
/// This is a demo-grade implementation of the same interface Android uses,
/// so the vault behaves identically in the browser. What it is not: shared
/// between browsers or devices. A memory saved in Chrome on this laptop is in
/// Chrome on this laptop. That is a property of the browser, and also the
/// privacy stance of the whole app — nothing is uploaded anywhere.
///
/// Written against package:web with dart:js_interop, which is what Flutter
/// Web compiles to today (dart:html is deprecated). The IndexedDB API is
/// callback-based; each call below wraps one request in a Future.
class IndexedDbMediaStore implements MediaStore {
  static const _dbName = 'mindpal_media';
  static const _storeName = 'files';
  static const _version = 1;

  web.IDBDatabase? _db;

  /// blob: URLs minted for video playback, so the same video does not get a
  /// new one every time it is shown. They are released when the page unloads.
  final Map<String, String> _objectUrls = {};

  @override
  Future<void> init() async {
    final request = web.window.indexedDB.open(_dbName, _version);

    // First open (or a version bump) fires upgradeneeded, and that is the
    // only moment an object store may be created.
    request.onupgradeneeded = ((web.Event _) {
      final db = request.result as web.IDBDatabase;
      if (!db.objectStoreNames.contains(_storeName)) {
        db.createObjectStore(_storeName);
      }
    }).toJS;

    _db = (await _await(request)) as web.IDBDatabase;
  }

  web.IDBDatabase get _database {
    final db = _db;
    if (db == null) {
      throw StateError('IndexedDbMediaStore.init() was not awaited.');
    }
    return db;
  }

  web.IDBObjectStore _store(String mode) =>
      _database.transaction(_storeName.toJS, mode).objectStore(_storeName);

  @override
  Future<String> save({
    required Uint8List bytes,
    required String extension,
  }) async {
    final ref = '${DateTime.now().microsecondsSinceEpoch}.$extension';
    await _await(_store('readwrite').put(bytes.toJS, ref.toJS));
    return ref;
  }

  @override
  Future<Uint8List?> read(String ref) async {
    try {
      final result = await _await(_store('readonly').get(ref.toJS));
      if (result == null || result.isUndefinedOrNull) return null;
      return (result as JSUint8Array).toDart;
    } catch (error) {
      debugPrint('Could not read media $ref: ${error.runtimeType}');
      return null;
    }
  }

  @override
  Future<void> delete(String ref) async {
    await _await(_store('readwrite').delete(ref.toJS));
    final url = _objectUrls.remove(ref);
    if (url != null) web.URL.revokeObjectURL(url);
  }

  @override
  Future<VideoPlayerController?> videoController(String ref) async {
    var url = _objectUrls[ref];
    if (url == null) {
      final bytes = await read(ref);
      if (bytes == null) return null;

      // A blob: URL is how a browser plays bytes it already holds. The MIME
      // type matters: without it some browsers refuse to play at all.
      final blob = web.Blob(
        [bytes.toJS].toJS,
        web.BlobPropertyBag(type: _mimeTypeFor(ref)),
      );
      url = web.URL.createObjectURL(blob);
      _objectUrls[ref] = url;
    }
    return VideoPlayerController.networkUrl(Uri.parse(url));
  }

  static String _mimeTypeFor(String ref) {
    final ext = extensionOf(ref, fallback: 'mp4');
    return switch (ext) {
      'webm' => 'video/webm',
      'mov' => 'video/quicktime',
      'ogv' || 'ogg' => 'video/ogg',
      _ => 'video/mp4',
    };
  }

  /// Turns an IDBRequest into a Future of its result.
  static Future<JSAny?> _await(web.IDBRequest request) {
    final completer = Completer<JSAny?>();
    request.onsuccess = ((web.Event _) {
      if (!completer.isCompleted) completer.complete(request.result);
    }).toJS;
    request.onerror = ((web.Event _) {
      if (!completer.isCompleted) {
        completer.completeError(
          StateError('IndexedDB request failed: ${request.error?.name}'),
        );
      }
    }).toJS;
    return completer.future;
  }
}
