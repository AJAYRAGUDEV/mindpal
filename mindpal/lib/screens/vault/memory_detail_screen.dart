import 'package:flutter/material.dart';

import '../../l10n/language_scope.dart';
import '../../models/vault_memory.dart';
import '../../services/memory_vault_service.dart';
import '../../theme/app_sizes.dart';
import '../../theme/app_theme.dart';
import '../../utils/date_formats.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/entry_list_scaffold.dart';
import '../../widgets/memory_media.dart';
import '../memory/entry_edit_result.dart';
import 'edit_memory_screen.dart';

/// One memory, full size: the photo, the video, the words.
///
/// This is the screen the vault exists for — the one an elderly user sits
/// with. So: one column, big media, big text, and only three actions, each
/// with a word on it. Edit and Delete pop a result to the vault screen,
/// which commits; Back is the app bar.
class MemoryDetailScreen extends StatelessWidget {
  const MemoryDetailScreen({
    super.key,
    required this.memory,
    required this.service,
  });

  final VaultMemory memory;
  final MemoryVaultService service;

  Future<void> _edit(BuildContext context) async {
    final result = await Navigator.of(context).push<EntryEditResult<MemoryDraft>>(
      MaterialPageRoute(
        builder: (_) => EditMemoryScreen(
          existing: memory,
          loadPhoto: memory.hasPhoto ? () => service.readMedia(memory.photoRef!) : null,
        ),
      ),
    );
    // Whatever the form decided (save / delete / cancel), this screen has
    // nothing more to do with it: pass it straight up to the list.
    if (result != null && context.mounted) Navigator.of(context).pop(result);
  }

  Future<void> _delete(BuildContext context) async {
    final confirmed = await confirmDestructiveAction(
      context,
      title: 'Delete this memory?',
      message: '"${memory.title}" and its photo or video will be removed. '
          'This cannot be undone.',
    );
    if (!confirmed || !context.mounted) return;
    Navigator.of(context).pop(const EntryEditResult<MemoryDraft>.delete());
  }

  @override
  Widget build(BuildContext context) {
    final category = memory.category;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Memory')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSizes.pagePadding),
          children: [
            if (memory.hasPhoto) ...[
              MemoryPhoto(
                load: () => service.readMedia(memory.photoRef!),
                height: 300,
              ),
              const SizedBox(height: AppSizes.gap),
            ],
            if (memory.hasVideo) ...[
              MemoryVideoPlayer(
                createController: () => service.videoController(memory.videoRef!),
              ),
              const SizedBox(height: AppSizes.gap),
            ],

            Row(
              children: [
                Icon(category.icon, size: 24, color: category.color),
                const SizedBox(width: 6),
                Text(
                  category.localisedLabel(LanguageScope.of(context)),
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: category.color,
                  ),
                ),
                if (memory.isDemo) ...[
                  const SizedBox(width: AppSizes.gap),
                  const Text(
                    'Demo',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppSizes.gapSmall),
            Text(memory.title, style: textTheme.headlineSmall),

            if (memory.date != null) ...[
              const SizedBox(height: AppSizes.gapSmall),
              _InfoRow(icon: Icons.calendar_month_rounded, text: formatFullDate(memory.date!)),
            ],
            if (memory.hasPerson) ...[
              const SizedBox(height: AppSizes.gapSmall),
              _InfoRow(icon: Icons.person_rounded, text: memory.personLabel),
            ],

            if (memory.story.trim().isNotEmpty) ...[
              const SizedBox(height: AppSizes.gapLarge),
              Text(
                memory.story,
                style: textTheme.bodyLarge?.copyWith(height: 1.5),
              ),
            ],

            const SizedBox(height: AppSizes.gapLarge),
            FilledButton.icon(
              onPressed: () => _edit(context),
              icon: const Icon(Icons.edit_rounded, size: AppSizes.iconMedium),
              label: const Text('Edit'),
            ),
            const SizedBox(height: AppSizes.gap),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back_rounded, size: AppSizes.iconMedium),
              label: const Text('Back'),
            ),
            const SizedBox(height: AppSizes.gapLarge),
            DeleteEntryButton(label: 'Delete memory', onPressed: () => _delete(context)),
            const SizedBox(height: AppSizes.gapLarge),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 24, color: AppColors.textSecondary),
        const SizedBox(width: AppSizes.gapSmall),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 18, color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }
}
