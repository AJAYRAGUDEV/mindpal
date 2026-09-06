import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_exception.dart';

/// Runs a save/delete and turns any failure into a readable message.
///
/// Returns the action's value on success, or null if it failed. So the caller
/// reads as:
///
///     final updated = await runGuarded(context, () => store.remove(list, id));
///     if (updated != null) setState(() => list = updated);
///
/// Writing this once means every screen in the Memory section fails the same
/// way — an AppException shows its friendly message, anything unexpected shows
/// a generic one, and nothing ever reaches the user as a stack trace.
///
/// Note `context.mounted`: after an `await`, the screen may already be gone,
/// and touching a dead BuildContext crashes. Every use of context after an
/// await in this app is guarded like this.
Future<T?> runGuarded<T>(
  BuildContext context,
  Future<T> Function() action, {
  String? successMessage,
}) async {
  try {
    final result = await action();
    if (context.mounted && successMessage != null) {
      _showMessage(context, successMessage);
    }
    return result;
  } on AppException catch (error) {
    if (context.mounted) _showMessage(context, error.message, isError: true);
    return null;
  } catch (_) {
    if (context.mounted) {
      _showMessage(context, 'Something went wrong. Please try again.',
          isError: true);
    }
    return null;
  }
}

void _showMessage(BuildContext context, String text, {bool isError = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(text),
      backgroundColor: isError ? AppColors.error : AppColors.primaryDark,
    ),
  );
}
