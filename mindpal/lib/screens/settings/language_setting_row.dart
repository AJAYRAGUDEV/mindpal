import 'package:flutter/material.dart';

import '../../l10n/app_language.dart';
import '../../l10n/language_scope.dart';
import '../../theme/app_sizes.dart';
import '../../theme/app_theme.dart';
import 'language_screen.dart';

/// The row on the Profile screen that opens the language picker.
///
/// It replaces the Day 1 dropdown, which listed Tamil, Telugu, Kannada and
/// Malayalam — South Indian languages that have nothing to do with a
/// North-Eastern app. That was a mistake in the original scaffold.
///
/// A row that opens a full screen beats a dropdown here: ten languages in
/// their own scripts do not fit in a dropdown at this font size, and the full
/// screen has room to say honestly which ones are translated.
class LanguageSettingRow extends StatelessWidget {
  const LanguageSettingRow({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = LanguageScope.of(context);
    final language = strings.language;

    return Semantics(
      button: true,
      label: '${strings.appLanguage}: ${language.englishName}',
      excludeSemantics: true,
      onTap: () => _open(context),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () => _open(context),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            constraints: const BoxConstraints(minHeight: 84),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border, width: 2),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.translate_rounded,
                  size: 32,
                  color: AppColors.primary,
                ),
                const SizedBox(width: AppSizes.gap),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        language.endonym,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        language.englishName,
                        style: const TextStyle(
                          fontSize: 17,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      // Never let the user believe a draft translation is
                      // finished work.
                      if (language.ui == CapabilityStatus.draft)
                        Text(
                          strings.translationDraft,
                          style: const TextStyle(
                            fontSize: 15,
                            color: AppColors.reminder,
                          ),
                        ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 32,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const LanguageScreen()));
  }
}
