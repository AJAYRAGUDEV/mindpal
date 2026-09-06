import 'package:flutter/foundation.dart';

import '../models/user_profile.dart';
import '../storage/local_storage.dart';
import '../utils/app_exception.dart';

/// Turns raw storage strings into a UserProfile and back.
///
/// The service is where "what should happen when things go wrong" is decided.
/// Screens never touch storage keys or JSON.
class ProfileService {
  ProfileService(this._storage);

  final LocalStorage _storage;

  /// Versioned key. If the shape of the data ever changes incompatibly we
  /// bump to _v2 and old data is simply ignored instead of crashing.
  static const String _profileKey = 'user_profile_v1';

  Future<UserProfile> load() async {
    final raw = _storage.readString(_profileKey);
    if (raw == null || raw.isEmpty) {
      return UserProfile.empty; // first launch
    }
    try {
      return UserProfile.fromJson(raw);
    } catch (error, stackTrace) {
      // Corrupt data must never block the app from opening.
      // We log it and start the user from a blank profile.
      debugPrint('Could not parse saved profile: $error\n$stackTrace');
      return UserProfile.empty;
    }
  }

  Future<void> save(UserProfile profile) async {
    try {
      await _storage.writeString(_profileKey, profile.toJson());
    } catch (error) {
      throw AppException(
        'We could not save your details. Please try again.',
        cause: error,
      );
    }
  }
}
