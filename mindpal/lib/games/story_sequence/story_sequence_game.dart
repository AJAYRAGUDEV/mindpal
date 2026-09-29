import 'dart:math';

import '../../content/cultural_pack.dart';
import '../../models/difficulty.dart';
import '../../models/game_result.dart';
import '../../models/game_type.dart';

/// What one tap on a scene did.
enum ScenePlacement {
  /// That was the next scene in the story. It has been placed.
  placed,

  /// Placed, and the story is now complete.
  completed,

  /// Not the next scene. Nothing is placed and one mistake is counted.
  wrong,

  /// Tap did nothing (already placed, or the story is finished).
  ignored,
}

/// Difficulty for Story Order: the NUMBER of scenes, and nothing else.
///
/// Deliberately not "hide the captions at Hard". Taking the words away would
/// turn the game into "can you identify this small symbol", which is an
/// eyesight test rather than a harder memory task — the same reasoning that
/// keeps labels on every Odd-One-Out tile.
class StorySequenceConfig {
  const StorySequenceConfig({
    required this.difficulty,
    required this.preferredScenes,
    required this.difficultyBonus,
  });

  final Difficulty difficulty;

  /// How many scenes this level would like. A pack may not have a story of
  /// exactly this length, in which case the closest one is used and the screen
  /// says so — see [StorySequenceGame.storyIsShorterThanAsked].
  final int preferredScenes;

  final int difficultyBonus;

  static const Map<Difficulty, StorySequenceConfig> _table = {
    Difficulty.easy: StorySequenceConfig(
      difficulty: Difficulty.easy,
      preferredScenes: 3,
      difficultyBonus: 0,
    ),
    Difficulty.medium: StorySequenceConfig(
      difficulty: Difficulty.medium,
      preferredScenes: 4,
      difficultyBonus: 50,
    ),
    Difficulty.hard: StorySequenceConfig(
      difficulty: Difficulty.hard,
      preferredScenes: 5,
      difficultyBonus: 100,
    ),
  };

  static StorySequenceConfig forDifficulty(Difficulty difficulty) =>
      _table[difficulty]!;
}

/// Put the scenes of a short story back in order.
///
/// Plain Dart with no Flutter import, like every other game's rules file.
///
/// **Why tapping rather than dragging.** The brief calls this "arranging"
/// scenes, and the obvious implementation is drag-and-drop. Drag-and-drop is
/// one of the hardest gestures there is for someone with a tremor or stiff
/// fingers: it needs a press, a sustained hold, a controlled move and a release
/// in the right place, and failing any part of it undoes the whole attempt.
/// Here the player taps the scene they think comes next. One tap. A wrong tap
/// is told gently and costs nothing but a count, and the board never ends up in
/// a wrong arrangement the player then has to fix.
///
/// **Why it is not built on SequenceRecallGame.** That game shows a pattern and
/// asks for it back from short-term memory; this one asks the player to reason
/// about what must happen before what. The shared parts — Difficulty,
/// GameResult, the result panel, the stat bar — are reused. The rules are not
/// the same rules, and pretending they were would have meant a config flag
/// changing the meaning of every field.
class StorySequenceGame {
  StorySequenceGame({
    required this.config,
    required this.pack,
    CulturalStory? story,
    Random? random,
  }) : _random = random ?? Random(),
       story = story ?? _chooseStory(pack, config.preferredScenes) {
    _shuffleScenes();
  }

  final StorySequenceConfig config;
  final CulturalPack pack;
  final CulturalStory story;
  final Random _random;

  /// The scenes as the player sees them: shuffled, and never in story order.
  late List<StoryScene> shuffled;

  /// Scene ids the player has correctly placed, in the order they placed them.
  final List<String> placed = [];

  int mistakes = 0;
  int hintsUsed = 0;

  DateTime? _startedAt;
  DateTime? _finishedAt;

  /// True when the pack had no story of the length this difficulty wanted.
  /// The screen says so plainly rather than letting Hard silently be Medium.
  bool get storyIsShorterThanAsked =>
      story.sceneCount < config.preferredScenes;

  int get sceneCount => story.sceneCount;

  bool get isComplete => placed.length == sceneCount;

  bool get hasStarted => _startedAt != null;

  Duration get elapsed {
    final start = _startedAt;
    if (start == null) return Duration.zero;
    return (_finishedAt ?? DateTime.now()).difference(start);
  }

  /// The scene that should be placed next, or null when the story is done.
  StoryScene? get expectedScene =>
      isComplete ? null : story.scenes[placed.length];

  bool isPlaced(StoryScene scene) => placed.contains(scene.id);

  /// 1 for the first scene placed, and so on. Null when not yet placed — the
  /// screen uses this to show a number on each placed tile.
  int? positionOf(StoryScene scene) {
    final index = placed.indexOf(scene.id);
    return index < 0 ? null : index + 1;
  }

  /// The story so far, as the player has built it.
  List<StoryScene> get placedScenes => [
    for (final id in placed) story.scenes.firstWhere((s) => s.id == id),
  ];

  /// The one entry point for playing.
  ScenePlacement tap(StoryScene scene) {
    if (isComplete || isPlaced(scene)) return ScenePlacement.ignored;

    _startedAt ??= DateTime.now();

    if (scene.id != expectedScene!.id) {
      mistakes++;
      return ScenePlacement.wrong;
    }

    placed.add(scene.id);
    if (isComplete) {
      _finishedAt = DateTime.now();
      return ScenePlacement.completed;
    }
    return ScenePlacement.placed;
  }

  /// Counted once per game, however many times the player reads it. The hint
  /// names what to think about; it never names the next scene.
  void useHint() {
    if (hintsUsed == 0) hintsUsed++;
  }

  /// Clears the placed scenes and reshuffles, keeping the same story and the
  /// running mistake count. Used by "Start this story again".
  void restartOrder() {
    placed.clear();
    _finishedAt = null;
    _shuffleScenes();
  }

  void _shuffleScenes() {
    final scenes = List<StoryScene>.from(story.scenes);
    // A shuffle that happens to produce the story's own order hands the player
    // a solved puzzle. With three scenes that is one chance in six, which is
    // often enough to matter, so it is reshuffled until it differs.
    if (scenes.length > 1) {
      final correct = story.scenes.map((s) => s.id).join('|');
      var attempts = 0;
      do {
        scenes.shuffle(_random);
        attempts++;
      } while (scenes.map((s) => s.id).join('|') == correct && attempts < 20);
    }
    shuffled = scenes;
  }

  /// Points for scenes placed, less what it took to get there.
  ///
  ///   each scene placed : 100
  ///   each mistake      : -20
  ///   a hint            : -25
  ///   difficulty        : +0 / +50 / +100
  ///
  /// No time term at all. This game asks the player to think about an order,
  /// and thinking slowly about an order is not doing it worse.
  int get score {
    if (placed.isEmpty) return 0;
    final total =
        placed.length * 100 -
        mistakes * 20 -
        hintsUsed * 25 +
        config.difficultyBonus;
    return total < 0 ? 0 : total;
  }

  GameResult toResult() => GameResult(
    gameType: GameType.folkStorySequence,
    difficulty: config.difficulty,
    score: score,
    durationSeconds: elapsed.inSeconds,
    completed: isComplete,
    mistakes: mistakes,
    playedAt: DateTime.now(),
    packId: pack.id,
    correct: placed.length,
    hintsUsed: hintsUsed,
  );

  /// The story closest to [wanted] scenes, preferring an exact match and then
  /// the longest one that is shorter.
  ///
  /// Throws when the pack has no stories at all. That is a programming error,
  /// not a user situation: the hub only offers this game for a pack with
  /// stories, and failing loudly here beats a blank screen.
  static CulturalStory _chooseStory(CulturalPack pack, int wanted) {
    if (pack.stories.isEmpty) {
      throw ArgumentError('Pack "${pack.id}" has no stories to order.');
    }
    for (final story in pack.stories) {
      if (story.sceneCount == wanted) return story;
    }
    final sorted = List<CulturalStory>.from(pack.stories)
      ..sort((a, b) => a.sceneCount.compareTo(b.sceneCount));
    final shorter = sorted.where((s) => s.sceneCount < wanted);
    return shorter.isNotEmpty ? shorter.last : sorted.first;
  }
}
