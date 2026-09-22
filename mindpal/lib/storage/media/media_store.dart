import 'dart:typed_data';

import 'package:video_player/video_player.dart';

import 'media_store_stub.dart'
    if (dart.library.io) 'media_store_io.dart'
    if (dart.library.js_interop) 'media_store_web.dart'
    as platform;

/// Where the bytes of photos and videos live.
///
/// This is the one part of the Memory Vault that cannot be the same code on
/// every platform, so it is the one part that is isolated:
///
///   * Android (and any OS with a filesystem): a directory inside the app's
///     private documents folder. Survives restarts and updates, is removed
///     with the app, and needs no permission because it is the app's own.
///   * Web: IndexedDB, the browser's database for large binary data. It
///     persists across reloads, holds hundreds of megabytes, and is per-site.
///     localStorage would not do — it caps at ~5 MB and stores only strings.
///
/// Everything above this interface (the service, the screens) is identical on
/// both platforms. That is the whole point of the interface.
///
/// A [ref] is an opaque key returned by [save]. It is what a VaultMemory
/// stores. It is deliberately NOT an absolute path: on Android the app's
/// documents directory can move between installs, and a stored absolute path
/// would silently break. A relative key is resolved fresh every time.
abstract class MediaStore {
  /// Must be awaited once before use. May throw; the caller decides what to
  /// do then (the service falls back to [InMemoryMediaStore]).
  Future<void> init();

  /// Stores [bytes] and returns the ref to keep in the memory record.
  ///
  /// [extension] is the file extension without a dot ("jpg", "mp4"). It is
  /// kept in the ref so the video player and the browser know the type.
  Future<String> save({required Uint8List bytes, required String extension});

  /// The stored bytes, or null if the ref is unknown or the file is gone.
  /// A null must be handled, never assumed impossible: caches get cleared,
  /// files get deleted, browsers get reset.
  Future<Uint8List?> read(String ref);

  Future<void> delete(String ref);

  /// A player for a stored video, or null if it cannot be played.
  ///
  /// Lives here rather than in a widget because creating one is the only
  /// other platform-specific step: Android plays from a File, the browser
  /// plays from a blob: URL minted from the stored bytes.
  Future<VideoPlayerController?> videoController(String ref);
}

/// Creates the store for the platform this code is compiled for.
///
/// Conditional imports pick the file at COMPILE time: the web build never
/// even sees dart:io, and the Android build never sees package:web.
MediaStore createMediaStore() => platform.createPlatformMediaStore();

/// Keeps everything in memory for the current session only.
///
/// Used by tests, and as the runtime safety net if the real store fails to
/// open — the vault still works for the session rather than crashing. Video
/// playback is not available from it.
class InMemoryMediaStore implements MediaStore {
  final Map<String, Uint8List> _files = {};
  int _counter = 0;

  int get count => _files.length;

  @override
  Future<void> init() async {}

  @override
  Future<String> save({
    required Uint8List bytes,
    required String extension,
  }) async {
    final ref = 'mem_${++_counter}.$extension';
    _files[ref] = Uint8List.fromList(bytes);
    return ref;
  }

  @override
  Future<Uint8List?> read(String ref) async => _files[ref];

  @override
  Future<void> delete(String ref) async {
    _files.remove(ref);
  }

  @override
  Future<VideoPlayerController?> videoController(String ref) async => null;
}

/// "jpg" from "IMG_2041.JPG"; [fallback] when there is no usable extension.
String extensionOf(String? fileName, {required String fallback}) {
  if (fileName == null) return fallback;
  final dot = fileName.lastIndexOf('.');
  if (dot < 0 || dot == fileName.length - 1) return fallback;
  final ext = fileName.substring(dot + 1).toLowerCase();
  // Only plain extensions. A stray query string or path must not become a
  // filename on disk.
  return RegExp(r'^[a-z0-9]{1,5}$').hasMatch(ext) ? ext : fallback;
}
