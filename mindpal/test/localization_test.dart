import 'package:flutter_test/flutter_test.dart';
import 'package:mindpal/l10n/app_language.dart';
import 'package:mindpal/l10n/app_strings.dart';
import 'package:mindpal/l10n/translations.dart';
import 'package:mindpal/models/reminder.dart';
import 'package:mindpal/models/vault_memory.dart';

/// Guards the two ways a multilingual app quietly starts lying:
/// a table that falls behind English, and a status that claims more than the
/// table delivers.
void main() {
  group('translation tables', () {
    test('every table uses keys English actually has', () {
      for (final entry in kTranslations.entries) {
        final unknown = entry.value.keys
            .where((key) => !kEnglishStrings.containsKey(key))
            .toList();
        expect(
          unknown,
          isEmpty,
          reason: '${entry.key} has keys English does not: $unknown',
        );
      }
    });

    test('no table contains an empty string', () {
      for (final entry in kTranslations.entries) {
        final blank = entry.value.entries
            .where((pair) => pair.value.trim().isEmpty)
            .map((pair) => pair.key)
            .toList();
        expect(blank, isEmpty, reason: '${entry.key} has blanks: $blank');
      }
    });

    test('a missing key falls back to English, never to a blank', () {
      // A language with no table at all: every string must still read.
      final garo = AppStrings.forLanguage(languageForCode('grt'));
      expect(garo.values, isEmpty);
      expect(garo.navHome, kEnglishStrings['nav_home']);
      expect(garo.catMedicine, 'Medicine');
      expect(garo.addMemory, 'Add Memory');
    });
  });

  group('coverage is measured, not claimed', () {
    test('English is complete by definition', () {
      expect(AppStrings.forLanguage(kEnglish).coverage, 1.0);
    });

    test('a language marked usable covers most of the app', () {
      for (final language in kAppLanguages) {
        if (!language.ui.isUsable) continue;
        final coverage = AppStrings.forLanguage(language).coverage;
        expect(
          coverage,
          greaterThanOrEqualTo(0.9),
          reason:
              '${language.englishName} claims ui=${language.ui.name} but '
              'covers only ${(coverage * 100).round()}% of the strings. '
              'Either finish the table or lower the status.',
        );
      }
    });

    test('a language with no table does not claim a usable UI', () {
      for (final language in kAppLanguages) {
        final hasTable = (kTranslations[language.code] ?? const {}).isNotEmpty;
        if (hasTable) continue;
        expect(
          language.ui.isUsable,
          isFalse,
          reason: '${language.englishName} has no table but claims '
              'ui=${language.ui.name}',
        );
      }
    });
  });

  group('enum labels are translatable', () {
    test('every reminder category and repeat resolves in every language', () {
      for (final language in kAppLanguages) {
        final strings = AppStrings.forLanguage(language);
        for (final category in ReminderCategory.values) {
          expect(category.localisedLabel(strings).trim(), isNotEmpty);
        }
        for (final repeat in ReminderRepeat.values) {
          expect(repeat.localisedLabel(strings).trim(), isNotEmpty);
        }
      }
    });

    test('every memory category resolves in every language', () {
      for (final language in kAppLanguages) {
        final strings = AppStrings.forLanguage(language);
        for (final category in MemoryCategory.values) {
          expect(category.localisedLabel(strings).trim(), isNotEmpty);
        }
      }
    });
  });

  group('the language list itself', () {
    test('codes are unique and endonyms are non-empty', () {
      final codes = kAppLanguages.map((language) => language.code).toList();
      expect(codes.toSet().length, codes.length);
      for (final language in kAppLanguages) {
        expect(language.endonym.trim(), isNotEmpty);
        expect(language.englishName.trim(), isNotEmpty);
      }
    });

    test('an unknown code falls back to English rather than throwing', () {
      expect(languageForCode('zz').code, 'en');
      expect(languageForCode(null).code, 'en');
    });
  });
}
