import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindpal/l10n/app_language.dart';
import 'package:mindpal/l10n/app_strings.dart';
import 'package:mindpal/l10n/language_scope.dart';
import 'package:mindpal/models/difficulty.dart';
import 'package:mindpal/models/game_result.dart';
import 'package:mindpal/models/game_settings.dart';
import 'package:mindpal/models/game_type.dart';
import 'package:mindpal/screens/mindpal_screen.dart';
import 'package:mindpal/services/ai_service.dart';
import 'package:mindpal/services/game_history_service.dart';
import 'package:mindpal/services/memory_aid_service.dart';
import 'package:mindpal/services/memory_vault_service.dart';
import 'package:mindpal/storage/local_storage.dart';
import 'package:mindpal/storage/media/media_store.dart';

/// The game hub, on its own.
///
/// It is the screen the whole app now points at, so it is worth testing without
/// the rest of MainShell around it.
Future<void> _pumpHub(
  WidgetTester tester, {
  List<GameResult> history = const [],
  GameSettings settings = GameSettings.defaults,
  ValueChanged<GameSettings>? onSettingsChanged,
}) async {
  tester.view.physicalSize = const Size(430, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final storage = InMemoryStorage();
  await storage.init();

  await tester.pumpWidget(
    LanguageScope(
      strings: AppStrings.forLanguage(kAppLanguages.first),
      onLanguageChanged: (_) {},
      child: MaterialApp(
        home: Scaffold(
          body: MindPalScreen(
            onGameFinished: (_) async {},
            memoryAidService: MemoryAidService(storage),
            memoryVaultService: MemoryVaultService(
              storage,
              media: InMemoryMediaStore(),
            ),
            onOpenMemoryAid: () {},
            aiService: const DeterministicAiService(),
            gameHistory: history,
            settings: settings,
            onSettingsChanged: onSettingsChanged ?? (_) {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

GameResult _session({
  bool completed = true,
  int mistakes = 0,
  GameType gameType = GameType.memoryMatch,
  Difficulty difficulty = Difficulty.easy,
  int daysAgo = 0,
}) => GameResult(
  gameType: gameType,
  difficulty: difficulty,
  score: 300,
  durationSeconds: 70,
  completed: completed,
  mistakes: mistakes,
  correct: 4,
  packId: 'assam_bihu_v1',
  playedAt: DateTime.now().subtract(Duration(days: daysAgo)),
);

void main() {
  testWidgets('the hub leads with the positioning and the games', (
    tester,
  ) async {
    await _pumpHub(tester);

    expect(find.text('Play, Remember, Connect'), findsOneWidget);
    expect(find.text('Games from your region'), findsOneWidget);
    expect(find.text('Cultural Memory Match'), findsWidgets);
    expect(find.text('Story Order'), findsWidgets);
    expect(find.text('Cultural Odd-One-Out'), findsWidgets);
  });

  testWidgets('the pack selector names one pack and admits the rest are absent', (
    tester,
  ) async {
    await _pumpHub(tester);

    expect(find.text('Cultural pack'), findsOneWidget);
    expect(find.text('Assam: Bihu and everyday things'), findsOneWidget);
    expect(find.text('Assam, North-East India'), findsOneWidget);
    // The pack says on the selector that nobody has checked it.
    expect(find.text('Facts not checked yet'), findsOneWidget);
    // And the selector states plainly what is NOT here, instead of showing
    // greyed-out buttons for regions with no content.
    expect(find.textContaining('Only Assam is available so far'), findsOneWidget);
  });

  testWidgets('with nothing played there is no Continue playing card', (
    tester,
  ) async {
    await _pumpHub(tester);
    expect(find.text('Continue playing'), findsNothing);
  });

  testWidgets('after a game, Continue playing offers that same game', (
    tester,
  ) async {
    await _pumpHub(
      tester,
      history: [_session(gameType: GameType.folkStorySequence)],
    );

    expect(find.text('Continue playing'), findsOneWidget);
    expect(find.text('Play Story Order again'), findsOneWidget);
  });

  testWidgets('no difficulty is suggested after a single game', (tester) async {
    await _pumpHub(tester, history: [_session()]);

    expect(find.textContaining('Would you like to try'), findsNothing);
  });

  testWidgets('three comfortable games offer a harder level, as an offer', (
    tester,
  ) async {
    await _pumpHub(
      tester,
      history: [
        _session(daysAgo: 0),
        _session(daysAgo: 1),
        _session(daysAgo: 2),
      ],
    );

    expect(find.textContaining('went smoothly'), findsOneWidget);
    // An offer, with a way to decline that sticks.
    expect(find.text('Try Medium'), findsOneWidget);
    expect(find.text('No thank you'), findsOneWidget);
  });

  testWidgets('accepting the offer changes the level and nothing else', (
    tester,
  ) async {
    GameSettings? saved;
    await _pumpHub(
      tester,
      history: [
        _session(daysAgo: 0),
        _session(daysAgo: 1),
        _session(daysAgo: 2),
      ],
      onSettingsChanged: (settings) => saved = settings,
    );

    await tester.tap(find.text('Try Medium'));
    await tester.pumpAndSettle();

    expect(saved?.difficulty, Difficulty.medium);
    // Declining suggestions is a separate choice and must not be set by
    // accepting one.
    expect(saved?.acceptDifficultySuggestions, isTrue);
  });

  testWidgets('declining turns the suggestions off', (tester) async {
    GameSettings? saved;
    await _pumpHub(
      tester,
      history: [
        _session(daysAgo: 0),
        _session(daysAgo: 1),
        _session(daysAgo: 2),
      ],
      onSettingsChanged: (settings) => saved = settings,
    );

    await tester.tap(find.text('No thank you'));
    await tester.pumpAndSettle();

    expect(saved?.acceptDifficultySuggestions, isFalse);
    expect(saved?.difficulty, Difficulty.easy);
  });

  testWidgets('a player who switched suggestions off is never nudged', (
    tester,
  ) async {
    await _pumpHub(
      tester,
      settings: const GameSettings(acceptDifficultySuggestions: false),
      history: [
        _session(daysAgo: 0),
        _session(daysAgo: 1),
        _session(daysAgo: 2),
      ],
    );

    expect(find.textContaining('went smoothly'), findsNothing);
  });

  testWidgets('the accessibility sheet opens and explains each switch', (
    tester,
  ) async {
    await _pumpHub(tester);

    final settingsButton = find.text('Sound, movement and reading aloud');
    await tester.scrollUntilVisible(settingsButton, 300, maxScrolls: 30);
    // It is the last thing in the list, so scrollUntilVisible can stop with it
    // only part way onto the screen — and a tap aimed outside the viewport
    // silently hits nothing.
    await tester.ensureVisible(settingsButton);
    await tester.pumpAndSettle();
    await tester.tap(settingsButton);
    await tester.pumpAndSettle();

    expect(find.text('How games behave'), findsOneWidget);
    expect(find.text('Sounds and buzzes'), findsOneWidget);
    expect(find.text('Less movement'), findsOneWidget);
    expect(find.text('Read instructions aloud'), findsOneWidget);
    // With no voice controller, the switch is shown as unavailable WITH the
    // reason, rather than hidden or dead.
    expect(
      find.textContaining('no voice installed'),
      findsOneWidget,
    );
    expect(
      find.textContaining('never changes the level on its own'),
      findsOneWidget,
    );
  });

  testWidgets('the progress screen opens from the hub', (tester) async {
    await _pumpHub(tester, history: [_session()]);

    await tester.scrollUntilVisible(
      find.text('Your progress'),
      300,
      maxScrolls: 30,
    );
    await tester.tap(find.text('Your progress'));
    await tester.pumpAndSettle();

    expect(find.text('Games you finished'), findsOneWidget);
  });

  testWidgets('Story Order starts from the hub with the pack story', (
    tester,
  ) async {
    await _pumpHub(tester);

    await tester.scrollUntilVisible(
      find.text('Play Story Order'),
      300,
      maxScrolls: 30,
    );
    await tester.tap(find.text('Play Story Order'));
    await tester.pumpAndSettle();

    // Easy wants three scenes, and the Assam pack has a three-scene story.
    expect(find.text('Tea in the morning'), findsOneWidget);
  });

  testWidgets('Cultural Memory Match starts from the hub', (tester) async {
    await _pumpHub(tester);

    await tester.scrollUntilVisible(
      find.text('Play Cultural Memory Match'),
      300,
      maxScrolls: 30,
    );
    await tester.tap(find.text('Play Cultural Memory Match'));
    await tester.pumpAndSettle();

    expect(find.text('?'), findsNWidgets(8));
  });

  testWidgets('the original Sequence Recall is still offered', (tester) async {
    await _pumpHub(tester);

    // The brief said to keep it if useful. It is a different kind of exercise
    // from Story Order, so it stays — under its own heading, not pretending to
    // be cultural content.
    await tester.scrollUntilVisible(
      find.text('Other games'),
      300,
      maxScrolls: 30,
    );
    expect(find.text('Sequence Recall'), findsOneWidget);
  });

  group('progress survives a restart', () {
    test('a recorded game reads back with its pack and counts', () async {
      final storage = InMemoryStorage();
      await storage.init();

      final saved = await GameHistoryService(storage).record(const [], _session(
        gameType: GameType.folkStorySequence,
      ));
      expect(saved, hasLength(1));

      // A fresh service over the same storage is what a relaunch does.
      final afterRestart = await GameHistoryService(storage).loadAll();

      expect(afterRestart, hasLength(1));
      expect(afterRestart.single.gameType, GameType.folkStorySequence);
      expect(afterRestart.single.packId, 'assam_bihu_v1');
      expect(afterRestart.single.correct, 4);
      expect(afterRestart.single.completed, isTrue);
      expect(afterRestart.single.id, greaterThan(0));
    });

    test('several games keep their own packs and game types', () async {
      final storage = InMemoryStorage();
      await storage.init();
      final service = GameHistoryService(storage);

      var history = await service.record(const [], _session());
      history = await service.record(
        history,
        _session(gameType: GameType.familyPhotoMatch, completed: false),
      );
      history = await service.record(
        history,
        _session(gameType: GameType.oddOneOut, mistakes: 3),
      );

      final afterRestart = await GameHistoryService(storage).loadAll();
      expect(afterRestart, hasLength(3));
      expect(
        afterRestart.map((result) => result.gameType).toSet(),
        {
          GameType.memoryMatch,
          GameType.familyPhotoMatch,
          GameType.oddOneOut,
        },
      );
      expect(
        afterRestart.where((result) => !result.completed).single.gameType,
        GameType.familyPhotoMatch,
      );
    });
  });
}
