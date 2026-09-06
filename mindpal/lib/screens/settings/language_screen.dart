import 'package:flutter/material.dart';

import '../../l10n/app_language.dart';
import '../../l10n/language_scope.dart';
import '../../theme/app_sizes.dart';
import '../../theme/app_theme.dart';
import 'capability_matrix_screen.dart';

/// Choose the app language.
///
/// Two accessibility decisions worth noting:
///
/// 1. Each row leads with the language's own name in its own script
///    (অসমীয়া, नेपाली). Someone who reads only Assamese cannot find their
///    language in a list that says "Assamese" — the English name goes second,
///    smaller, for anyone who needs it.
///
/// 2. The list never hides a language. Bodo, Meitei, Mizo, Khasi, Garo and
///    Kokborok have no translation yet, and rather than omitting them (which
///    hides our intent) or pretending they work (which is dishonest), they are
///    shown with a plain notice that English will appear instead.
class LanguageScreen extends StatelessWidget {
  const LanguageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = LanguageScope.scopeOf(context);
    final strings = scope.strings;
    final current = strings.language;

    return Scaffold(
      appBar: AppBar(title: Text(strings.chooseLanguage)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSizes.pagePadding),
          children: [
            Text(
              strings.chooseLanguageSubtitle,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: AppSizes.gapLarge),

            for (final language in kAppLanguages) ...[
              _LanguageTile(
                language: language,
                isSelected: language.code == current.code,
                pendingLabel: strings.translationPending,
                draftLabel: strings.translationDraft,
                selectedLabel: strings.selected,
                onTap: () {
                  scope.onLanguageChanged(language);
                  Navigator.of(context).pop();
                },
              ),
              const SizedBox(height: AppSizes.gap),
            ],

            const SizedBox(height: AppSizes.gap),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const CapabilityMatrixScreen(),
                ),
              ),
              icon: const Icon(Icons.fact_check_outlined, size: 28),
              label: Text(strings.viewCapabilities),
            ),
            const SizedBox(height: AppSizes.gapLarge),
          ],
        ),
      ),
    );
  }
}

class _LanguageTile extends StatelessWidget {
  const _LanguageTile({
    required this.language,
    required this.isSelected,
    required this.pendingLabel,
    required this.draftLabel,
    required this.selectedLabel,
    required this.onTap,
  });

  final AppLanguage language;
  final bool isSelected;
  final String pendingLabel;
  final String draftLabel;
  final String selectedLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Only shown when there is something the user genuinely needs to know.
    final notice = switch (language.ui) {
      CapabilityStatus.notAvailable => pendingLabel,
      CapabilityStatus.draft => draftLabel,
      _ => null,
    };

    return Semantics(
      button: true,
      selected: isSelected,
      label: '${language.endonym}, ${language.englishName}'
          '${isSelected ? ', $selectedLabel' : ''}',
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: isSelected ? AppColors.primarySoft : AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSizes.radius),
          child: Container(
            constraints: const BoxConstraints(minHeight: 84),
            padding: const EdgeInsets.all(AppSizes.cardPadding),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSizes.radius),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.border,
                width: isSelected ? 3 : 1.5,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // The endonym is the headline: it is what a speaker of
                      // this language is scanning for.
                      Text(
                        language.endonym,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        language.englishName,
                        style: const TextStyle(
                          fontSize: 18,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (notice != null) ...[
                        const SizedBox(height: AppSizes.gapSmall),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              language.ui == CapabilityStatus.draft
                                  ? Icons.rate_review_outlined
                                  : Icons.info_outline_rounded,
                              size: 22,
                              color: AppColors.reminder,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                notice,
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: AppColors.reminder,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: AppSizes.gapSmall),
                Icon(
                  isSelected
                      ? Icons.check_circle_rounded
                      : Icons.circle_outlined,
                  size: 34,
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
