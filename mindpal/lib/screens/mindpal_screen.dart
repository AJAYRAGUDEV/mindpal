import 'package:flutter/material.dart';

import '../content/cultural_pack.dart';
import '../content/pack_library.dart';
import '../games/cultural/cultural_adapters.dart';
import '../games/family_match/family_match_setup_screen.dart';
import '../games/memory_match/memory_match_config.dart';
import '../games/memory_match/memory_match_screen.dart';
import '../games/odd_one_out/odd_one_out_screen.dart';
import '../games/personalized/personalized_game_screen.dart';
import '../games/sequence_recall/sequence_recall_screen.dart';
import '../games/story_sequence/story_sequence_screen.dart';
import '../games/widgets/game_shell.dart';
import '../l10n/language_scope.dart';
import '../models/difficulty.dart';
import '../models/game_result.dart';
import '../models/game_settings.dart';
import '../models/game_type.dart';
import '../services/adaptive_difficulty.dart';
import '../services/ai_service.dart';
import '../services/memory_aid_service.dart';
import '../services/memory_vault_service.dart';
import '../services/voice/voice_controller.dart';
import '../theme/app_sizes.dart';
import '../theme/app_theme.dart';
import '../widgets/difficulty_selector.dart';
import '../widgets/game_card.dart';
import '../widgets/section_title.dart';
import 'games/game_settings_sheet.dart';
import 'games/player_progress_screen.dart';

/// The MindPal game hub — the main thing the app does.
///
/// Games are grouped by where their content comes from, because that is the
/// distinction a player actually notices: pictures from their region, pictures
/// from their own life, and the app's own. Six cards in one flat list would be
/// six things to read; three short sections are three.
class MindPalScreen extends StatefulWidget {
  const MindPalScreen({
    super.key,
    required this.onGameFinished,
    required this.memoryAidService,
    required this.memoryVaultService,
    required this.onOpenMemoryAid,
    required this.aiService,
    required this.gameHistory,
    required this.settings,
    required this.onSettingsChanged,
    this.voice,
  });

  /// Called with every finished (or abandoned) game so MainShell can file it
  /// in the Activity History. The hub does not own the history itself —
  /// Home needs it too.
  final Future<void> Function(GameResult result) onGameFinished;

  /// The personalised game reads the user's saved People/Places/Notes.
  final MemoryAidService memoryAidService;

  /// The family board reads photos out of the Memory Vault.
  final MemoryVaultService memoryVaultService;

  /// Used by the personalised game's empty state, to send the user to the
  /// Memory tab where they can add the data it needs.
  final VoidCallback onOpenMemoryAid;

  /// Provider-agnostic. main.dart decides whether this is the generative
  /// implementation or the offline one.
  final AiService aiService;

  /// Read-only. Used for "Continue playing" and for difficulty suggestions.
  final List<GameResult> gameHistory;

  final GameSettings settings;
  final ValueChanged<GameSettings> onSettingsChanged;

  final VoiceController? voice;

  @override
  State<MindPalScreen> createState() => _MindPalScreenState();
}

class _MindPalScreenState extends State<MindPalScreen> {
  static const AdaptiveDifficulty _adaptive = AdaptiveDifficulty();

  Difficulty get _difficulty => widget.settings.difficulty;

  /// The chosen pack. `packFor` falls back to the starter pack, both on a first
  /// run and when a saved id names a pack this build no longer ships.
  CulturalPack get _pack => packFor(widget.settings.packId);

  void _setDifficulty(Difficulty difficulty) =>
      widget.onSettingsChanged(widget.settings.copyWith(difficulty: difficulty));

  void _setPack(CulturalPack pack) =>
      widget.onSettingsChanged(widget.settings.copyWith(packId: pack.id));

  /// The Memory Match board for this pack: the difficulty's size, or the whole
  /// pack when it has fewer pictures than that.
  ///
  /// The starter pack is comfortably big enough. A smaller pack contributed
  /// later would otherwise deal a short board, which the game asserts against in
  /// debug and would simply get wrong in a release build.
  MemoryMatchConfig get _matchConfig {
    final wanted = MemoryMatchConfig.forDifficulty(_difficulty);
    if (_pack.canFillMatchBoard(wanted.pairCount)) return wanted;
    return MemoryMatchConfig.forPairs(_difficulty, _pack.items.length);
  }

  /// The notes every cultural game shows: what the pack is, and whether anyone
  /// has checked it.
  List<GameNote> get _packNotes => [
    GameNote(_pack.title, icon: Icons.public_rounded),
    if (!_pack.review.isReviewed)
      GameNote(
        'The facts in this pack have not been checked by a reviewer yet.',
        icon: _pack.review.icon,
      ),
  ];

  /// Added only when a board had to be made smaller than the level asked for.
  List<GameNote> _sizeNotes(int dealt, int asked) => [
    if (dealt < asked)
      GameNote(
        'This pack has $dealt pictures, so the board is that size rather than '
        '$asked pairs.',
      ),
  ];

  /// Opens a game as a full-screen route and files whatever it returns.
  ///
  /// `push` returns a Future that completes when the pushed screen pops, and
  /// the popped value comes back here. That is how a game hands us its score.
  Future<void> _play(GameType gameType) async {
    final result = await Navigator.of(context).push<GameResult>(
      MaterialPageRoute(builder: (_) => _screenFor(gameType)),
    );

    // `context` may be gone by the time the game closes, so re-check.
    if (!mounted || result == null) return;

    await widget.onGameFinished(result);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.completed
              ? 'Finished ${result.gameType.label} — score ${result.score}'
              : 'Stopped ${result.gameType.label} — score ${result.score}',
        ),
        backgroundColor: AppColors.primaryDark,
      ),
    );
  }

  Widget _screenFor(GameType gameType) => switch (gameType) {
    GameType.memoryMatch => MemoryMatchScreen(
      difficulty: _difficulty,
      config: _matchConfig,
      // Cultural pictures rather than the app's generic ones. The rules,
      // the scoring and the layout are untouched.
      pool: matchTilesFor(_pack),
      packId: _pack.id,
      title: 'Cultural Memory Match',
      notes: [
        ..._packNotes,
        ..._sizeNotes(
          _matchConfig.pairCount,
          MemoryMatchConfig.forDifficulty(_difficulty).pairCount,
        ),
      ],
      factsAreUnchecked: !_pack.review.isReviewed,
      settings: widget.settings,
      voice: widget.voice,
    ),
    GameType.oddOneOut => OddOneOutScreen(
      difficulty: _difficulty,
      deck: deckFor(_pack),
      title: 'Cultural Odd-One-Out',
      notes: _packNotes,
      settings: widget.settings,
      voice: widget.voice,
    ),
    GameType.folkStorySequence => StorySequenceScreen(
      difficulty: _difficulty,
      pack: _pack,
      notes: _packNotes,
      settings: widget.settings,
      voice: widget.voice,
    ),
    GameType.familyPhotoMatch => FamilyMatchSetupScreen(
      vault: widget.memoryVaultService,
      difficulty: _difficulty,
      settings: widget.settings,
      voice: widget.voice,
    ),
    GameType.sequenceRecall => SequenceRecallScreen(difficulty: _difficulty),
    GameType.personalizedMemory => PersonalizedGameScreen(
      memoryAidService: widget.memoryAidService,
      difficulty: _difficulty,
      onOpenMemoryAid: widget.onOpenMemoryAid,
      aiService: widget.aiService,
      language: LanguageScope.of(context).language,
    ),
  };

  /// The last game played, for the Continue playing card. Null on a first run.
  GameResult? get _lastPlayed {
    if (widget.gameHistory.isEmpty) return null;
    final sorted = [...widget.gameHistory]
      ..sort((a, b) => b.playedAt.compareTo(a.playedAt));
    return sorted.first;
  }

  /// A level MindPal offers for the game most recently played, or null.
  DifficultySuggestion? get _suggestion {
    if (!widget.settings.acceptDifficultySuggestions) return null;
    final last = _lastPlayed;
    if (last == null) return null;
    return _adaptive.suggest(
      history: widget.gameHistory,
      gameType: last.gameType,
      current: _difficulty,
    );
  }

  Future<void> _openSettings() async {
    final next = await showGameSettingsSheet(
      context,
      settings: widget.settings,
      // No point offering spoken instructions on a device with no voice.
      canSpeak: widget.voice?.speakerAvailable ?? false,
    );
    if (next != null) widget.onSettingsChanged(next);
  }

  void _openProgress() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlayerProgressScreen(history: widget.gameHistory),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = LanguageScope.of(context);
    final last = _lastPlayed;
    final suggestion = _suggestion;

    return ListView(
      padding: const EdgeInsets.all(AppSizes.pagePadding),
      children: [
        Text(
          'Play, Remember, Connect',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 4),
        const Text(
          'Familiar stories, traditions and memories, as simple games.',
          style: TextStyle(fontSize: 18, color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSizes.gapLarge),

        if (last != null) ...[
          _ContinueCard(
            result: last,
            onPlay: () => _play(last.gameType),
          ),
          const SizedBox(height: AppSizes.gapLarge),
        ],

        const SectionTitle('Cultural pack'),
        const SizedBox(height: AppSizes.gap),
        _PackSelector(
          packs: kCulturalPacks,
          selected: _pack,
          onSelect: _setPack,
        ),
        const SizedBox(height: AppSizes.gapLarge),

        const SectionTitle('Difficulty'),
        const SizedBox(height: AppSizes.gap),
        DifficultySelector(
          selected: _difficulty,
          onChanged: _setDifficulty,
        ),
        if (suggestion != null) ...[
          const SizedBox(height: AppSizes.gap),
          _SuggestionCard(
            suggestion: suggestion,
            onAccept: () => _setDifficulty(suggestion.to),
            onDismiss: () => widget.onSettingsChanged(
              widget.settings.copyWith(acceptDifficultySuggestions: false),
            ),
          ),
        ],
        const SizedBox(height: AppSizes.gapLarge),

        const SectionTitle('Games from your region'),
        const SizedBox(height: AppSizes.gap),
        GameCard(
          gameType: GameType.memoryMatch,
          difficulty: _difficulty,
          title: 'Cultural Memory Match',
          description:
              'Match pairs of instruments, foods and handmade things from '
              '${_pack.region}.',
          playLabel: 'Play Cultural Memory Match',
          onPlay: () => _play(GameType.memoryMatch),
        ),
        const SizedBox(height: AppSizes.gap),
        GameCard(
          gameType: GameType.folkStorySequence,
          difficulty: _difficulty,
          title: 'Story Order',
          description:
              'Read or hear a short story, then put its scenes in the order '
              'they happened.',
          playLabel: 'Play Story Order',
          // A pack with no stories cannot offer this game, and the card says so
          // rather than opening an empty screen.
          enabled: _pack.hasStories,
          comingSoonLabel: 'No story in this pack yet',
          onPlay: () => _play(GameType.folkStorySequence),
        ),
        const SizedBox(height: AppSizes.gap),
        GameCard(
          gameType: GameType.oddOneOut,
          difficulty: _difficulty,
          title: 'Cultural Odd-One-Out',
          description:
              'Three of these belong together and one does not. Which is it?',
          playLabel: 'Play Cultural Odd-One-Out',
          // Needs two kinds of thing to compare. A pack with only one could not
          // pose a question that has an answer.
          enabled: deckFor(_pack).isPlayable,
          comingSoonLabel: 'This pack needs more kinds of picture',
          onPlay: () => _play(GameType.oddOneOut),
        ),

        const SizedBox(height: AppSizes.gapLarge),
        const SectionTitle('Games from your own life'),
        const SizedBox(height: AppSizes.gap),
        GameCard(
          gameType: GameType.familyPhotoMatch,
          difficulty: _difficulty,
          title: 'Family Photo Match',
          description:
              'Match pairs made from photos in your Memory Vault. They stay '
              'on this phone.',
          playLabel: 'Play Family Photo Match',
          onPlay: () => _play(GameType.familyPhotoMatch),
        ),
        const SizedBox(height: AppSizes.gap),
        GameCard(
          gameType: GameType.personalizedMemory,
          difficulty: _difficulty,
          title: strings.personalizedGame,
          description: strings.personalizedGameDescription,
          playLabel: strings.playPersonalizedGame,
          onPlay: () => _play(GameType.personalizedMemory),
        ),

        const SizedBox(height: AppSizes.gapLarge),
        const SectionTitle('Other games'),
        const SizedBox(height: AppSizes.gap),
        GameCard(
          gameType: GameType.sequenceRecall,
          difficulty: _difficulty,
          onPlay: () => _play(GameType.sequenceRecall),
        ),

        const SizedBox(height: AppSizes.gapLarge),
        OutlinedButton.icon(
          onPressed: _openProgress,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, AppSizes.buttonHeight),
          ),
          icon: const Icon(Icons.timeline_rounded, size: 26),
          label: const Text('Your progress'),
        ),
        const SizedBox(height: AppSizes.gap),
        OutlinedButton.icon(
          onPressed: _openSettings,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, AppSizes.buttonHeight),
          ),
          icon: const Icon(Icons.tune_rounded, size: 26),
          label: const Text('Sound, movement and reading aloud'),
        ),
        const SizedBox(height: AppSizes.gapLarge),
      ],
    );
  }
}

/// Picks up where the player left off.
class _ContinueCard extends StatelessWidget {
  const _ContinueCard({required this.result, required this.onPlay});

  final GameResult result;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final pack = packById(result.packId);

    return Container(
      padding: const EdgeInsets.all(AppSizes.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(AppSizes.radius),
        border: Border.all(color: AppColors.primary, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Continue playing',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            result.gameType.label,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (pack != null)
            Text(
              pack.title,
              style: const TextStyle(
                fontSize: 17,
                color: AppColors.textSecondary,
              ),
            ),
          const SizedBox(height: AppSizes.gap),
          FilledButton.icon(
            onPressed: onPlay,
            icon: const Icon(Icons.play_arrow_rounded, size: 28),
            label: Text('Play ${result.gameType.label} again'),
          ),
        ],
      ),
    );
  }
}

/// The cultural pack chooser.
///
/// It lists only packs with playable content, and prints what is missing in
/// words. A row of greyed-out state names would claim content that does not
/// exist — the one thing this selector must not do.
class _PackSelector extends StatelessWidget {
  const _PackSelector({
    required this.packs,
    required this.selected,
    required this.onSelect,
  });

  final List<CulturalPack> packs;
  final CulturalPack selected;
  final ValueChanged<CulturalPack> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final pack in packs) ...[
          _PackRow(
            pack: pack,
            isSelected: pack.id == selected.id,
            onTap: () => onSelect(pack),
          ),
          const SizedBox(height: AppSizes.gapSmall),
        ],
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.info_outline_rounded,
              size: 20,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: AppSizes.gapSmall),
            const Expanded(
              child: Text(
                kPackCoverageNote,
                style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PackRow extends StatelessWidget {
  const _PackRow({
    required this.pack,
    required this.isSelected,
    required this.onTap,
  });

  final CulturalPack pack;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: '${pack.title}. ${pack.region}. '
          '${isSelected ? "Chosen" : "Not chosen"}',
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSizes.radius),
          child: Container(
            padding: const EdgeInsets.all(AppSizes.cardPadding),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppSizes.radius),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.border,
                width: isSelected ? 3 : 1.5,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isSelected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 30,
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.textSecondary,
                ),
                const SizedBox(width: AppSizes.gap),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pack.title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        pack.region,
                        style: const TextStyle(
                          fontSize: 16,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            pack.review.icon,
                            size: 18,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              pack.review.label,
                              style: const TextStyle(
                                fontSize: 15,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
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

/// An offer of a different level — never a change made on the player's behalf.
class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({
    required this.suggestion,
    required this.onAccept,
    required this.onDismiss,
  });

  final DifficultySuggestion suggestion;
  final VoidCallback onAccept;

  /// Turns suggestions off altogether. Offered right next to the suggestion,
  /// because someone who does not want to be nudged should not have to find a
  /// settings screen to say so.
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radius),
        border: Border.all(color: AppColors.primary, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                suggestion.isHarder
                    ? Icons.trending_up_rounded
                    : Icons.favorite_rounded,
                size: 26,
                color: AppColors.primary,
              ),
              const SizedBox(width: AppSizes.gapSmall),
              Expanded(
                child: Text(
                  suggestion.reason,
                  style: const TextStyle(
                    fontSize: 18,
                    height: 1.35,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.gap),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: onAccept,
                  child: Text('Try ${suggestion.to.label}'),
                ),
              ),
              const SizedBox(width: AppSizes.gapSmall),
              Expanded(
                child: OutlinedButton(
                  onPressed: onDismiss,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, AppSizes.minTouchTarget),
                  ),
                  child: const Text('No thank you'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
