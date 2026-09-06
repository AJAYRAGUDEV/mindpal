import 'package:flutter/material.dart';

import '../games/memory_match/memory_match_screen.dart';
import '../games/odd_one_out/odd_one_out_screen.dart';
import '../games/personalized/personalized_game_screen.dart';
import '../games/sequence_recall/sequence_recall_screen.dart';
import '../l10n/language_scope.dart';
import '../models/difficulty.dart';
import '../models/game_result.dart';
import '../models/game_type.dart';
import '../services/ai_service.dart';
import '../services/memory_aid_service.dart';
import '../theme/app_sizes.dart';
import '../theme/app_theme.dart';
import '../widgets/difficulty_selector.dart';
import '../widgets/game_card.dart';
import '../widgets/section_title.dart';

/// The MindPal game hub.
///
/// Replaces the Day 1 placeholder. It is a StatefulWidget now because it owns
/// one piece of state: the chosen difficulty, which applies to all games.
///
/// One selector for all three games (rather than one per game) is a
/// simplification on purpose — it is one decision for the user to make instead
/// of three.
class MindPalScreen extends StatefulWidget {
  const MindPalScreen({
    super.key,
    required this.onGameFinished,
    required this.memoryAidService,
    required this.onOpenMemoryAid,
    required this.aiService,
  });

  /// Called with every finished (or abandoned) game so MainShell can file it
  /// in the Activity History. The hub does not own the history itself —
  /// Home needs it too.
  final Future<void> Function(GameResult result) onGameFinished;

  /// The personalised game reads the user's saved People/Places/Notes.
  final MemoryAidService memoryAidService;

  /// Used by the personalised game's empty state, to send the user to the
  /// Memory tab where they can add the data it needs.
  final VoidCallback onOpenMemoryAid;

  /// Provider-agnostic. main.dart decides whether this is the generative
  /// implementation or the offline one.
  final AiService aiService;

  @override
  State<MindPalScreen> createState() => _MindPalScreenState();
}

class _MindPalScreenState extends State<MindPalScreen> {
  Difficulty _difficulty = Difficulty.easy;

  /// Opens a game as a full-screen route and waits for its result.
  ///
  /// This is the first Navigator.push in the project. Tabs and games are
  /// different kinds of navigation:
  ///   * a TAB is a place you switch between freely (bottom bar, IndexedStack),
  ///   * a GAME is a task you enter, finish, and come back from.
  ///
  /// `push` returns a Future that completes when the pushed screen pops, and
  /// the popped value comes back here. That is how the game hands us its score.
  Future<void> _play(GameType gameType) async {
    final result = await Navigator.of(context).push<GameResult>(
      MaterialPageRoute(
        builder: (_) => switch (gameType) {
          GameType.memoryMatch => MemoryMatchScreen(difficulty: _difficulty),
          GameType.sequenceRecall => SequenceRecallScreen(
            difficulty: _difficulty,
          ),
          GameType.personalizedMemory => PersonalizedGameScreen(
            memoryAidService: widget.memoryAidService,
            difficulty: _difficulty,
            onOpenMemoryAid: widget.onOpenMemoryAid,
            aiService: widget.aiService,
            language: LanguageScope.of(context).language,
          ),
          GameType.oddOneOut => OddOneOutScreen(difficulty: _difficulty),
        },
      ),
    );

    // `context` may be gone by the time the game closes, so re-check.
    if (!mounted || result == null) return;

    // Hand the result up to be saved, then confirm to the user.
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

  @override
  Widget build(BuildContext context) {
    final strings = LanguageScope.of(context);

    return ListView(
      padding: const EdgeInsets.all(AppSizes.pagePadding),
      children: [
        Text(
          'Choose an activity for today',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: AppSizes.gapLarge),

        const SectionTitle('Difficulty'),
        const SizedBox(height: AppSizes.gap),
        DifficultySelector(
          selected: _difficulty,
          onChanged: (difficulty) => setState(() => _difficulty = difficulty),
        ),
        const SizedBox(height: AppSizes.gapLarge),

        const SectionTitle('Activities'),
        const SizedBox(height: AppSizes.gap),

        // The personalised game leads, because it is the one made from this
        // user's own life rather than generic shapes.
        GameCard(
          gameType: GameType.personalizedMemory,
          difficulty: _difficulty,
          title: strings.personalizedGame,
          description: strings.personalizedGameDescription,
          playLabel: strings.playPersonalizedGame,
          onPlay: () => _play(GameType.personalizedMemory),
        ),
        const SizedBox(height: AppSizes.gap),
        GameCard(
          gameType: GameType.memoryMatch,
          difficulty: _difficulty,
          onPlay: () => _play(GameType.memoryMatch),
        ),
        const SizedBox(height: AppSizes.gap),
        GameCard(
          gameType: GameType.sequenceRecall,
          difficulty: _difficulty,
          onPlay: () => _play(GameType.sequenceRecall),
        ),
        const SizedBox(height: AppSizes.gap),
        GameCard(
          gameType: GameType.oddOneOut,
          difficulty: _difficulty,
          title: strings.oddOneOut,
          description: strings.oddOneOutDescription,
          playLabel: strings.playOddOneOut,
          onPlay: () => _play(GameType.oddOneOut),
        ),
        const SizedBox(height: AppSizes.gapLarge),
      ],
    );
  }
}
