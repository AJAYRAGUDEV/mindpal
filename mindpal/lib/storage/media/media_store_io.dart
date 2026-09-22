import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:video_player/video_player.dart';

import 'media_store.dart';

MediaStore createPlatformMediaStore() => FileMediaStore();

/// Android (and desktop) media storage: files in the app's own documents
/// directory.
///
/// Why the documents directory and not the cache: Android may clear the
/// cache whenever it is short of space, and a memory whose photo vanished
/// would be exactly the kind of loss this app exists to prevent. Documents
/// persist until the app is uninstalled.
///
/// Why copy at all, rather than remembering where the picker found the
/// photo: the picker hands over a temporary copy, and the original lives in
/// the gallery, which the app has no permission to read later. Copying the
/// bytes into the app's own folder is what makes the memory the app's own.
///
/// No Android permission is needed for any of this. The directory belongs to
/// the app; the picker is a system UI that returns the file the user chose.
class FileMediaStore implements MediaStore {
  Directory? _dir;

  @override
  Future<void> init() async {
    // The platform interface rather than the path_provider umbrella package:
    // the umbrella drags in the iOS/macOS backend, whose native build hook
    // cannot run on this machine. This app ships on Android and the web, so
    // only path_provider_android is declared, and it registers itself here.
    final docsPath = await PathProviderPlatform.instance
        .getApplicationDocumentsPath();
    if (docsPath == null) {
      throw StateError('No documents directory on this platform.');
    }
    final dir = Directory('$docsPath${Platform.pathSeparator}memory_vault');
    if (!await dir.exists()) await dir.create(recursive: true);
    _dir = dir;
  }

  Directory get _root {
    final dir = _dir;
    if (dir == null) throw StateError('FileMediaStore.init() was not awaited.');
    return dir;
  }

  File _fileFor(String ref) =>
      File('${_root.path}${Platform.pathSeparator}$ref');

  @override
  Future<String> save({
    required Uint8List bytes,
    required String extension,
  }) async {
    // Time-based name: unique enough for one device, and sorts by age.
    final ref = '${DateTime.now().microsecondsSinceEpoch}.$extension';
    await _fileFor(ref).writeAsBytes(bytes, flush: true);
    return ref;
  }

  @override
  Future<Uint8List?> read(String ref) async {
    final file = _fileFor(ref);
    if (!await file.exists()) return null;
    try {
      return await file.readAsBytes();
    } catch (error) {
      debugPrint('Could not read media $ref: ${error.runtimeType}');
      return null;
    }
  }

  @override
  Future<void> delete(String ref) async {
    final file = _fileFor(ref);
    if (await file.exists()) await file.delete();
  }

  @override
  Future<VideoPlayerController?> videoController(String ref) async {
    final file = _fileFor(ref);
    if (!await file.exists()) return null;
    return VideoPlayerController.file(file);
  }
}
