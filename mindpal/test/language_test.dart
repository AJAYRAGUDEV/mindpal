import 'package:flutter_test/flutter_test.dart';
import 'package:mindpal/l10n/app_language.dart';
import 'package:mindpal/l10n/app_strings.dart';
import 'package:mindpal/l10n/translations.dart';
import 'package:mindpal/services/language_service.dart';
import 'package:mindpal/storage/local_storage.dart';

void main() {
  group('language registry', () {
    test('covers the North-Eastern languages we promised', () {
      final codes = kAppLanguages.map((language) => language.code).toSet();

      // The eight NER states' major languages, plus English.
      for (final expected in [
        'en', 'as', 'bn', 'ne', 'brx', 'mni', 'lus', 'kha', 'grt', 'trp',
      ]) {
        expect(codes, contains(expected), reason: '$expected is missing');
      }
    });

    test('every language code is unique', () {
      final codes = kAppLanguages.map((language) => language.code).toList();
      expect(codes.length, codes.toSet().length);
    });

    test('an unknown or missing code falls back to English', () {
      expect(languageForCode(null).code, 'en');
      expect(languageForCode('').code, 'en');
      expect(languageForCode('klingon').code, 'en');
      expect(languageForCode('as').code, 'as');
    });

    test('every language has a name in its own script', () {
      for (final language in kAppLanguages) {
        expect(language.endonym.trim(), isNotEmpty);
        expect(language.englishName.trim(), isNotEmpty);
      }
    });
  });

  group('honesty of the capability matrix', () {
    // These tests exist to stop the app quietly over-claiming. If someone
    // marks a capability as working, they have to change the test too — which
    // forces the question "did you actually test it?"

    test('no language claims VERIFIED AI until someone has tested it', () {
      // The generative path exists now, so `notAvailable` is no longer the
      // honest answer. What must stay true is that nobody marks a language
      // verified without running real requests in it. Changing this test is
      // the deliberate speed bump that forces that question to be asked.
      for (final language in kAppLanguages) {
        expect(
          language.textAi,
          isNot(CapabilityStatus.verified),
          reason: '${language.englishName} claims tested AI support',
        );
      }
    });

    test('no language claims tested speech, because none has been run', () {
      for (final language in kAppLanguages) {
        expect(language.speechToText, isNot(CapabilityStatus.verified));
        expect(language.textToSpeech, isNot(CapabilityStatus.verified));
      }
    });

    test('only English claims a verified UI translation', () {
      final verified = kAppLanguages
          .where((language) => language.ui == CapabilityStatus.verified)
          .map((language) => language.code)
          .toList();

      expect(verified, ['en']);
    });

    test('a language marked notAvailable really has no translation table', () {
      for (final language in kAppLanguages) {
        if (language.ui == CapabilityStatus.notAvailable) {
          expect(
            kTranslations.containsKey(language.code),
            isFalse,
            reason:
                '${language.englishName} has a translation but is marked '
                'unavailable',
          );
        }
      }
    });

    test('a language marked draft really does have a translation table', () {
      for (final language in kAppLanguages) {
        if (language.ui == CapabilityStatus.draft) {
          expect(
            kTranslations[language.code],
            isNotNull,
            reason: '${language.englishName} is marked draft with no strings',
          );
        }
      }
    });
  });

  group('translation completeness', () {
    test('every translation table covers every English key', () {
      for (final entry in kTranslations.entries) {
        final missing = kEnglishStrings.keys
            .where((key) => !entry.value.containsKey(key))
            .toList();

        expect(
          missing,
          isEmpty,
          reason: 'Language "${entry.key}" is missing: ${missing.join(", ")}',
        );
      }
    });

    test('no translation table has keys English does not have', () {
      // A stray key means a typo that would silently never be shown.
      for (final entry in kTranslations.entries) {
        final extra = entry.value.keys
            .where((key) => !kEnglishStrings.containsKey(key))
            .toList();

        expect(extra, isEmpty, reason: 'Language "${entry.key}" has: $extra');
      }
    });

    test('translated text is actually different from English', () {
      // Catches a table that was copied but never translated.
      final assamese = AppStrings.forLanguage(languageForCode('as'));
      final english = AppStrings.forLanguage(kEnglish);

      expect(assamese.navHome, isNot(english.navHome));
      expect(assamese.quickActions, isNot(english.quickActions));
    });
  });

  group('AppStrings fallback', () {
    test('an untranslated language shows English rather than blanks', () {
      final mizo = AppStrings.forLanguage(languageForCode('lus'));

      expect(mizo.language.code, 'lus'); // still the chosen language
      expect(mizo.navHome, 'Home'); // but English text
      expect(mizo.quickActions, 'Quick Actions');
    });

    test('a partly translated language falls back key by key', () {
      // Not a whole-table fallback: only the missing key comes from English.
      final partial = AppStrings(
        language: languageForCode('bn'),
        values: const {'nav_home': 'হোম'},
      );

      expect(partial.navHome, 'হোম');
      expect(partial.navProfile, 'Profile'); // filled in from English
    });

    test('a key missing everywhere shows the key, not a crash', () {
      final broken = AppStrings(
        language: kEnglish,
        values: const {},
      );
      // Every real key exists in English, so this can only be reached by a
      // genuine bug — and then it is visible on screen rather than silent.
      expect(broken.navHome, isNotEmpty);
    });
  });

  group('LanguageService', () {
    test('defaults to English when nothing was ever chosen', () async {
      final storage = InMemoryStorage();
      await storage.init();

      expect((await LanguageService(storage).loadSelected()).code, 'en');
    });

    test('the chosen language survives a restart', () async {
      final storage = InMemoryStorage();
      await storage.init();

      await LanguageService(storage).save(languageForCode('as'));

      // A brand-new service on the same storage: app closed and reopened.
      expect((await LanguageService(storage).loadSelected()).code, 'as');
    });

    test('stores the code, not the whole language object', () async {
      final storage = InMemoryStorage();
      await storage.init();

      await LanguageService(storage).save(languageForCode('ne'));

      expect(storage.readString('app_language_code_v1'), 'ne');
    });
  });
}
