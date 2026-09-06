import 'package:flutter/material.dart';

import '../theme/app_sizes.dart';

/// A full-width primary action button.
///
/// Full width plus the 64dp height from the theme gives a very large, hard to
/// miss touch target — the single most useful accessibility win for our users.
class QuickActionButton extends StatelessWidget {
  const QuickActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: AppSizes.iconMedium),
      label: Text(label),
    );
  }
}
