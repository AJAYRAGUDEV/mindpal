import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindpal/content/packs/assam_bihu_pack.dart';
import 'package:mindpal/games/cultural/cultural_adapters.dart';
import 'package:mindpal/games/family_match/family_match_setup_screen.dart';
import 'package:mindpal/games/memory_match/memory_match_screen.dart';
import 'package:mindpal/games/odd_one_out/odd_one_out_screen.dart';
import 'package:mindpal/games/story_sequence/story_sequence_screen.dart';
import 'package:mindpal/l10n/app_language.dart';
import 'package:mindpal/l10n/app_strings.dart';
import 'package:mindpal/l10n/language_scope.dart';
import 'package:mindpal/models/difficulty.dart';
import 'package:mindpal/models/game_result.dart';
import 'package:mindpal/models/game_settings.dart';
import 'package:mindpal/models/game_type.dart';
import 'package:mindpal/models/vault_memory.dart';
import 'package:mindpal/screens/games/player_progress_screen.dart';
import 'package:mindpal/services/memory_vault_service.dart';
import 'package:mindpal/storage/local_storage.dart';
import 'package:mindpal/storage/media/media_store.dart';

/// A real 1x1 PNG. Garbage bytes would make Image.memory take its error path,
/// which is a different case — tested separately below.
final Uint8List _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8'
  '/x8AAwMCAO+ip1sAAAAASUVORK5CYII=',
);

/// Wraps a screen in the minimum a game needs: a LanguageScope and a
/// MaterialApp. No services, no network, no voice.
Widget _host(Widget child) => LanguageScope(
  strings: AppStrings.forLanguage(kAppLanguages.first),
  onLanguageChanged: (_) {},
  child: MaterialApp(home: child),
);

/// Wraps a screen at a larger text size, to check nothing overflows.
Widget _hostAtTextScale(Widget child, double scale) => LanguageScope(
  strings: AppStrings.forLanguage(kAppLanguages.first),
  onLanguageChanged: (_) {},
  child: MaterialApp(
    builder: (context, widget) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(scale),
      ),
      child: widget!,
    ),
    home: child,
  ),
);

/// A tall phone, so a ListView builds the children a test looks for.
void _phoneSized(WidgetTester tester) {
  tester.view.physicalSize = const Size(430, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<MemoryVaultService> _vaultWith(
  int photoCount, {
  int ghostCount = 0,
}) async {
  final storage = InMemoryStorage();
  await storage.init();
  final vault = MemoryVaultService(storage, media: InMemoryMediaStore());
  await vault.init();

  var memories = <VaultMemory>[];
  for (var i = 1; i <= photoCount; i++) {
    memories = await vault.commit(
      memories,
      MemoryDraft(
        memory: VaultMemory(
          id: 0,
          title: 'Photo $i',
          createdAt: DateTime(2026, 1, i),
        ),
        newPhoto: PendingMedia(bytes: _png, extension: 'png'),
      ),
    );
  }

  // Records that point at media which is not there. This is what a photo
  // deleted outside the app, or lost by the platform, actually looks like.
  for (var i = 1; i <= ghostCount; i++) {
    memories = await vault.store.add(
      memories,
      (id) => VaultMemory(
        id: id,
        title: 'Missing $i',
        photoRef: 'ref-that-does-not-exist-$i',
        createdAt: DateTime(2026, 2, i),
      ),
    );
  }

  return vault;
}

void main() {
  group('Cultural Memory Match', () {
    testWidgets('starts, names the pack and says the facts are unchecked', (
      tester,
    ) async {
      _phoneSized(tester);
      await tester.pumpWidget(
        _host(
          MemoryMatchScreen(
            difficulty: Difficulty.easy,
            pool: matchTilesFor(kAssamBihuPack),
            packId: kAssamBihuPack.id,
            title: 'Cultural Memory Match',
            factsAreUnchecked: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Cultural Memory Match'), findsOneWidget);
      // Written instructions are on screen from the start, not behind a dialog.
      expect(
        find.textContaining('Tap a card to turn it over'),
        findsOneWidget,
      );
      // Eight cards, all face down.
      expect(find.text('?'), findsNWidgets(8));
      expect(find.text('Matches'), findsOneWidget);
    });

    testWidgets('a cultural card shows the object name when turned over', (
      tester,
    ) async {
      _phoneSized(tester);
      await tester.pumpWidget(
        _host(
          MemoryMatchScreen(
            difficulty: Difficulty.easy,
            pool: matchTilesFor(kAssamBihuPack),
            packId: kAssamBihuPack.id,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('?').first);
      await tester.pumpAndSettle();

      // Seven still hidden, and the one turned over is named — the name is
      // always shown, never only a picture.
      expect(find.text('?'), findsNWidgets(7));
      expect(find.textContaining('Now find its pair'), findsOneWidget);
    });

    testWidgets('pause covers the board and offers a way out', (tester) async {
      _phoneSized(tester);
      await tester.pumpWidget(
        _host(
          MemoryMatchScreen(
            difficulty: Difficulty.easy,
            pool: matchTilesFor(kAssamBihuPack),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Pause'));
      await tester.pumpAndSettle();

      expect(find.text('Paused'), findsOneWidget);
      expect(find.text('Carry on playing'), findsOneWidget);
      expect(find.text('Start again'), findsOneWidget);
      expect(find.text('Leave this game'), findsOneWidget);

      await tester.tap(find.text('Carry on playing'));
      await tester.pumpAndSettle();
      expect(find.text('Paused'), findsNothing);
    });

    testWidgets('leaving hands back a result even when unfinished', (
      tester,
    ) async {
      _phoneSized(tester);
      GameResult? popped;

      await tester.pumpWidget(
        _host(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                popped = await Navigator.of(context).push<GameResult>(
                  MaterialPageRoute(
                    builder: (_) => MemoryMatchScreen(
                      difficulty: Difficulty.easy,
                      pool: matchTilesFor(kAssamBihuPack),
                      packId: kAssamBihuPack.id,
                    ),
                  ),
                );
              },
              child: const Text('go'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Leave this game'));
      await tester.pumpAndSettle();

      // A game that was played is recorded, finished or not. That is what makes
      // the "games you started" list on the progress screen possible.
      expect(popped, isNotNull);
      expect(popped!.completed, isFalse);
      expect(popped!.packId, kAssamBihuPack.id);
    });
  });

  group('Cultural Odd-One-Out', () {
    testWidgets('offers a hint that names the rule, then explains the answer', (
      tester,
    ) async {
      _phoneSized(tester);
      await tester.pumpWidget(
        _host(
          OddOneOutScreen(
            difficulty: Difficulty.easy,
            deck: deckFor(kAssamBihuPack),
            title: 'Cultural Odd-One-Out',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Cultural Odd-One-Out'), findsOneWidget);
      // Four tiles on Easy, and the pack supports it, so no reduction note.
      expect(
        find.textContaining('the board is that size rather than'),
        findsNothing,
      );

      await tester.tap(find.text('Give me a hint'));
      await tester.pumpAndSettle();
      expect(find.text('Give me a hint'), findsNothing);
      expect(find.textContaining('Look for the one that is not'), findsOneWidget);
    });

    testWidgets('on Hard it says the board had to be smaller', (tester) async {
      _phoneSized(tester);
      await tester.pumpWidget(
        _host(
          OddOneOutScreen(
            difficulty: Difficulty.hard,
            deck: deckFor(kAssamBihuPack),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Honest rather than silent: Hard asks for nine tiles, the pack has five
      // of each kind, so the board is six and the screen says so.
      expect(
        find.textContaining('the board is that size rather than 9'),
        findsOneWidget,
      );
    });
  });

  group('Story Order', () {
    testWidgets('shows the story first, and says it is not folklore', (
      tester,
    ) async {
      _phoneSized(tester);
      await tester.pumpWidget(
        _host(
          StorySequenceScreen(
            difficulty: Difficulty.easy,
            pack: kAssamBihuPack,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tea in the morning'), findsOneWidget);
      expect(
        find.textContaining('not a traditional tale'),
        findsOneWidget,
      );
      // The scenes are not offered until the story has been shown.
      expect(find.text('I am ready'), findsOneWidget);
      expect(find.textContaining('in place'), findsNothing);
    });

    testWidgets('can be played through in order, and explains why', (
      tester,
    ) async {
      _phoneSized(tester);
      await tester.pumpWidget(
        _host(
          StorySequenceScreen(
            difficulty: Difficulty.easy,
            pack: kAssamBihuPack,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('I am ready'));
      await tester.pumpAndSettle();
      expect(find.text('0 of 3 in place'), findsOneWidget);

      // The captions in the correct order for "Tea in the morning".
      for (final caption in [
        'The youngest leaves are picked in the garden.',
        'The leaves are dried until they turn dark.',
        'The hot tea is poured out to drink.',
      ]) {
        await tester.tap(find.text(caption));
        await tester.pumpAndSettle();
      }

      expect(find.text('3 of 3 in place'), findsOneWidget);
      expect(find.textContaining('That is the whole story'), findsOneWidget);
      // The explanation is always given, not only on a wrong answer.
      expect(find.text('Why this order'), findsOneWidget);
      expect(find.text('See how you did'), findsOneWidget);
    });

    testWidgets('a wrong tap is gentle and places nothing', (tester) async {
      _phoneSized(tester);
      await tester.pumpWidget(
        _host(
          StorySequenceScreen(
            difficulty: Difficulty.easy,
            pack: kAssamBihuPack,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('I am ready'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('The hot tea is poured out to drink.'));
      await tester.pumpAndSettle();

      expect(find.text('0 of 3 in place'), findsOneWidget);
      expect(
        find.textContaining('Something else comes before that one'),
        findsOneWidget,
      );
      // The word "wrong" never appears.
      expect(find.textContaining('Wrong'), findsNothing);
    });

    testWidgets('the story can be re-read in the middle of ordering', (
      tester,
    ) async {
      _phoneSized(tester);
      await tester.pumpWidget(
        _host(
          StorySequenceScreen(
            difficulty: Difficulty.easy,
            pack: kAssamBihuPack,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('I am ready'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('The story'));
      await tester.pumpAndSettle();

      expect(find.text('Tea in the morning'), findsOneWidget);
      expect(find.text('I am ready'), findsOneWidget);
    });

    testWidgets('Hard uses the five-scene story', (tester) async {
      _phoneSized(tester);
      await tester.pumpWidget(
        _host(
          StorySequenceScreen(
            difficulty: Difficulty.hard,
            pack: kAssamBihuPack,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('How the golden shawl was made'), findsOneWidget);
      await tester.tap(find.text('I am ready'));
      await tester.pumpAndSettle();
      expect(find.text('0 of 5 in place'), findsOneWidget);
    });
  });

  group('Family Photo Match', () {
    testWidgets('with no photos it explains what is needed', (tester) async {
      _phoneSized(tester);
      final vault = await _vaultWith(0);

      await tester.pumpWidget(
        _host(
          FamilyMatchSetupScreen(vault: vault, difficulty: Difficulty.easy),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('This game needs a few photos first'), findsOneWidget);
      expect(
        find.textContaining('no photos in your Memory Vault yet'),
        findsOneWidget,
      );
      expect(find.text('Back to games'), findsOneWidget);
    });

    testWidgets('with two photos it says how many are needed', (tester) async {
      _phoneSized(tester);
      final vault = await _vaultWith(2);

      await tester.pumpWidget(
        _host(
          FamilyMatchSetupScreen(vault: vault, difficulty: Difficulty.easy),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('are 2 photos'), findsOneWidget);
      expect(find.textContaining('needs at least 3'), findsOneWidget);
      expect(find.text('Start playing'), findsNothing);
    });

    testWidgets('with four photos it offers them, pre-ticked, and can start', (
      tester,
    ) async {
      _phoneSized(tester);
      final vault = await _vaultWith(4);

      await tester.pumpWidget(
        _host(
          FamilyMatchSetupScreen(vault: vault, difficulty: Difficulty.easy),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Photo 1'), findsOneWidget);
      expect(find.text('Photo 4'), findsOneWidget);
      expect(find.text('4 chosen — 4 pairs to find'), findsOneWidget);
      // The privacy statement is on the screen where the photos are chosen.
      expect(
        find.textContaining('stay on this phone'),
        findsOneWidget,
      );

      // Unticking one keeps it playable; unticking two does not.
      await tester.tap(find.text('Photo 1'));
      await tester.pumpAndSettle();
      expect(find.text('3 chosen — 3 pairs to find'), findsOneWidget);

      await tester.tap(find.text('Photo 2'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Choose at least 3 photos'), findsOneWidget);
    });

    testWidgets('a photo whose file is gone is dropped, not shown broken', (
      tester,
    ) async {
      _phoneSized(tester);
      // Three real photos and two records pointing at files that do not exist.
      final vault = await _vaultWith(3, ghostCount: 2);

      await tester.pumpWidget(
        _host(
          FamilyMatchSetupScreen(vault: vault, difficulty: Difficulty.easy),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Photo 1'), findsOneWidget);
      // The unreadable ones never reach the list.
      expect(find.text('Missing 1'), findsNothing);
      expect(find.text('Missing 2'), findsNothing);
      expect(find.text('3 chosen — 3 pairs to find'), findsOneWidget);
    });

    testWidgets('deleting every photo takes the game back to its empty state', (
      tester,
    ) async {
      _phoneSized(tester);
      // The selection is never stored, so there is no stale list of photo ids
      // to go wrong: a vault whose photos are all gone is simply an empty one.
      final vault = await _vaultWith(3);
      var memories = await vault.loadAll();
      for (final memory in [...memories]) {
        memories = await vault.remove(memories, memory);
      }

      await tester.pumpWidget(
        _host(
          FamilyMatchSetupScreen(vault: vault, difficulty: Difficulty.easy),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('This game needs a few photos first'), findsOneWidget);
    });

    testWidgets('starting the game opens a board of the chosen photos', (
      tester,
    ) async {
      _phoneSized(tester);
      final vault = await _vaultWith(3);

      await tester.pumpWidget(
        _host(
          FamilyMatchSetupScreen(vault: vault, difficulty: Difficulty.easy),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Start playing'));
      await tester.pumpAndSettle();

      expect(find.text('Family Photo Match'), findsWidgets);
      // Three pairs chosen, so six cards — not the four pairs Easy would
      // otherwise deal.
      expect(find.text('?'), findsNWidgets(6));
      expect(find.text('Matches'), findsOneWidget);
    });
  });

  group('progress', () {
    GameResult result({
      required bool completed,
      GameType gameType = GameType.memoryMatch,
      String? packId,
      int day = 1,
    }) => GameResult(
      gameType: gameType,
      difficulty: Difficulty.easy,
      score: 200,
      durationSeconds: 65,
      completed: completed,
      mistakes: 1,
      correct: 4,
      packId: packId,
      playedAt: DateTime(2026, 4, day),
    );

    testWidgets('with nothing played it says so', (tester) async {
      _phoneSized(tester);
      await tester.pumpWidget(_host(const PlayerProgressScreen(history: [])));
      await tester.pumpAndSettle();

      expect(find.text('Nothing here yet'), findsOneWidget);
    });

    testWidgets('finished and started games are kept apart', (tester) async {
      _phoneSized(tester);
      await tester.pumpWidget(
        _host(
          PlayerProgressScreen(
            history: [
              result(completed: true, packId: 'assam_bihu_v1'),
              result(
                completed: true,
                gameType: GameType.oddOneOut,
                day: 2,
              ),
              result(completed: false, day: 3),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Games you finished'), findsOneWidget);
      expect(find.text('Games you started'), findsOneWidget);
      // Two finished, of two different games.
      expect(find.text('2'), findsNWidgets(2));
      expect(find.text('games finished'), findsOneWidget);
      expect(find.text('different games'), findsOneWidget);
      // The pack played is named.
      expect(
        find.textContaining('Assam: Bihu and everyday things'),
        findsOneWidget,
      );
    });

    testWidgets('it shows facts, and no interpretation of them', (
      tester,
    ) async {
      _phoneSized(tester);
      await tester.pumpWidget(
        _host(PlayerProgressScreen(history: [result(completed: true)])),
      );
      await tester.pumpAndSettle();

      expect(find.text('Right: 4'), findsOneWidget);
      expect(find.text('Tries that missed: 1'), findsOneWidget);

      // Nothing medical, nothing diagnostic, no trend. These words must never
      // appear on a screen built from game scores.
      for (final forbidden in [
        'dementia',
        'decline',
        'improving',
        'worsening',
        'stage',
        'assessment',
        'diagnos',
      ]) {
        expect(
          find.textContaining(forbidden, findRichText: true),
          findsNothing,
          reason: forbidden,
        );
      }
    });
  });

  group('large text does not break the game layouts', () {
    // The users this app is for are the ones most likely to have the system
    // font size turned up. A RenderFlex overflow throws in a test, so
    // takeException() catching nothing is the actual assertion here.
    for (final scale in [1.5, 2.0]) {
      testWidgets('Cultural Memory Match at ${scale}x', (tester) async {
        _phoneSized(tester);
        await tester.pumpWidget(
          _hostAtTextScale(
            MemoryMatchScreen(
              difficulty: Difficulty.hard,
              pool: matchTilesFor(kAssamBihuPack),
              packId: kAssamBihuPack.id,
              title: 'Cultural Memory Match',
              factsAreUnchecked: true,
            ),
            scale,
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('?'), findsNWidgets(16));
      });

      testWidgets('Story Order at ${scale}x', (tester) async {
        _phoneSized(tester);
        await tester.pumpWidget(
          _hostAtTextScale(
            StorySequenceScreen(
              difficulty: Difficulty.hard,
              pack: kAssamBihuPack,
            ),
            scale,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        await tester.tap(find.text('I am ready'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('0 of 5 in place'), findsOneWidget);
      });

      testWidgets('Cultural Odd-One-Out at ${scale}x', (tester) async {
        _phoneSized(tester);
        await tester.pumpWidget(
          _hostAtTextScale(
            OddOneOutScreen(
              difficulty: Difficulty.hard,
              deck: deckFor(kAssamBihuPack),
            ),
            scale,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });

      testWidgets('progress at ${scale}x', (tester) async {
        _phoneSized(tester);
        await tester.pumpWidget(
          _hostAtTextScale(
            PlayerProgressScreen(
              history: [
                GameResult(
                  gameType: GameType.folkStorySequence,
                  difficulty: Difficulty.hard,
                  score: 420,
                  durationSeconds: 130,
                  completed: true,
                  mistakes: 2,
                  correct: 5,
                  hintsUsed: 1,
                  packId: 'assam_bihu_v1',
                  playedAt: DateTime(2026, 4, 2),
                ),
              ],
            ),
            scale,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('the games need nothing but the device', () {
    testWidgets('every cultural game opens with no services at all', (
      tester,
    ) async {
      // No AiService, no CareSyncService, no VoiceController, no storage and no
      // network client is passed to any of these. If a bundled game ever grew a
      // dependency on the gateway, this test would stop compiling or throw —
      // which is the point of writing it this way rather than mocking a client.
      _phoneSized(tester);

      for (final screen in <Widget>[
        MemoryMatchScreen(
          difficulty: Difficulty.easy,
          pool: matchTilesFor(kAssamBihuPack),
          packId: kAssamBihuPack.id,
        ),
        OddOneOutScreen(
          difficulty: Difficulty.easy,
          deck: deckFor(kAssamBihuPack),
        ),
        StorySequenceScreen(
          difficulty: Difficulty.easy,
          pack: kAssamBihuPack,
        ),
      ]) {
        await tester.pumpWidget(_host(screen));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('no Listen button appears when there is no voice', (
      tester,
    ) async {
      _phoneSized(tester);
      await tester.pumpWidget(
        _host(
          MemoryMatchScreen(
            difficulty: Difficulty.easy,
            pool: matchTilesFor(kAssamBihuPack),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // A button that silently does nothing is worse than no button. The
      // instructions are still there in writing.
      expect(find.text('Read this to me'), findsNothing);
      expect(find.textContaining('Tap a card to turn it over'), findsOneWidget);
    });
  });

  group('the sound setting actually does something', () {
    /// Records the haptic calls the app makes, so the test can tell the
    /// difference between "sounds are on" and "the switch is decorative".
    ///
    /// **Only haptics, deliberately.** Flutter's own InkWell plays
    /// `SystemSound.play` on every tap through `Feedback.forTap`, so counting
    /// clicks would count the framework's taps as well as ours and prove
    /// nothing. `HapticFeedback.vibrate` on a plain tap comes only from
    /// GameFeedback, so it is the signal that is actually attributable.
    List<String> watchHaptics() {
      final calls = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'HapticFeedback.vibrate') calls.add(call.method);
        return null;
      });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );
      return calls;
    }

    /// Taps two cards that are not a pair, which is the mismatch path.
    Future<void> tapAMismatch(WidgetTester tester) async {
      await tester.tap(find.text('?').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('?').first);
      await tester.pump();
    }

    testWidgets('with sounds on, the platform is asked to click and buzz', (
      tester,
    ) async {
      _phoneSized(tester);
      final calls = watchHaptics();

      await tester.pumpWidget(
        _host(
          StorySequenceScreen(
            difficulty: Difficulty.easy,
            pack: kAssamBihuPack,
            settings: const GameSettings(soundOn: true),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('I am ready'));
      await tester.pumpAndSettle();

      // A wrong tap, then a right one.
      await tester.tap(find.text('The hot tea is poured out to drink.'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('The youngest leaves are picked in the garden.'));
      await tester.pumpAndSettle();

      // One buzz for the wrong tap, one for the right one.
      expect(calls, hasLength(2));
    });

    testWidgets('with sounds off, the platform is not asked at all', (
      tester,
    ) async {
      _phoneSized(tester);
      final calls = watchHaptics();

      await tester.pumpWidget(
        _host(
          StorySequenceScreen(
            difficulty: Difficulty.easy,
            pack: kAssamBihuPack,
            settings: const GameSettings(soundOn: false),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('I am ready'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('The hot tea is poured out to drink.'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('The youngest leaves are picked in the garden.'));
      await tester.pumpAndSettle();

      // The game still plays; it simply makes no noise.
      expect(find.text('1 of 3 in place'), findsOneWidget);
      expect(calls, isEmpty);
    });

    testWidgets('Memory Match is quiet with sounds off too', (tester) async {
      _phoneSized(tester);
      final calls = watchHaptics();

      await tester.pumpWidget(
        _host(
          MemoryMatchScreen(
            difficulty: Difficulty.easy,
            pool: matchTilesFor(kAssamBihuPack),
            settings: const GameSettings(soundOn: false),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tapAMismatch(tester);

      expect(calls, isEmpty);
    });

    testWidgets('Memory Match buzzes on a mismatch when sounds are on', (
      tester,
    ) async {
      _phoneSized(tester);
      final calls = watchHaptics();

      await tester.pumpWidget(
        _host(
          MemoryMatchScreen(
            difficulty: Difficulty.easy,
            pool: matchTilesFor(kAssamBihuPack),
            settings: const GameSettings(soundOn: true),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tapAMismatch(tester);

      expect(calls, hasLength(1));
    });

    testWidgets('reduced motion still plays the game', (tester) async {
      _phoneSized(tester);
      await tester.pumpWidget(
        _host(
          MemoryMatchScreen(
            difficulty: Difficulty.easy,
            pool: matchTilesFor(kAssamBihuPack),
            settings: const GameSettings(reducedMotion: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('?').first);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('?'), findsNWidgets(7));
    });
  });

  group('a game can be finished, restarted and left', () {
    /// Plays a Memory Match board to completion by turning cards over until
    /// every pair is found.
    ///
    /// It pairs cards at random rather than cheating with a seed, because the
    /// screen owns its own Random — which is the honest thing for it to do, and
    /// means the test drives the game exactly as a player does. A face-down card
    /// shows "?", so "no ? left" is precisely "the board is complete".
    Future<void> playToCompletion(WidgetTester tester) async {
      // The second card is chosen by a rotating offset, not always the next one
      // along. Always taking the first two hidden cards retries the SAME pair
      // for ever when they do not match, and the board never finishes — which
      // is exactly what the first version of this helper did.
      var offset = 0;

      for (var guard = 0; guard < 400; guard++) {
        final hidden = find.text('?');
        if (hidden.evaluate().isEmpty) return;

        await tester.tap(hidden.first);
        await tester.pump();

        final rest = find.text('?');
        final count = rest.evaluate().length;
        if (count == 0) {
          // The last pair: let the match register.
          await tester.pump(const Duration(milliseconds: 1600));
          return;
        }

        offset = (offset + 1) % count;
        await tester.tap(rest.at(offset));
        // Long enough to cover the mismatch pause, so the two wrong cards turn
        // back over before the next attempt.
        await tester.pump(const Duration(milliseconds: 1600));
      }
      fail('the board did not finish within 400 attempts');
    }

    testWidgets('finishing shows the result, and Play again deals a new board', (
      tester,
    ) async {
      _phoneSized(tester);
      await tester.pumpWidget(
        _host(
          MemoryMatchScreen(
            difficulty: Difficulty.easy,
            pool: matchTilesFor(kAssamBihuPack),
            packId: kAssamBihuPack.id,
            title: 'Cultural Memory Match',
          ),
        ),
      );
      await tester.pumpAndSettle();

      await playToCompletion(tester);
      await tester.pumpAndSettle();

      // Never "Game over" and never "You lose".
      expect(find.text('All pairs found!'), findsWidgets);
      expect(find.text('Play again'), findsOneWidget);
      expect(find.text('Back to games'), findsOneWidget);
      expect(find.textContaining('Game over'), findsNothing);

      await tester.tap(find.text('Play again'));
      await tester.pumpAndSettle();

      // A fresh board of eight face-down cards.
      expect(find.text('?'), findsNWidgets(8));
      expect(find.text('All pairs found!'), findsNothing);
    });

    testWidgets('a finished game is reported as completed', (tester) async {
      _phoneSized(tester);
      GameResult? popped;

      await tester.pumpWidget(
        _host(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                popped = await Navigator.of(context).push<GameResult>(
                  MaterialPageRoute(
                    builder: (_) => MemoryMatchScreen(
                      difficulty: Difficulty.easy,
                      pool: matchTilesFor(kAssamBihuPack),
                      packId: kAssamBihuPack.id,
                    ),
                  ),
                );
              },
              child: const Text('go'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      await playToCompletion(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Back to games'));
      await tester.pumpAndSettle();

      expect(popped, isNotNull);
      expect(popped!.completed, isTrue);
      expect(popped!.correct, 4);
      expect(popped!.packId, kAssamBihuPack.id);
      expect(popped!.gameType, GameType.memoryMatch);
    });

    testWidgets('Story Order restarts from the pause overlay', (tester) async {
      _phoneSized(tester);
      await tester.pumpWidget(
        _host(
          StorySequenceScreen(
            difficulty: Difficulty.easy,
            pack: kAssamBihuPack,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('I am ready'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('The youngest leaves are picked in the garden.'));
      await tester.pumpAndSettle();
      expect(find.text('1 of 3 in place'), findsOneWidget);

      await tester.tap(find.text('Pause'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start again'));
      await tester.pumpAndSettle();

      // Start again means a whole new game, so it begins at the story once more.
      expect(find.text('Tea in the morning'), findsOneWidget);
      expect(find.text('I am ready'), findsOneWidget);
    });

    testWidgets('Cultural Odd-One-Out plays five rounds to a result', (
      tester,
    ) async {
      _phoneSized(tester);
      await tester.pumpWidget(
        _host(
          OddOneOutScreen(
            difficulty: Difficulty.easy,
            deck: deckFor(kAssamBihuPack),
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (var round = 1; round <= 5; round++) {
        expect(find.textContaining('$round / 5'), findsOneWidget);
        // Tap a tile on the board specifically — the screen has other InkWells
        // (Pause, the hint button), and picking one of those would answer
        // nothing.
        final tiles = find.descendant(
          of: find.byType(GridView),
          matching: find.byType(InkWell),
        );
        await tester.tap(tiles.first);
        await tester.pumpAndSettle();
        expect(find.textContaining('The answer was'), findsOneWidget);

        await tester.tap(
          round == 5 ? find.text('See result') : find.text('Next question'),
        );
        await tester.pumpAndSettle();
      }

      expect(find.text('Play again'), findsWidgets);
    });
  });
}
