import 'package:flutter/material.dart';

import '../theme/app_sizes.dart';
import '../theme/app_theme.dart';

/// A card for one saved item — a person, a place, or a note.
///
/// One widget for all three because they share a shape: something on the left,
/// a bold title, a quieter line under it, and a tap that opens it. The three
/// list screens differ only in what they put in these slots.
class EntryCard extends StatelessWidget {
  const EntryCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.onTap,
    this.icon,
    this.initial,
    this.trailingLine,
  });

  final String title;
  final String subtitle;
  final Color accentColor;
  final VoidCallback onTap;

  /// Use [icon] for places and notes.
  final IconData? icon;

  /// Use [initial] for people — a big letter reads as "a person" far more
  /// clearly than a generic silhouette icon, and it differs per person.
  final String? initial;

  /// A third, smaller line, e.g. a phone number or a date.
  final String? trailingLine;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      button: true,
      label: trailingLine == null
          ? '$title. $subtitle'
          : '$title. $subtitle. $trailingLine',
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSizes.radius),
          child: Container(
            constraints: const BoxConstraints(
              minHeight: AppSizes.minTouchTarget,
            ),
            padding: const EdgeInsets.all(AppSizes.cardPadding),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSizes.radius),
              border: Border.all(color: AppColors.border, width: 1.5),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: initial != null
                      ? Text(
                          initial!,
                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        )
                      : Icon(icon, size: 32, color: Colors.white),
                ),
                const SizedBox(width: AppSizes.gap),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: textTheme.titleLarge),
                      if (subtitle.trim().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(subtitle, style: textTheme.bodyMedium),
                      ],
                      if (trailingLine != null &&
                          trailingLine!.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          trailingLine!,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ],
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
}
