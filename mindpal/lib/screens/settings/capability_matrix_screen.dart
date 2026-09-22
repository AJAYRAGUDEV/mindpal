import 'package:flutter/material.dart';

import '../../l10n/app_language.dart';
import '../../l10n/language_scope.dart';
import '../../theme/app_sizes.dart';
import '../../theme/app_theme.dart';

/// The honest capability matrix.
///
/// This screen exists so that nobody — not the team, not a judge — has to
/// guess what actually works. It reads directly from the same constants the
/// app uses at runtime, so it cannot drift out of date: if a language is
/// marked `untested` in code, this screen says untested.
///
/// Read it as: "UI" is the app's own text; "AI" is generated text; "Speech"
/// is speaking to the app; "Voice" is the app speaking back.
class CapabilityMatrixScreen extends StatelessWidget {
  const CapabilityMatrixScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = LanguageScope.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(strings.capabilityTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSizes.pagePadding),
          children: [
            const _HonestyNote(),
            const SizedBox(height: AppSizes.gapLarge),

            for (final language in kAppLanguages) ...[
              _LanguageRow(language: language),
              const SizedBox(height: AppSizes.gap),
            ],

            const _DeviceFeatures(),
            const SizedBox(height: AppSizes.gap),
            const _Legend(),
            const SizedBox(height: AppSizes.gapLarge),
          ],
        ),
      ),
    );
  }
}

class _HonestyNote extends StatelessWidget {
  const _HonestyNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radius),
        border: Border.all(color: AppColors.reminder, width: 2),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What is actually working today',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: AppSizes.gapSmall),
          Text(
            'The AI connection is built but has not been tested in any '
            'language yet, so every language shows "Untested". Speech has no '
            'implementation at all. A row only changes once someone has '
            'actually run that language end to end — not before.',
            style: TextStyle(fontSize: 18, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _LanguageRow extends StatelessWidget {
  const _LanguageRow({required this.language});

  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radius),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${language.endonym}  ·  ${language.englishName}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSizes.gap),

          // Stacked rows rather than a real table: a four-column table is
          // unreadable at this font size on a phone, and would force the user
          // to scroll sideways.
          _CapabilityLine(label: 'App text', status: language.ui),
          _CapabilityLine(label: 'AI replies', status: language.textAi),
          _CapabilityLine(
            label: 'Speech to text',
            status: language.speechToText,
          ),
          _CapabilityLine(
            label: 'Spoken aloud',
            status: language.textToSpeech,
          ),

          if (language.speechLocaleTag == null) ...[
            const SizedBox(height: AppSizes.gapSmall),
            const Text(
              'No standard speech code exists for this language, so device '
              'speech support is unlikely.',
              style: TextStyle(fontSize: 16, color: AppColors.reminder),
            ),
          ],
          if (language.scriptNote != null) ...[
            const SizedBox(height: AppSizes.gapSmall),
            Text(
              language.scriptNote!,
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CapabilityLine extends StatelessWidget {
  const _CapabilityLine({required this.label, required this.status});

  final String label;
  final CapabilityStatus status;

  (IconData, Color) get _mark => switch (status) {
    CapabilityStatus.verified => (
      Icons.check_circle_rounded,
      const Color(0xFF1B5E20),
    ),
    CapabilityStatus.draft => (
      Icons.rate_review_rounded,
      AppColors.reminder,
    ),
    CapabilityStatus.experimental => (
      Icons.science_outlined,
      AppColors.activity,
    ),
    CapabilityStatus.untested => (
      Icons.help_outline_rounded,
      AppColors.textSecondary,
    ),
    CapabilityStatus.notAvailable => (
      Icons.remove_circle_outline_rounded,
      AppColors.textSecondary,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _mark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 24, color: color),
          const SizedBox(width: AppSizes.gapSmall),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 18,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Text(
            status.label,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What the words mean',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSizes.gapSmall),
        for (final status in CapabilityStatus.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '${status.label} — ${status.description}',
              style: const TextStyle(
                fontSize: 17,
                color: AppColors.textSecondary,
              ),
            ),
          ),
      ],
    );
  }
}

/// Features that depend on the device rather than on a language.
///
/// Statuses here are set by hand, deliberately, and must be updated when the
/// facts change. As of 22 September 2026: reminder notifications are built
/// for Android (OS-scheduled alarms, sound, vibration, reboot recovery) and
/// verified as far as compiling, packaging and unit tests go, but have NOT
/// yet been watched firing on a real phone. That is exactly what "untested"
/// means here, and it stays until someone has seen the notification appear.
class _DeviceFeatures extends StatelessWidget {
  const _DeviceFeatures();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radius),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Device features',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSizes.gap),
          const _CapabilityLine(
            label: 'Reminder notifications, Android',
            status: CapabilityStatus.untested,
          ),
          const _CapabilityLine(
            label: 'Reminder notifications, web',
            status: CapabilityStatus.notAvailable,
          ),
          const _CapabilityLine(
            label: 'Memory Vault photos and videos',
            status: CapabilityStatus.experimental,
          ),
          const SizedBox(height: AppSizes.gapSmall),
          const Text(
            "Android reminders use the phone's own alarm system, with sound "
            'and vibration, and are re-armed after a reboot. Built and '
            'unit-tested; delivery on a real phone has not yet been observed. '
            'A browser cannot ring with the page closed, so the web version '
            'keeps the reminder list without alarms.',
            style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
