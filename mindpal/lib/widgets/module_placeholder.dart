import 'package:flutter/material.dart';

import '../theme/app_sizes.dart';
import '../theme/app_theme.dart';

/// The shared body for the three "coming soon" module screens.
///
/// One widget instead of three near-identical screens. When MindPal, Reminders
/// and Memory get real content on Days 2-4, each screen replaces this widget
/// and the others are untouched.
class ModulePlaceholder extends StatelessWidget {
  const ModulePlaceholder({
    super.key,
    required this.icon,
    required this.accentColor,
    required this.message,
    required this.note,
  });

  final IconData icon;
  final Color accentColor;

  /// The main sentence, e.g. "Your daily reminders will appear here."
  final String message;

  /// A short reassurance line under it.
  final String note;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    // SingleChildScrollView keeps this usable when the user has cranked up
    // the system font size and the content no longer fits the screen.
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSizes.pagePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: AppSizes.gapLarge),
          Container(
            width: 104,
            height: 104,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Icon(icon, size: 52, color: Colors.white),
          ),
          const SizedBox(height: AppSizes.gapLarge),
          Text(
            message,
            textAlign: TextAlign.center,
            style: textTheme.headlineSmall,
          ),
          const SizedBox(height: AppSizes.gap),
          Text(note, textAlign: TextAlign.center, style: textTheme.bodyMedium),
          const SizedBox(height: AppSizes.gapLarge),
          const _OfflineNote(),
        ],
      ),
    );
  }
}

/// Small trust cue: this app keeps working without internet.
class _OfflineNote extends StatelessWidget {
  const _OfflineNote();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.offline_bolt_outlined, color: AppColors.primary),
        const SizedBox(width: AppSizes.gapSmall),
        Flexible(
          child: Text(
            'Works without internet',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.primaryDark),
          ),
        ),
      ],
    );
  }
}
