import 'package:flutter/material.dart';

import '../theme/app_sizes.dart';
import '../theme/app_theme.dart';

/// One card in "Today's Overview".
///
/// Built once and reused three times on the Home screen. If we later decide
/// overview cards need a badge or a chevron, we change it here only.
class OverviewCard extends StatelessWidget {
  const OverviewCard({
    super.key,
    required this.icon,
    required this.accentColor,
    required this.title,
    required this.message,
    this.onTap,
  });

  final IconData icon;
  final Color accentColor;
  final String title;
  final String message;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      container: true,
      button: onTap != null,
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
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: AppSizes.iconMedium,
                  ),
                ),
                const SizedBox(width: AppSizes.gap),
                // Expanded stops long text from overflowing on narrow phones.
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: textTheme.titleMedium),
                      const SizedBox(height: 6),
                      Text(message, style: textTheme.bodyMedium),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
