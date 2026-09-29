import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../models/difficulty.dart';
import '../../models/game_result.dart';
import '../../models/game_settings.dart';
import '../../models/game_type.dart';
import '../../models/vault_memory.dart';
import '../../services/memory_vault_service.dart';
import '../../services/voice/voice_controller.dart';
import '../../theme/app_sizes.dart';
import '../../theme/app_theme.dart';
import '../memory_match/memory_match_config.dart';
import '../memory_match/memory_match_screen.dart';
import '../memory_match/memory_symbol.dart';

/// Family Memory Play: choose photos from the Memory Vault, then match them.
///
/// **What this screen does not do, and will not.** No face recognition, no
/// grouping "people" automatically, and nothing here leaves the device. The
/// photos are read from the app's own media store, decoded into memory, shown,
/// and dropped when the game closes. Nothing is uploaded, nothing is sent to
/// Gemini or any other service, and no photo or caption is written into a saved
/// game result — a result records the pack id, the score and the counts, which
/// is why the caregiver report can never leak a family picture.
///
/// **How a deleted photo is handled.** The selection is not saved anywhere. Each
/// game starts by reading the vault again, so a photo deleted yesterday is
/// simply not offered today — there is no stored list of photo ids that could
/// go stale. If a file disappears between this screen and the board (deleted
/// from another tab, or lost by the platform), the card falls back to showing
/// the memory's title on a plain tile and the game carries on. Both paths are
/// covered by tests.
class FamilyMatchSetupScreen extends StatefulWidget {
  const FamilyMatchSetupScreen({
    super.key,
    required this.vault,
    required this.difficulty,
    this.settings = GameSettings.defaults,
    this.voice,
  });

  final MemoryVaultService vault;
  final Difficulty difficulty;
  final GameSettings settings;
  final VoiceController? voice;

  /// Fewer pairs than this is not a memory game, it is a reveal.
  static const int minimumPhotos = 3;

  @override
  State<FamilyMatchSetupScreen> createState() => _FamilyMatchSetupScreenState();
}

class _FamilyMatchSetupScreenState extends State<FamilyMatchSetupScreen> {
  /// Vault entries that actually have a photo.
  List<VaultMemory> _withPhotos = const [];

  /// Decoded bytes by media ref. Read once here so the board never waits on
  /// the disk mid-game.
  final Map<String, Uint8List> _images = {};

  /// Ids the player has ticked.
  final Set<int> _chosen = {};

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final all = await widget.vault.loadAll();
      final withPhotos = all.where((memory) => memory.hasPhoto).toList();

      // Read every photo now. A memory whose file has gone is dropped here
      // rather than becoming a blank card later.
      final images = <String, Uint8List>{};
      final usable = <VaultMemory>[];
      for (final memory in withPhotos) {
        final bytes = await widget.vault.readMedia(memory.photoRef!);
        if (bytes == null) continue;
        images[memory.photoRef!] = bytes;
        usable.add(memory);
      }

      if (!mounted) return;
      setState(() {
        _withPhotos = usable;
        _images
          ..clear()
          ..addAll(images);
        // Pre-tick up to what this difficulty wants, so a player who just
        // wants to play can press Start immediately.
        final wanted = MemoryMatchConfig.forDifficulty(
          widget.difficulty,
        ).pairCount;
        _chosen
          ..clear()
          ..addAll(usable.take(wanted).map((memory) => memory.id));
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _withPhotos = const [];
        _loading = false;
      });
    }
  }

  /// How many pairs the board will have: what was chosen, but never more than
  /// this difficulty asks for.
  int get _pairs {
    final wanted = MemoryMatchConfig.forDifficulty(
      widget.difficulty,
    ).pairCount;
    return _chosen.length <= wanted ? _chosen.length : wanted;
  }

  bool get _canStart => _chosen.length >= FamilyMatchSetupScreen.minimumPhotos;

  Future<void> _start() async {
    final chosen = [
      for (final memory in _withPhotos)
        if (_chosen.contains(memory.id)) memory,
    ].take(_pairs).toList();

    final pool = [
      for (final memory in chosen)
        MemorySymbol(
          _labelFor(memory),
          // Shown only if the photo cannot be decoded on the board.
          Icons.photo_rounded,
          AppColors.memory,
          // The vault id, never the title: two memories can easily share a
          // title, and matching on the title would let two different photos
          // count as a pair.
          matchKey: 'vault_${memory.id}',
          imageRef: memory.photoRef,
          description: 'One of your own photos.',
        ),
    ];

    final result = await Navigator.of(context).push<GameResult>(
      MaterialPageRoute(
        builder: (_) => MemoryMatchScreen(
          difficulty: widget.difficulty,
          config: MemoryMatchConfig.forPairs(widget.difficulty, _pairs),
          pool: pool,
          gameType: GameType.familyPhotoMatch,
          title: 'Family Photo Match',
          images: _images,
          settings: widget.settings,
          voice: widget.voice,
        ),
      ),
    );

    // Hand the result straight up to the hub, and close this screen with it —
    // the player finished a game, not a photo chooser.
    if (mounted) Navigator.of(context).pop<GameResult>(result);
  }

  /// The caption on a card. The memory's own title when it has one.
  String _labelFor(VaultMemory memory) {
    final title = memory.title.trim();
    if (title.isNotEmpty) return title;
    return memory.hasPerson ? memory.personName.trim() : 'A photo';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Family Photo Match'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back to games',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _withPhotos.length < FamilyMatchSetupScreen.minimumPhotos
            ? _NotEnoughPhotos(found: _withPhotos.length)
            : _Chooser(
                memories: _withPhotos,
                images: _images,
                chosen: _chosen,
                pairs: _pairs,
                canStart: _canStart,
                labelFor: _labelFor,
                onToggle: (memory) => setState(() {
                  if (!_chosen.remove(memory.id)) _chosen.add(memory.id);
                }),
                onStart: _start,
              ),
      ),
    );
  }
}

/// The honest empty state: what is needed, and where to get it.
class _NotEnoughPhotos extends StatelessWidget {
  const _NotEnoughPhotos({required this.found});

  final int found;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSizes.pagePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSizes.gapLarge),
          const Icon(
            Icons.photo_library_outlined,
            size: 88,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: AppSizes.gap),
          Text(
            'This game needs a few photos first',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: AppSizes.gap),
          Text(
            found == 0
                ? 'There are no photos in your Memory Vault yet. Add at least '
                      '${FamilyMatchSetupScreen.minimumPhotos} memories with a '
                      'photo, and this game will be ready.'
                : 'There '
                      '${found == 1 ? "is 1 photo" : "are $found photos"} in '
                      'your Memory Vault. This game needs at least '
                      '${FamilyMatchSetupScreen.minimumPhotos}.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              height: 1.4,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSizes.gap),
          const Text(
            'Open My Memories, add a memory, and choose a photo for it.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSizes.gapLarge),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_rounded, size: 26),
            label: const Text('Back to games'),
          ),
        ],
      ),
    );
  }
}

class _Chooser extends StatelessWidget {
  const _Chooser({
    required this.memories,
    required this.images,
    required this.chosen,
    required this.pairs,
    required this.canStart,
    required this.labelFor,
    required this.onToggle,
    required this.onStart,
  });

  final List<VaultMemory> memories;
  final Map<String, Uint8List> images;
  final Set<int> chosen;
  final int pairs;
  final bool canStart;
  final String Function(VaultMemory memory) labelFor;
  final ValueChanged<VaultMemory> onToggle;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSizes.pagePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Choose the photos you would like to play with.',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Your photos stay on this phone. They are not sent anywhere.',
                style: TextStyle(fontSize: 17, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.pagePadding,
            ),
            itemCount: memories.length,
            separatorBuilder: (_, _) =>
                const SizedBox(height: AppSizes.gapSmall),
            itemBuilder: (context, index) {
              final memory = memories[index];
              final isChosen = chosen.contains(memory.id);
              final bytes = images[memory.photoRef];

              return _PhotoRow(
                label: labelFor(memory),
                bytes: bytes,
                chosen: isChosen,
                onTap: () => onToggle(memory),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSizes.pagePadding),
          child: Column(
            children: [
              Text(
                canStart
                    ? '${chosen.length} chosen — $pairs pairs to find'
                    : 'Choose at least '
                          '${FamilyMatchSetupScreen.minimumPhotos} photos',
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSizes.gapSmall),
              FilledButton.icon(
                onPressed: canStart ? onStart : null,
                icon: const Icon(Icons.play_arrow_rounded, size: 28),
                label: const Text('Start playing'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PhotoRow extends StatelessWidget {
  const _PhotoRow({
    required this.label,
    required this.bytes,
    required this.chosen,
    required this.onTap,
  });

  final String label;
  final Uint8List? bytes;
  final bool chosen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final photo = bytes;

    return Semantics(
      button: true,
      // "Chosen" is stated in words, not signalled by a tint, so it does not
      // depend on seeing a colour difference.
      label: '$label. ${chosen ? "Chosen" : "Not chosen"}',
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSizes.radius),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppSizes.radius),
              border: Border.all(
                color: chosen ? AppColors.primary : AppColors.border,
                width: chosen ? 3 : 1.5,
              ),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 78,
                    height: 78,
                    child: photo == null
                        ? const ColoredBox(
                            color: AppColors.background,
                            child: Icon(
                              Icons.broken_image_outlined,
                              size: 34,
                              color: AppColors.textSecondary,
                            ),
                          )
                        : Image.memory(
                            photo,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const ColoredBox(
                              color: AppColors.background,
                              child: Icon(
                                Icons.broken_image_outlined,
                                size: 34,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: AppSizes.gap),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Icon(
                  chosen
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 34,
                  color: chosen ? AppColors.primary : AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
