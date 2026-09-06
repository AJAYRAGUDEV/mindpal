import 'package:flutter/material.dart';

import '../../models/reminder.dart';
import '../../theme/app_sizes.dart';
import '../../theme/app_theme.dart';
import '../../utils/date_formats.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/entry_list_scaffold.dart';
import 'add_reminder_screen.dart';

/// What the details screen decided when it closed.
enum ReminderAction { completed, uncompleted, edited, deleted }

class ReminderDetailsResult {
  const ReminderDetailsResult(this.action, [this.reminder]);

  final ReminderAction action;

  /// The updated reminder, for [ReminderAction.edited].
  final Reminder? reminder;
}

/// One reminder in full, with the three things you can do to it.
///
/// Like every other form in this app, it decides nothing itself — it pops a
/// [ReminderDetailsResult] and MainShell (which owns the list) carries it out.
class ReminderDetailsScreen extends StatelessWidget {
  const ReminderDetailsScreen({super.key, required this.reminder});

  final Reminder reminder;

  Future<void> _edit(BuildContext context) async {
    final updated = await Navigator.of(context).push<Reminder>(
      MaterialPageRoute(
        // The add form already handles editing — pass the existing reminder
        // and it pre-fills, keeps the id, and returns the changed version.
        builder: (_) => AddReminderScreen(existing: reminder),
      ),
    );
    if (updated == null || !context.mounted) return;

    Navigator.of(
      context,
    ).pop(ReminderDetailsResult(ReminderAction.edited, updated));
  }

  Future<void> _delete(BuildContext context) async {
    final confirmed = await confirmDestructiveAction(
      context,
      title: 'Delete this reminder?',
      message:
          '"${reminder.title}" will be removed and it will stop reminding '
          'you. This cannot be undone.',
    );
    if (!confirmed || !context.mounted) return;

    Navigator.of(
      context,
    ).pop(const ReminderDetailsResult(ReminderAction.deleted));
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isDone = reminder.isCompletedOn(now);
    final isMissed = reminder.isMissedAt(now);

    return Scaffold(
      appBar: AppBar(title: const Text('Reminder')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSizes.pagePadding),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: reminder.category.color,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    reminder.category.icon,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: AppSizes.gap),
                Expanded(
                  child: Text(
                    reminder.title,
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.gapLarge),

            _DetailRow(label: 'Time', value: reminder.formattedTime, big: true),
            _DetailRow(label: 'Repeats', value: reminder.repeat.label),
            _DetailRow(label: 'Type', value: reminder.category.label),
            _DetailRow(
              label: 'Status',
              value: isDone
                  ? 'Completed today'
                  : (isMissed ? 'Missed — still can be completed' : 'Due later today'),
            ),
            _DetailRow(label: 'Today', value: formatFullDate(now)),
            if (reminder.notes.trim().isNotEmpty)
              _DetailRow(label: 'Notes', value: reminder.notes),

            const SizedBox(height: AppSizes.gapLarge),

            if (isDone)
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).pop(
                  const ReminderDetailsResult(ReminderAction.uncompleted),
                ),
                icon: const Icon(Icons.undo_rounded, size: 28),
                label: const Text('Mark as not done'),
              )
            else
              FilledButton.icon(
                onPressed: () => Navigator.of(context).pop(
                  const ReminderDetailsResult(ReminderAction.completed),
                ),
                icon: const Icon(Icons.check_rounded, size: AppSizes.iconMedium),
                label: const Text('Complete'),
              ),
            const SizedBox(height: AppSizes.gap),

            OutlinedButton.icon(
              onPressed: () => _edit(context),
              icon: const Icon(Icons.edit_outlined, size: 28),
              label: const Text('Edit reminder'),
            ),
            const SizedBox(height: AppSizes.gapLarge),

            DeleteEntryButton(
              label: 'Delete reminder',
              onPressed: () => _delete(context),
            ),
            const SizedBox(height: AppSizes.gapLarge),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.big = false,
  });

  final String label;
  final String value;
  final bool big;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.gap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: big ? 30 : 22,
              fontWeight: big ? FontWeight.w700 : FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
