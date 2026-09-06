import 'package:flutter/material.dart';

import '../theme/app_sizes.dart';
import '../theme/app_theme.dart';

/// The shared frame for the People, Places and Notes list screens.
///
/// All three need: a title bar, one very large "Add" button at the top, a list,
/// and a friendly empty state. Building that once means the three screens
/// underneath it are about forty lines each and cannot drift apart visually.
///
/// The Add button sits at the TOP of the page rather than in a floating circle
/// in the corner. A floating action button is a small unlabelled circle — one
/// of the least discoverable controls in Material Design, and a poor fit for
/// users who rely on reading the words.
class EntryListScaffold extends StatelessWidget {
  const EntryListScaffold({
    super.key,
    required this.title,
    required this.addLabel,
    required this.onAdd,
    required this.items,
    required this.accentColor,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptyMessage,
  });

  final String title;
  final String addLabel;
  final VoidCallback onAdd;

  /// The already-built cards. The parent decides what a row looks like.
  final List<Widget> items;

  final Color accentColor;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSizes.pagePadding),
          children: [
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded, size: 34),
              label: Text(addLabel),
            ),
            const SizedBox(height: AppSizes.gapLarge),
            if (items.isEmpty)
              _EmptyState(
                icon: emptyIcon,
                accentColor: accentColor,
                title: emptyTitle,
                message: emptyMessage,
              )
            else
              for (final item in items) ...[
                item,
                const SizedBox(height: AppSizes.gap),
              ],
            const SizedBox(height: AppSizes.gap),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.accentColor,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final Color accentColor;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: AppSizes.gap),
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: accentColor,
            borderRadius: BorderRadius.circular(26),
          ),
          child: Icon(icon, size: 50, color: Colors.white),
        ),
        const SizedBox(height: AppSizes.gapLarge),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: AppSizes.gapSmall),
        Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

/// A full-width delete button with the app's error colour.
///
/// Used at the bottom of every edit form. Kept here so "how do we present a
/// destructive action?" is answered in one place.
class DeleteEntryButton extends StatelessWidget {
  const DeleteEntryButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.error,
        side: const BorderSide(color: AppColors.error, width: 2),
      ),
      icon: const Icon(Icons.delete_outline_rounded, size: 28),
      label: Text(label),
    );
  }
}
