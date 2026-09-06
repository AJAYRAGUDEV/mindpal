import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Asks a yes/no question and returns what the user chose.
///
/// Returns true only if they explicitly confirmed. Tapping outside the dialog
/// or pressing Back both count as "no" — the safe answer for a destructive
/// action, and important when a user may tap the screen by accident.
///
/// Accessibility choices here:
///   * the question is short and literal ("Delete this reminder?"),
///   * Cancel comes first and is the plain button; Delete is the coloured one,
///     so the harmless choice is not the one that stands out,
///   * both buttons are full size, not the tiny text buttons Material uses
///     by default.
Future<bool> confirmDestructiveAction(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Delete',
  String cancelLabel = 'Cancel',
}) async {
  final answer = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title, style: Theme.of(context).textTheme.titleLarge),
      // The buttons live in `content`, not in `actions`. AlertDialog lays
      // `actions` out side by side, which would squash two full-width buttons;
      // stacking them in a Column keeps both at full size.
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            message,
            style: const TextStyle(fontSize: 20, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(cancelLabel),
          ),
          const SizedBox(height: 12),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    ),
  );

  // showDialog returns null when dismissed without a choice.
  return answer ?? false;
}
