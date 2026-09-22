import 'media_store.dart';

/// Chosen only on a platform with neither dart:io nor JS interop, which no
/// Flutter target is. It exists so the conditional import always resolves.
MediaStore createPlatformMediaStore() => throw UnsupportedError(
  'No media store for this platform.',
);
