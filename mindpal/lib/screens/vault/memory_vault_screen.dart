import 'package:flutter/material.dart';

import '../../models/vault_memory.dart';
import '../../services/memory_vault_service.dart';
import '../../theme/app_sizes.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_exception.dart';
import '../../utils/date_formats.dart';
import '../../widgets/memory_media.dart';
import '../memory/entry_edit_result.dart';
import 'edit_memory_screen.dart';
import 'memory_detail_screen.dart';

/// The Memory Vault: saved moments, newest first, each a card to tap.
///
/// Owns the list for as long as it is open. Add, edit and delete all come
/// back here to commit through the service, so there is exactly one place
/// that changes the data — the same shape as PeopleScreen and the others.
class MemoryVaultScreen extends StatefulWidget {
  const MemoryVaultScreen({super.key, required this.service});

  final MemoryVaultService service;

  @override
  State<MemoryVaultScreen> createState() => _MemoryVaultScreenState();
}

class _MemoryVaultScreenState extends State<MemoryVaultScreen> {
  List<VaultMemory> _memories = const [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await widget.service.init();
    final memories = await widget.service.loadAll();
    if (!mounted) return;
    setState(() {
      _memories = memories;
      _isLoading = false;
    });
  }

  Future<void> _add() async {
    final result = await Navigator.of(context).push<EntryEditResult<MemoryDraft>>(
      MaterialPageRoute(builder: (_) => const EditMemoryScreen()),
    );
    if (result?.item == null || !mounted) return;
    await _commit(result!.item!);
  }

  Future<void> _open(VaultMemory memory) async {
    final result = await Navigator.of(context).push<EntryEditResult<MemoryDraft>>(
      MaterialPageRoute(
        builder: (_) => MemoryDetailScreen(memory: memory, service: widget.service),
      ),
    );
    if (result == null || !mounted) return;

    if (result.deleted) {
      await _run(() => widget.service.remove(_memories, memory), 'Memory deleted');
    } else if (result.item != null) {
      await _commit(result.item!);
    }
  }

  Future<void> _addDemo() async {
    await _run(
      () => widget.service.addDemoMemories(_memories),
      'Two sample memories added. Delete them whenever you like.',
    );
  }

  Future<void> _commit(MemoryDraft draft) =>
      _run(() => widget.service.commit(_memories, draft), 'Memory saved');

  /// One path for every change: run it, show the outcome, never leave the
  /// list stale or the user guessing whether the tap worked.
  Future<void> _run(
    Future<List<VaultMemory>> Function() action,
    String successMessage,
  ) async {
    setState(() => _isSaving = true);
    try {
      final updated = await action();
      if (!mounted) return;
      setState(() => _memories = updated);
      _toast(successMessage);
    } on AppException catch (error) {
      if (mounted) _toast(error.message, isError: true);
    } catch (error) {
      debugPrint('Memory vault change failed: ${error.runtimeType}');
      if (mounted) _toast('Sorry, that did not save. Please try again.', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _toast(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message, style: const TextStyle(fontSize: 18)),
          backgroundColor: isError ? AppColors.error : null,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Memory Vault')),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _memories.isEmpty
            ? _EmptyVault(onAdd: _add, onAddDemo: _addDemo, busy: _isSaving)
            : ListView(
                padding: const EdgeInsets.all(AppSizes.pagePadding),
                children: [
                  FilledButton.icon(
                    onPressed: _isSaving ? null : _add,
                    icon: const Icon(Icons.add_rounded, size: AppSizes.iconMedium),
                    label: const Text('Add Memory'),
                  ),
                  const SizedBox(height: AppSizes.gapLarge),
                  for (final memory in _memories) ...[
                    _MemoryCard(
                      memory: memory,
                      service: widget.service,
                      onTap: () => _open(memory),
                    ),
                    const SizedBox(height: AppSizes.gap),
                  ],
                  const SizedBox(height: AppSizes.gapLarge),
                ],
              ),
      ),
    );
  }
}

/// A calm, useful empty state. Never "coming soon" — the feature is here,
/// the vault is simply empty.
class _EmptyVault extends StatelessWidget {
  const _EmptyVault({
    required this.onAdd,
    required this.onAddDemo,
    required this.busy,
  });

  final VoidCallback onAdd;
  final VoidCallback onAddDemo;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSizes.pagePadding),
      children: [
        const SizedBox(height: AppSizes.gapLarge),
        Container(
          width: 96,
          height: 96,
          decoration: const BoxDecoration(
            color: AppColors.primarySoft,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.photo_album_rounded,
            size: 52,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: AppSizes.gapLarge),
        Text(
          'No memories added yet.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: AppSizes.gapSmall),
        Text(
          'Keep the moments that matter: a birthday, a trip, a face you '
          'love. Add a photo or a short video and a few words about it.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: AppSizes.gapLarge),
        FilledButton.icon(
          onPressed: busy ? null : onAdd,
          icon: const Icon(Icons.add_rounded, size: AppSizes.iconMedium),
          label: const Text('Add Your First Memory'),
        ),
        const SizedBox(height: AppSizes.gap),
        OutlinedButton.icon(
          onPressed: busy ? null : onAddDemo,
          icon: const Icon(Icons.auto_stories_rounded, size: AppSizes.iconMedium),
          label: const Text('Add sample memories'),
        ),
        const SizedBox(height: AppSizes.gapSmall),
        const Text(
          'Samples are marked "Demo" and can be deleted at any time.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _MemoryCard extends StatelessWidget {
  const _MemoryCard({
    required this.memory,
    required this.service,
    required this.onTap,
  });

  final VaultMemory memory;
  final MemoryVaultService service;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final category = memory.category;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppSizes.radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSizes.radius),
            border: Border.all(color: AppColors.border, width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (memory.hasPhoto)
                MemoryPhoto(
                  load: () => service.readMedia(memory.photoRef!),
                  height: 190,
                  borderRadius: 0,
                )
              else if (memory.hasVideo)
                const _VideoPoster()
              else
                _CategoryBanner(category: category),

              Padding(
                padding: const EdgeInsets.all(AppSizes.cardPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _Tag(
                          icon: category.icon,
                          label: category.label,
                          color: category.color,
                        ),
                        if (memory.hasVideo && memory.hasPhoto) ...[
                          const SizedBox(width: AppSizes.gapSmall),
                          const _Tag(
                            icon: Icons.videocam_rounded,
                            label: 'Video',
                            color: AppColors.textSecondary,
                          ),
                        ],
                        if (memory.isDemo) ...[
                          const SizedBox(width: AppSizes.gapSmall),
                          const _Tag(
                            icon: Icons.science_outlined,
                            label: 'Demo',
                            color: AppColors.textSecondary,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppSizes.gapSmall),
                    Text(
                      memory.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    if (memory.date != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        formatFullDate(memory.date!),
                        style: const TextStyle(
                          fontSize: 16,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                    if (memory.story.trim().isNotEmpty) ...[
                      const SizedBox(height: AppSizes.gapSmall),
                      Text(
                        memory.story,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                    if (memory.hasPerson) ...[
                      const SizedBox(height: AppSizes.gapSmall),
                      Row(
                        children: [
                          const Icon(
                            Icons.person_rounded,
                            size: 22,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              memory.personLabel,
                              style: const TextStyle(
                                fontSize: 17,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A video-only memory has no still to show, so the card carries a clear
/// "this is a video" poster instead of a blank.
class _VideoPoster extends StatelessWidget {
  const _VideoPoster();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 150,
      color: const Color(0xFF1B2B28),
      alignment: Alignment.center,
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.play_circle_fill_rounded, size: 64, color: Colors.white),
          SizedBox(height: 4),
          Text(
            'Video',
            style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _CategoryBanner extends StatelessWidget {
  const _CategoryBanner({required this.category});

  final MemoryCategory category;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      color: category.color.withValues(alpha: 0.14),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.cardPadding),
      child: Icon(category.icon, size: 40, color: category.color),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}
