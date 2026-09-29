import 'package:flutter/material.dart';

import '../../content/cultural_pack.dart';
import '../../l10n/language_scope.dart';
import '../../models/difficulty.dart';
import '../../models/game_result.dart';
import '../../models/game_settings.dart';
import '../../services/voice/voice_controller.dart';
import '../../theme/app_sizes.dart';
import '../../theme/app_theme.dart';
import '../../widgets/game_message_banner.dart';
import '../../widgets/game_result_panel.dart';
import '../widgets/game_feedback.dart';
import '../widgets/game_shell.dart';
import 'story_sequence_game.dart';

/// Folk Story Sequence: hear or read a short story, then put its scenes back
/// in order.
///
/// Two phases, and the first one is not optional. A player is shown the story
/// before being asked to order it, and can hear it read aloud and go back to
/// re-read it at any point — including in the middle of ordering. Asking
/// someone with memory difficulty to hold five scenes from a single reading,
/// with no way back to the text, would be a test rather than a game.
class StorySequenceScreen extends StatefulWidget {
  const StorySequenceScreen({
    super.key,
    required this.difficulty,
    required this.pack,
    this.settings = GameSettings.defaults,
    this.voice,
    this.notes = const [],
  });

  final Difficulty difficulty;
  final CulturalPack pack;
  final GameSettings settings;
  final VoiceController? voice;
  final List<GameNote> notes;

  @override
  State<StorySequenceScreen> createState() => _StorySequenceScreenState();
}

class _StorySequenceScreenState extends State<StorySequenceScreen> {
  late StorySequenceGame _game;

  /// True while the story is being read, before the ordering starts.
  bool _reading = true;

  bool _hintShown = false;
  bool _showingResult = false;

  String _message = '';
  MessageTone _tone = MessageTone.neutral;

  @override
  void initState() {
    super.initState();
    _newGame();
  }

  void _newGame() {
    setState(() {
      _game = StorySequenceGame(
        config: StorySequenceConfig.forDifficulty(widget.difficulty),
        pack: widget.pack,
      );
      _reading = true;
      _hintShown = false;
      _showingResult = false;
      _message = 'Tap the scene you think happened first.';
      _tone = MessageTone.neutral;
    });
  }

  /// Starts the ordering again with the same story, keeping the mistake count.
  /// Wiping the count would make "Start again" a way to launder a score, and
  /// the count is the honest record of the session.
  void _startOrderAgain() {
    setState(() {
      _game.restartOrder();
      _message = 'Tap the scene you think happened first.';
      _tone = MessageTone.neutral;
      _showingResult = false;
    });
  }

  void _readStoryAloud() {
    final voice = widget.voice;
    if (voice == null || !voice.speakerAvailable) return;
    voice.speak(
      '${_game.story.title}. ${_game.story.text}',
      LanguageScope.of(context).language,
    );
  }

  void _tap(StoryScene scene) {
    final feedback = GameFeedback(widget.settings);
    final outcome = _game.tap(scene);
    switch (outcome) {
      case ScenePlacement.ignored:
        return;
      case ScenePlacement.placed:
        feedback.good();
        setState(() {
          _message = 'Yes. And then what happened?';
          _tone = MessageTone.positive;
        });
      case ScenePlacement.completed:
        feedback.finished();
        setState(() {
          _message = 'That is the whole story, in order.';
          _tone = MessageTone.positive;
        });
      case ScenePlacement.wrong:
        feedback.notYet();
        setState(() {
          // Never "wrong". It says what to think about instead, and the scene
          // stays where it was rather than being moved somewhere the player
          // then has to undo.
          _message = 'Something else comes before that one. Have another look.';
          _tone = MessageTone.negative;
        });
    }
  }

  void _showHint() {
    setState(() {
      _hintShown = true;
      _game.useHint();
    });
  }

  void _leaveWithResult() =>
      Navigator.of(context).pop<GameResult>(_game.toResult());

  @override
  Widget build(BuildContext context) {
    final voice = widget.voice;
    final canListen = voice != null && voice.speakerAvailable;

    return GameShell(
      title: 'Story Order',
      instructions: _reading
          ? 'Read the story, or have it read to you. When you are ready, put '
                'the pictures in the order they happened.'
          : 'Tap the scene that happened first, then the next one, and so on. '
                'There is no time limit.',
      notes: [
        ...widget.notes,
        if (_game.storyIsShorterThanAsked)
          GameNote(
            'This pack has no ${_game.config.preferredScenes}-scene story yet, '
            'so this one has ${_game.sceneCount}.',
          ),
      ],
      settings: widget.settings,
      voice: widget.voice,
      onExit: _leaveWithResult,
      onRestart: _newGame,
      child: _showingResult
          ? _ResultView(
              game: _game,
              onPlayAgain: _newGame,
              onBack: _leaveWithResult,
            )
          : _reading
          ? _StoryView(
              story: _game.story,
              onListen: canListen ? _readStoryAloud : null,
              onReady: () => setState(() => _reading = false),
            )
          : _OrderView(
              game: _game,
              message: _message,
              tone: _tone,
              hintShown: _hintShown,
              reducedMotion: widget.settings.reducedMotion,
              onHint: _showHint,
              onTap: _tap,
              onReadAgain: () => setState(() => _reading = true),
              onStartOver: _startOrderAgain,
              onSeeResult: () => setState(() => _showingResult = true),
            ),
    );
  }
}

/// Phase one: the story itself.
class _StoryView extends StatelessWidget {
  const _StoryView({
    required this.story,
    required this.onListen,
    required this.onReady,
  });

  final CulturalStory story;

  /// Null when the device has no voice installed. No dead button then.
  final VoidCallback? onListen;
  final VoidCallback onReady;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  story.title,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: AppSizes.gapSmall),
                _OriginNote(story: story),
                const SizedBox(height: AppSizes.gap),
                Text(
                  story.text,
                  style: const TextStyle(
                    fontSize: 21,
                    height: 1.5,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSizes.gap),
                if (onListen != null)
                  OutlinedButton.icon(
                    onPressed: onListen,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, AppSizes.minTouchTarget),
                    ),
                    icon: const Icon(Icons.volume_up_rounded, size: 26),
                    label: const Text('Read the story to me'),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSizes.gap),
        FilledButton.icon(
          onPressed: onReady,
          icon: const Icon(Icons.play_arrow_rounded, size: 28),
          label: const Text('I am ready'),
        ),
      ],
    );
  }
}

/// Says plainly whether this is a traditional tale or was written for MindPal.
///
/// Presenting an invented story as folklore would be a lie about somebody's
/// culture, and the kind that is very hard to walk back once it is in a demo.
class _OriginNote extends StatelessWidget {
  const _OriginNote({required this.story});

  final CulturalStory story;

  @override
  Widget build(BuildContext context) {
    final text =
        story.attribution ??
        (story.origin == ContentOrigin.traditional
            ? 'A traditional story.'
            : 'Written for MindPal.');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          story.origin == ContentOrigin.traditional
              ? Icons.auto_stories_rounded
              : Icons.edit_note_rounded,
          size: 22,
          color: AppColors.textSecondary,
        ),
        const SizedBox(width: AppSizes.gapSmall),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

/// Phase two: the scenes, to be tapped in order.
class _OrderView extends StatelessWidget {
  const _OrderView({
    required this.game,
    required this.message,
    required this.tone,
    required this.hintShown,
    required this.reducedMotion,
    required this.onHint,
    required this.onTap,
    required this.onReadAgain,
    required this.onStartOver,
    required this.onSeeResult,
  });

  final StorySequenceGame game;
  final String message;
  final MessageTone tone;
  final bool hintShown;
  final bool reducedMotion;
  final VoidCallback onHint;
  final ValueChanged<StoryScene> onTap;
  final VoidCallback onReadAgain;
  final VoidCallback onStartOver;
  final VoidCallback onSeeResult;

  @override
  Widget build(BuildContext context) {
    return GameBoardLayout(
      header: Column(
        children: [
          Text(
            '${game.placed.length} of ${game.sceneCount} in place',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryDark,
            ),
          ),
          const SizedBox(height: AppSizes.gapSmall),
          GameMessageBanner(message: message, tone: tone),
          if (hintShown) ...[
            const SizedBox(height: AppSizes.gapSmall),
            _Hint(text: game.story.hint),
          ],
        ],
      ),
      // The scenes are a list on purpose: five rows of a full sentence each do
      // not fit on a phone at a large font size, and a caption clipped to fit
      // would make the puzzle unanswerable.
      board: ListView(
        children: [
          for (final scene in game.shuffled) ...[
            _SceneTile(
              scene: scene,
              position: game.positionOf(scene),
              reducedMotion: reducedMotion,
              onTap: game.isPlaced(scene) || game.isComplete
                  ? null
                  : () => onTap(scene),
            ),
            const SizedBox(height: AppSizes.gap),
          ],
          if (game.isComplete) _Explanation(story: game.story),
        ],
      ),
      footer: game.isComplete
          ? FilledButton.icon(
            onPressed: onSeeResult,
            icon: const Icon(Icons.emoji_events_rounded, size: 28),
            label: const Text('See how you did'),
          )
        : Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onReadAgain,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, AppSizes.minTouchTarget),
                  ),
                  icon: const Icon(Icons.menu_book_rounded, size: 24),
                  label: const Text('The story'),
                ),
              ),
              const SizedBox(width: AppSizes.gapSmall),
              Expanded(
                child: hintShown
                    ? OutlinedButton.icon(
                        onPressed: onStartOver,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, AppSizes.minTouchTarget),
                        ),
                        icon: const Icon(Icons.replay_rounded, size: 24),
                        label: const Text('Start over'),
                      )
                    : OutlinedButton.icon(
                        onPressed: onHint,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, AppSizes.minTouchTarget),
                        ),
                        icon: const Icon(Icons.help_outline_rounded, size: 24),
                        label: const Text('Hint'),
                      ),
              ),
            ],
          ),
    );
  }
}

/// One scene: a wide row, because the caption is a sentence and a sentence in a
/// small square tile wraps into something nobody can read.
class _SceneTile extends StatelessWidget {
  const _SceneTile({
    required this.scene,
    required this.position,
    required this.reducedMotion,
    required this.onTap,
  });

  final StoryScene scene;

  /// 1, 2, 3 once placed. Null while still to be placed.
  final int? position;

  final bool reducedMotion;
  final VoidCallback? onTap;

  bool get isPlaced => position != null;

  static const Color _placedBorder = Color(0xFF1B5E20);
  static const Color _placedFill = Color(0xFFE3F1E4);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      label: isPlaced
          ? 'Number $position. ${scene.caption}. ${scene.description}'
          : 'Not placed yet. ${scene.caption}. ${scene.description}',
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSizes.radius),
          child: AnimatedContainer(
            duration: Duration(milliseconds: reducedMotion ? 0 : 200),
            constraints: const BoxConstraints(minHeight: 96),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isPlaced ? _placedFill : AppColors.surface,
              borderRadius: BorderRadius.circular(AppSizes.radius),
              border: Border.all(
                color: isPlaced ? _placedBorder : AppColors.border,
                width: isPlaced ? 3 : 2,
              ),
            ),
            child: Row(
              children: [
                // The position number, or a blank circle while unplaced. A
                // number is what tells the player the order they have built —
                // it must never be conveyed by colour alone.
                Container(
                  width: 54,
                  height: 54,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isPlaced ? _placedBorder : AppColors.background,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.border, width: 1.5),
                  ),
                  child: Text(
                    isPlaced ? '$position' : '?',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: isPlaced ? Colors.white : AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: AppSizes.gap),
                Icon(scene.icon, size: 38, color: scene.color),
                const SizedBox(width: AppSizes.gapSmall),
                Expanded(
                  child: Text(
                    scene.caption,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
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

class _Hint extends StatelessWidget {
  const _Hint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.lightbulb_outline_rounded,
            size: 24,
            color: AppColors.primary,
          ),
          const SizedBox(width: AppSizes.gapSmall),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 18,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Why that order is the right one. Shown on completing the story and again on
/// the result, because "you got it" without "here is why" teaches nothing.
class _Explanation extends StatelessWidget {
  const _Explanation({required this.story});

  final CulturalStory story;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(AppSizes.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Why this order',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryDark,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            story.explanation,
            style: const TextStyle(
              fontSize: 18,
              height: 1.4,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({
    required this.game,
    required this.onPlayAgain,
    required this.onBack,
  });

  final StorySequenceGame game;
  final VoidCallback onPlayAgain;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          GameResultPanel(
            result: game.toResult(),
            headline: game.isComplete
                ? 'You put the whole story in order!'
                : 'Thank you for playing',
            subtitle: game.story.title,
            icon: game.isComplete
                ? Icons.check_rounded
                : Icons.favorite_rounded,
            iconColor: game.isComplete
                ? const Color(0xFF1B5E20)
                : AppColors.primary,
            extraStats: {
              'Scenes in order': '${game.placed.length} of ${game.sceneCount}',
              if (game.hintsUsed > 0) 'Hint used': 'Yes',
            },
            onPlayAgain: onPlayAgain,
            onBackToGames: onBack,
          ),
          const SizedBox(height: AppSizes.gap),
          _Explanation(story: game.story),
          const SizedBox(height: AppSizes.gap),
        ],
      ),
    );
  }
}
