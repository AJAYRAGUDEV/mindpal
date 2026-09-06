import 'package:flutter/foundation.dart';

import '../l10n/app_language.dart';
import '../storage/local_storage.dart';

/// Remembers which language the user chose.
///
/// Stateless and tiny, like ProfileService. It stores only the language CODE
/// ('as', 'bn'), not the whole AppLanguage — so if we later change an
/// endonym, add a capability field, or fix a status, saved settings keep
/// working. Store the identifier, never the whole object.
class LanguageService {
  LanguageService(this._storage);

  final LocalStorage _storage;

  static const String _key = 'app_language_code_v1';

  /// The saved language, or English if nothing has been chosen.
  ///
  /// Never throws: a language setting is not worth failing to launch over.
  Future<AppLanguage> loadSelected() async {
    try {
      return languageForCode(_storage.readString(_key));
    } catch (error) {
      debugPrint('Could not read the language setting: $error');
      return kDefaultLanguage;
    }
  }

  Future<void> save(AppLanguage language) async {
    try {
      await _storage.writeString(_key, language.code);
    } catch (error) {
      // Worth logging, not worth interrupting the user. The language still
      // applies for this session; it just will not survive a restart.
      debugPrint('Could not save the language setting: $error');
    }
  }
}
