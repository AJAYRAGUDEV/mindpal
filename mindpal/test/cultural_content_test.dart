import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindpal/content/cultural_pack.dart';
import 'package:mindpal/content/pack_library.dart';
import 'package:mindpal/content/packs/assam_bihu_pack.dart';
import 'package:mindpal/games/cultural/cultural_adapters.dart';
import 'package:mindpal/games/memory_match/memory_match_config.dart';
import 'package:mindpal/games/memory_match/memory_match_game.dart';
import 'package:mindpal/games/odd_one_out/odd_one_out_game.dart';
import 'package:mindpal/games/story_sequence/story_sequence_game.dart';
import 'package:mindpal/models/difficulty.dart';
import 'package:mindpal/models/game_result.dart';
import 'package:mindpal/models/game_settings.dart';
import 'package:mindpal/models/game_type.dart';
import 'package:mindpal/services/adaptive_difficulty.dart';
import 'package:mindpal/services/game_settings_service.dart';
import 'package:mindpal/storage/local_storage.dart';

/// A deliberately awkward two-item pack, for the cases the real pack cannot
/// produce: two objects with the SAME displayed name.
const CulturalPack _sameNamePack = CulturalPack(
  id: 'test_same_name',
  title: 'Two things with one name',
  region: 'Nowhere',
  languageNote: 'English.',
  review: PackReview.pendingReview,
  artworkNote: 'Icons.',
  sources: [],
  stories: [],
  items: [
    CulturalItem(
      id: 'pitha_rice',
      name: 'Pitha',
      kind: ItemKind.food,
      icon: Icons.bakery_dining_rounded,
      color: Color(0xFF000001),
      description: 'One kind of pitha.',
    ),
    CulturalItem(
      id: 'pitha_sesame',
      name: 'Pitha',
      kind: ItemKind.food,
      icon: Icons.cookie_rounded,
      color: Color(0xFF000002),
      description: 'A different kind of pitha.',
    ),
  ],
);

void main() {
  group('the starter pack holds together', () {
    final pack = kAssamBihuPack;

    test('it is the pack the library ships', () {
      expect(kCulturalPacks, hasLength(1));
      expect(kCulturalPacks.single.id, pack.id);
    });

    test('every item id is unique', () {
      final ids = pack.items.map((item) => item.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('every item has a name and a description', () {
      for (final item in pack.items) {
        expect(item.name.trim(), isNotEmpty, reason: item.id);
        expect(item.description.trim(), isNotEmpty, reason: item.id);
      }
    });

    test('every kind can form a group, and Odd-One-Out gets six tiles', () {
      expect(pack.playableKinds, hasLength(ItemKind.values.length));
      for (final kind in ItemKind.values) {
        expect(pack.itemsOfKind(kind).length, greaterThanOrEqualTo(5));
      }
      // Five per kind means the biggest honest board is six: five of one kind
      // plus one other. Hard asks for nine and is told it is getting six.
      expect(pack.largestGroupSize, 6);
    });

    test('it can fill the hardest Memory Match board', () {
      final hard = MemoryMatchConfig.forDifficulty(Difficulty.hard);
      expect(pack.canFillMatchBoard(hard.pairCount), isTrue);
    });

    test('there is a story for each difficulty, of the right length', () {
      // Easy wants 3 scenes, Medium 4, Hard 5. All three exist, so no
      // difficulty has to fall back.
      for (final (difficulty, scenes) in [
        (Difficulty.easy, 3),
        (Difficulty.medium, 4),
        (Difficulty.hard, 5),
      ]) {
        final game = StorySequenceGame(
          config: StorySequenceConfig.forDifficulty(difficulty),
          pack: pack,
        );
        expect(game.sceneCount, scenes, reason: difficulty.name);
        expect(game.storyIsShorterThanAsked, isFalse, reason: difficulty.name);
      }
    });

    test('every story explains itself and its scene ids are unique', () {
      for (final story in pack.stories) {
        expect(story.text.trim(), isNotEmpty, reason: story.id);
        expect(story.explanation.trim(), isNotEmpty, reason: story.id);
        expect(story.hint.trim(), isNotEmpty, reason: story.id);
        final ids = story.scenes.map((scene) => scene.id).toList();
        expect(ids.toSet().length, ids.length, reason: story.id);
        expect(story.scenes.length, greaterThanOrEqualTo(3), reason: story.id);
      }
    });

    test('an invented story is never labelled as traditional', () {
      // The honesty rule in data form: anything written for MindPal must carry
      // an attribution saying so, so no screen can present it as folklore.
      for (final story in pack.stories) {
        if (story.origin == ContentOrigin.original) {
          expect(story.attribution, isNotNull, reason: story.id);
          expect(story.attribution, contains('not a traditional tale'));
        }
      }
    });

    test('the pack says it has not been reviewed, and names its artwork', () {
      expect(pack.review, PackReview.pendingReview);
      expect(pack.artworkNote, contains('not photographs'));
      expect(pack.sources, isNotEmpty);
    });
  });

  group('pack to game adapters', () {
    test('match tiles carry the item id as the pair key, not the name', () {
      final tiles = matchTilesFor(_sameNamePack);

      expect(tiles.map((tile) => tile.label).toSet(), {'Pitha'});
      expect(tiles.map((tile) => tile.pairKey).toSet(), {
        'pitha_rice',
        'pitha_sesame',
      });
    });

    test('two different objects with one name are NOT a pair', () {
      // The bug this guards: matching on the visible label would let two
      // different foods that happen to share a name count as a match.
      final game = MemoryMatchGame(
        config: MemoryMatchConfig.forPairs(Difficulty.easy, 2),
        pool: matchTilesFor(_sameNamePack),
        random: Random(3),
      );

      final first = game.cards.first;
      final differentObject = game.cards.firstWhere(
        (card) => card.symbol.pairKey != first.symbol.pairKey,
      );

      expect(first.symbol.label, differentObject.symbol.label);
      expect(game.tap(first), TapResult.firstCardRevealed);
      expect(game.tap(differentObject), TapResult.mismatched);
      expect(game.matches, 0);
    });

    test('a real pair still matches', () {
      final game = MemoryMatchGame(
        config: MemoryMatchConfig.forPairs(Difficulty.easy, 2),
        pool: matchTilesFor(_sameNamePack),
        random: Random(3),
      );

      final first = game.cards.first;
      final twin = game.cards.firstWhere(
        (card) =>
            card.id != first.id && card.symbol.pairKey == first.symbol.pairKey,
      );

      expect(game.tap(first), TapResult.firstCardRevealed);
      expect(game.tap(twin), TapResult.matched);
      expect(game.matches, 1);
    });

    test('the pack id and match count reach the saved result', () {
      final game = MemoryMatchGame(
        config: MemoryMatchConfig.forPairs(Difficulty.easy, 2),
        pool: matchTilesFor(kAssamBihuPack),
        packId: kAssamBihuPack.id,
        random: Random(1),
      );

      final result = game.toResult();
      expect(result.packId, 'assam_bihu_v1');
      expect(result.correct, 0);
      expect(result.gameType, GameType.memoryMatch);
    });

    test('the family board is filed under its own game, not Memory Match', () {
      final game = MemoryMatchGame(
        config: MemoryMatchConfig.forPairs(Difficulty.easy, 2),
        pool: matchTilesFor(_sameNamePack),
        random: Random(1),
      );

      expect(
        game.toResult(gameType: GameType.familyPhotoMatch).gameType,
        GameType.familyPhotoMatch,
      );
    });

    test('a cultural deck only ever groups by kinds the pack holds', () {
      final deck = deckFor(kAssamBihuPack);
      expect(deck.packId, kAssamBihuPack.id);
      expect(deck.isPlayable, isTrue);
      expect(deck.largestBoard, 6);

      for (var seed = 0; seed < 50; seed++) {
        final game = OddOneOutGame(
          config: OddOneOutConfig.forDifficulty(Difficulty.hard),
          deck: deck,
          random: Random(seed),
        );

        // Hard asks for nine; the pack supports six, and the game says so
        // rather than dealing a short board.
        expect(game.itemCount, 6, reason: 'seed $seed');
        expect(game.items, hasLength(6), reason: 'seed $seed');
        expect(game.boardWasReduced, isTrue, reason: 'seed $seed');

        // Exactly one odd tile, and the rule is never ambiguous.
        final odd = game.items[game.oddIndex].category;
        final others = [
          for (var i = 0; i < game.items.length; i++)
            if (i != game.oddIndex) game.items[i].category,
        ];
        expect(others.toSet(), hasLength(1), reason: 'seed $seed');
        expect(others.first, isNot(odd), reason: 'seed $seed');
      }
    });

    test('the explanation names both kinds and never the wrong tile', () {
      final game = OddOneOutGame(
        config: OddOneOutConfig.forDifficulty(Difficulty.easy),
        deck: deckFor(kAssamBihuPack),
        random: Random(11),
      );

      expect(game.explanation, contains(game.oddItem.label));
      expect(game.explanation, contains(game.majorityCategory.many));
      expect(game.explanation, startsWith('The others are all '));
      expect(game.explanation, contains(game.oddCategory.singular));
      // The hint points at the rule without naming the answer.
      expect(game.hint, contains(game.majorityCategory.many));
      expect(game.hint, isNot(contains(game.oddItem.label)));
    });

    test('a hint is counted once per round however often it is asked', () {
      final game = OddOneOutGame(
        config: OddOneOutConfig.forDifficulty(Difficulty.easy),
        deck: deckFor(kAssamBihuPack),
        random: Random(5),
      );

      game.useHint();
      game.useHint();
      game.useHint();
      expect(game.hintsUsed, 1);

      game.answer(game.oddIndex);
      game.next();
      game.useHint();
      expect(game.hintsUsed, 2);
      expect(game.toResult().hintsUsed, 2);
    });
  });

  group('Story Order', () {
    StorySequenceGame game({Difficulty difficulty = Difficulty.easy, int seed = 1}) =>
        StorySequenceGame(
          config: StorySequenceConfig.forDifficulty(difficulty),
          pack: kAssamBihuPack,
          random: Random(seed),
        );

    test('the shuffle never hands the player a solved puzzle', () {
      for (var seed = 0; seed < 200; seed++) {
        final story = game(seed: seed);
        final shuffled = story.shuffled.map((scene) => scene.id).join('|');
        final correct = story.story.scenes.map((scene) => scene.id).join('|');
        expect(shuffled, isNot(correct), reason: 'seed $seed');
      }
    });

    test('tapping the scenes in order finishes the story', () {
      final story = game();

      for (var i = 0; i < story.sceneCount; i++) {
        final expected = story.expectedScene!;
        final outcome = story.tap(expected);
        expect(
          outcome,
          i == story.sceneCount - 1
              ? ScenePlacement.completed
              : ScenePlacement.placed,
        );
      }

      expect(story.isComplete, isTrue);
      expect(story.mistakes, 0);
      expect(story.placed, hasLength(3));
      expect(story.toResult().completed, isTrue);
      expect(story.toResult().correct, 3);
    });

    test('a wrong tap places nothing and is not a failure', () {
      final story = game();
      final wrong = story.story.scenes.last; // the last scene cannot be first

      expect(story.tap(wrong), ScenePlacement.wrong);
      expect(story.placed, isEmpty);
      expect(story.mistakes, 1);
      // The player can still go on and finish.
      expect(story.tap(story.expectedScene!), ScenePlacement.placed);
      expect(story.placed, hasLength(1));
    });

    test('tapping a scene already placed does nothing at all', () {
      final story = game();
      final first = story.expectedScene!;
      story.tap(first);

      expect(story.tap(first), ScenePlacement.ignored);
      expect(story.placed, hasLength(1));
      expect(story.mistakes, 0);
    });

    test('positions are 1-based and only set once placed', () {
      final story = game();
      final first = story.expectedScene!;

      expect(story.positionOf(first), isNull);
      story.tap(first);
      expect(story.positionOf(first), 1);
      expect(story.isPlaced(first), isTrue);
    });

    test('starting the order again keeps the honest mistake count', () {
      final story = game();
      story.tap(story.story.scenes.last); // a mistake
      story.tap(story.expectedScene!);
      expect(story.placed, hasLength(1));

      story.restartOrder();

      expect(story.placed, isEmpty);
      expect(story.isComplete, isFalse);
      // Restarting must not be a way to wipe the record of the session.
      expect(story.mistakes, 1);
    });

    test('a hint is counted once, however often it is read', () {
      final story = game();
      story.useHint();
      story.useHint();
      expect(story.hintsUsed, 1);
      expect(story.toResult().hintsUsed, 1);
    });

    test('score cannot go below zero, and is zero before anything is placed', () {
      final story = game();
      expect(story.score, 0);

      for (var i = 0; i < 40; i++) {
        story.tap(story.story.scenes.last);
      }
      expect(story.mistakes, greaterThan(20));
      expect(story.score, 0);
    });

    test('the result records the pack and the game type', () {
      final result = game().toResult();
      expect(result.gameType, GameType.folkStorySequence);
      expect(result.packId, kAssamBihuPack.id);
    });

    test('a pack with no stories fails loudly rather than showing a blank', () {
      expect(
        () => StorySequenceGame(
          config: StorySequenceConfig.forDifficulty(Difficulty.easy),
          pack: _sameNamePack,
        ),
        throwsArgumentError,
      );
    });
  });

  group('Memory Match pause', () {
    test('time spent paused is not charged as playing time', () async {
      final game = MemoryMatchGame(
        config: MemoryMatchConfig.forPairs(Difficulty.easy, 2),
        random: Random(1),
      );

      game.tap(game.cards.first); // starts the clock
      game.pause();
      expect(game.isPaused, isTrue);

      await Future<void>.delayed(const Duration(milliseconds: 120));
      final whilePaused = game.elapsed;
      await Future<void>.delayed(const Duration(milliseconds: 120));

      // The clock did not move while paused.
      expect(game.elapsed.inMilliseconds, whilePaused.inMilliseconds);

      game.resume();
      expect(game.isPaused, isFalse);
    });

    test('pausing before the first tap does nothing', () {
      final game = MemoryMatchGame(
        config: MemoryMatchConfig.forPairs(Difficulty.easy, 2),
        random: Random(1),
      );
      game.pause();
      expect(game.isPaused, isFalse);
      expect(game.elapsed, Duration.zero);
    });
  });

  group('adaptive difficulty', () {
    const adaptive = AdaptiveDifficulty();

    GameResult session({
      required bool completed,
      int mistakes = 0,
      int hintsUsed = 0,
      int durationSeconds = 60,
      Difficulty difficulty = Difficulty.easy,
      GameType gameType = GameType.memoryMatch,
      int daysAgo = 0,
    }) => GameResult(
      gameType: gameType,
      difficulty: difficulty,
      score: 100,
      durationSeconds: durationSeconds,
      completed: completed,
      mistakes: mistakes,
      hintsUsed: hintsUsed,
      playedAt: DateTime.now().subtract(Duration(days: daysAgo)),
    );

    test('says nothing at all with no history', () {
      expect(
        adaptive.suggest(
          history: const [],
          gameType: GameType.memoryMatch,
          current: Difficulty.easy,
        ),
        isNull,
      );
    });

    test('says nothing after one good game', () {
      // One good day is not a pattern.
      expect(
        adaptive.suggest(
          history: [session(completed: true)],
          gameType: GameType.memoryMatch,
          current: Difficulty.easy,
        ),
        isNull,
      );
    });

    test('offers a harder level after three comfortable games', () {
      final suggestion = adaptive.suggest(
        history: [
          session(completed: true, daysAgo: 0),
          session(completed: true, daysAgo: 1),
          session(completed: true, daysAgo: 2),
        ],
        gameType: GameType.memoryMatch,
        current: Difficulty.easy,
      );

      expect(suggestion, isNotNull);
      expect(suggestion!.to, Difficulty.medium);
      expect(suggestion.isHarder, isTrue);
      // The reason is about the games, never about the person.
      expect(suggestion.reason.toLowerCase(), isNot(contains('memory')));
      expect(suggestion.reason, contains('Medium'));
    });

    test('a slow but clean game still counts as comfortable', () {
      // The rule that matters most here: taking a long time is NOT doing badly,
      // and nothing in the suggestion reads the clock.
      final suggestion = adaptive.suggest(
        history: [
          session(completed: true, durationSeconds: 900),
          session(completed: true, durationSeconds: 1200),
          session(completed: true, durationSeconds: 1800),
        ],
        gameType: GameType.memoryMatch,
        current: Difficulty.easy,
      );

      expect(suggestion?.to, Difficulty.medium);
    });

    test('offers an easier level after two hard-going games', () {
      final suggestion = adaptive.suggest(
        history: [
          session(completed: false, difficulty: Difficulty.medium),
          session(completed: true, mistakes: 6, difficulty: Difficulty.medium),
        ],
        gameType: GameType.memoryMatch,
        current: Difficulty.medium,
      );

      expect(suggestion, isNotNull);
      expect(suggestion!.to, Difficulty.easy);
      expect(suggestion.isHarder, isFalse);
    });

    test('leaning on hints counts as hard going', () {
      final suggestion = adaptive.suggest(
        history: [
          session(completed: true, hintsUsed: 2, difficulty: Difficulty.medium),
          session(completed: true, hintsUsed: 3, difficulty: Difficulty.medium),
        ],
        gameType: GameType.memoryMatch,
        current: Difficulty.medium,
      );

      expect(suggestion?.to, Difficulty.easy);
    });

    test('never offers harder than Hard or easier than Easy', () {
      expect(
        adaptive.suggest(
          history: [
            for (var i = 0; i < 5; i++)
              session(completed: true, difficulty: Difficulty.hard),
          ],
          gameType: GameType.memoryMatch,
          current: Difficulty.hard,
        ),
        isNull,
      );

      expect(
        adaptive.suggest(
          history: [
            for (var i = 0; i < 5; i++) session(completed: false),
          ],
          gameType: GameType.memoryMatch,
          current: Difficulty.easy,
        ),
        isNull,
      );
    });

    test('sessions from another game or level are not counted', () {
      expect(
        adaptive.suggest(
          history: [
            session(completed: true, gameType: GameType.oddOneOut),
            session(completed: true, gameType: GameType.oddOneOut),
            session(completed: true, gameType: GameType.oddOneOut),
            session(completed: true, difficulty: Difficulty.hard),
          ],
          gameType: GameType.memoryMatch,
          current: Difficulty.easy,
        ),
        isNull,
      );
    });

    test('the thresholds are configurable in one place', () {
      // Raising the streak makes MindPal slower to suggest, and nothing else
      // needs to change.
      const patient = AdaptiveDifficulty(
        config: AdaptiveDifficultyConfig(comfortableStreak: 5),
      );

      final threeGoodGames = [
        session(completed: true),
        session(completed: true),
        session(completed: true),
      ];

      expect(
        const AdaptiveDifficulty().suggest(
          history: threeGoodGames,
          gameType: GameType.memoryMatch,
          current: Difficulty.easy,
        ),
        isNotNull,
      );
      expect(
        patient.suggest(
          history: threeGoodGames,
          gameType: GameType.memoryMatch,
          current: Difficulty.easy,
        ),
        isNull,
      );
    });
  });

  group('game settings survive a restart', () {
    test('what is saved is what comes back', () async {
      final storage = InMemoryStorage();
      await storage.init();
      final service = GameSettingsService(storage);

      expect(service.load(), isA<GameSettings>());
      expect(service.load().soundOn, isTrue);
      expect(service.load().reducedMotion, isFalse);
      expect(service.load().packId, isNull);

      await service.save(
        const GameSettings(
          soundOn: false,
          reducedMotion: true,
          spokenInstructions: true,
          difficulty: Difficulty.hard,
          packId: 'assam_bihu_v1',
          acceptDifficultySuggestions: false,
        ),
      );

      // A fresh service over the same storage: this is what a relaunch does.
      final reopened = GameSettingsService(storage).load();
      expect(reopened.soundOn, isFalse);
      expect(reopened.reducedMotion, isTrue);
      expect(reopened.spokenInstructions, isTrue);
      expect(reopened.difficulty, Difficulty.hard);
      expect(reopened.packId, 'assam_bihu_v1');
      expect(reopened.acceptDifficultySuggestions, isFalse);
    });

    test('unreadable saved settings fall back to the defaults', () async {
      final storage = InMemoryStorage();
      await storage.init();
      await storage.writeString('game_settings_v1', 'not json at all');

      expect(GameSettingsService(storage).load().soundOn, isTrue);
    });

    test('an unknown pack id resolves to the pack that ships', () {
      // A settings file naming a pack a later build removed must not leave the
      // games with nothing to deal.
      expect(packFor('a_pack_that_was_deleted').id, kDefaultPack.id);
      expect(packFor(null).id, kDefaultPack.id);
      // But a SAVED SESSION with an unknown pack honestly reports none.
      expect(packById('a_pack_that_was_deleted'), isNull);
    });
  });

  group('saved progress', () {
    test('the new fields survive a round trip', () {
      final result = GameResult(
        gameType: GameType.folkStorySequence,
        difficulty: Difficulty.medium,
        score: 310,
        durationSeconds: 95,
        completed: true,
        mistakes: 2,
        playedAt: DateTime(2026, 3, 14, 10, 30),
        packId: 'assam_bihu_v1',
        correct: 4,
        hintsUsed: 1,
      );

      final read = GameResult.fromJson(result.toJson());

      expect(read.gameType, GameType.folkStorySequence);
      expect(read.packId, 'assam_bihu_v1');
      expect(read.correct, 4);
      expect(read.hintsUsed, 1);
      expect(read.completed, isTrue);
    });

    test('history saved before packs existed still reads', () {
      // Exactly the shape the old app wrote. It must open, not be discarded.
      final old = GameResult.fromMap({
        'id': 7,
        'gameType': 'memoryMatch',
        'difficulty': 'easy',
        'score': 400,
        'durationSeconds': 60,
        'completed': true,
        'mistakes': 1,
        'playedAt': '2026-01-05T09:00:00.000',
      });

      expect(old.id, 7);
      expect(old.score, 400);
      expect(old.packId, isNull);
      expect(old.correct, 0);
      expect(old.hintsUsed, 0);
    });

    test('an id carried onto a result keeps the new fields', () {
      final result = GameResult(
        gameType: GameType.familyPhotoMatch,
        difficulty: Difficulty.easy,
        score: 100,
        durationSeconds: 10,
        completed: true,
        mistakes: 0,
        playedAt: DateTime(2026, 5, 1),
        correct: 3,
        hintsUsed: 2,
        packId: 'x',
      ).withId(42);

      expect(result.id, 42);
      expect(result.correct, 3);
      expect(result.hintsUsed, 2);
      expect(result.packId, 'x');
    });
  });
}
