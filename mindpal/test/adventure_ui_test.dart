import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindpal/adventure/content/pongal_adventure.dart';
import 'package:mindpal/adventure/engine/adventure_engine.dart';
import 'package:mindpal/adventure/engine/adventure_state.dart';
import 'package:mindpal/adventure/storage/adventure_store.dart';
import 'package:mindpal/adventure/ui/adventure_home_screen.dart';
import 'package:mindpal/adventure/ui/adventure_screen.dart';
import 'package:mindpal/l10n/app_language.dart';
import 'package:mindpal/l10n/app_strings.dart';
import 'package:mindpal/l10n/language_scope.dart';
import 'package:mindpal/storage/local_storage.dart';

/// Festival Quest, driven through its screens.
///
/// The engine tests prove the rules; these prove the rules reach the player —
/// that a tap on a person opens a conversation, that the market shows what it
/// refuses and why, and that finishing writes the run down.
Widget _host(Widget child) => LanguageScope(
  strings: AppStrings.forLanguage(kAppLanguages.first),
  onLanguageChanged: (_) {},
  child: MaterialApp(home: child),
);

void _phoneSized(WidgetTester tester) {
  tester.view.physicalSize = const Size(430, 1500);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<AdventureStore> _store() async {
  final storage = InMemoryStorage();
  await storage.init();
  return AdventureStore(storage);
}

/// Scrolls the open bottom sheet until [finder] is visible.
///
/// A sheet's list is the last Scrollable on screen, and `scrollUntilVisible`
/// needs telling which one to drive when more than one exists.
Future<void> _scrollSheetTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find.byType(Scrollable).last,
    maxScrolls: 30,
  );
  await tester.pumpAndSettle();
}

void main() {
  final engine = AdventureEngine(kPongalAdventure);

  group('the scene', () {
    testWidgets('shows where you are and who is there', (tester) async {
      _phoneSized(tester);
      final store = await _store();

      await tester.pumpWidget(
        _host(AdventureScreen(adventure: kPongalAdventure, store: store)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Village square'), findsOneWidget);
      // People and things are named in the picture, never left as bare icons.
      expect(find.text('Ammal'), findsOneWidget);
      expect(find.text('Murugan'), findsOneWidget);
      expect(find.text('The well'), findsOneWidget);
      expect(find.text('To the market'), findsOneWidget);

      // The coins are always on screen.
      expect(find.text('26'), findsOneWidget);
      // And so is what to do next.
      expect(find.text('Ask Ammal what she needs'), findsOneWidget);
    });

    testWidgets('walking somewhere changes the scene', (tester) async {
      _phoneSized(tester);
      final store = await _store();

      await tester.pumpWidget(
        _host(AdventureScreen(adventure: kPongalAdventure, store: store)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('To the market'));
      await tester.pumpAndSettle();

      expect(find.text('Market'), findsWidgets);
      expect(find.text('Kannan'), findsOneWidget);
      expect(find.text('The stalls'), findsOneWidget);
      // And the way back is right there.
      expect(find.text('Back to the square'), findsOneWidget);
    });

    testWidgets('an object that is not yet relevant is simply absent', (
      tester,
    ) async {
      _phoneSized(tester);
      final store = await _store();

      await tester.pumpWidget(
        _host(
          AdventureScreen(
            adventure: kPongalAdventure,
            store: store,
            resumeFrom: engine.newGame().copyWith(locationId: 'market'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('A stack of boards'), findsNothing);
    });
  });

  group('talking', () {
    testWidgets('a tap opens a panel that says who is speaking', (
      tester,
    ) async {
      _phoneSized(tester);
      final store = await _store();

      await tester.pumpWidget(
        _host(AdventureScreen(adventure: kPongalAdventure, store: store)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ammal'));
      await tester.pumpAndSettle();

      // The name AND who they are, every time, so nobody has to remember.
      expect(find.text('Ammal'), findsWidgets);
      expect(find.text('She is cooking the pongal'), findsOneWidget);
      expect(find.textContaining('Another pair of hands'), findsOneWidget);
      // One line at a time, never a wall of text.
      expect(find.text('Go on'), findsOneWidget);
    });

    testWidgets('replies appear only after the speaker has finished', (
      tester,
    ) async {
      _phoneSized(tester);
      final store = await _store();

      await tester.pumpWidget(
        _host(AdventureScreen(adventure: kPongalAdventure, store: store)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ammal'));
      await tester.pumpAndSettle();
      expect(find.textContaining('What do you need?'), findsNothing);

      await tester.tap(find.text('Go on'));
      await tester.pumpAndSettle();
      expect(find.textContaining('What do you need?'), findsOneWidget);
    });

    testWidgets('accepting the errand starts the shopping', (tester) async {
      _phoneSized(tester);
      final store = await _store();

      await tester.pumpWidget(
        _host(AdventureScreen(adventure: kPongalAdventure, store: store)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ammal'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Go on'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('What do you need?'));
      await tester.pumpAndSettle();

      // She reads out the list, and the journal has moved on.
      expect(find.textContaining('A pot big enough'), findsOneWidget);
      expect(store.progressFor(kPongalAdventure.id)!.flags,
          contains('has_list'));
    });

    testWidgets('a conversation can be left at any point', (tester) async {
      _phoneSized(tester);
      final store = await _store();

      await tester.pumpWidget(
        _host(AdventureScreen(adventure: kPongalAdventure, store: store)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ammal'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Stop talking'));
      await tester.pumpAndSettle();

      expect(find.text('Go on'), findsNothing);
      expect(find.text('The well'), findsOneWidget);
    });
  });

  group('the market', () {
    Future<void> openMarket(WidgetTester tester, AdventureStore store) async {
      await tester.pumpWidget(
        _host(
          AdventureScreen(
            adventure: kPongalAdventure,
            store: store,
            resumeFrom: engine.newGame().copyWith(
              locationId: 'market',
              flags: {'has_list', 'been_market'},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('The stalls'));
      await tester.pumpAndSettle();
    }

    testWidgets('it is a shop, with goods, prices and a list', (tester) async {
      _phoneSized(tester);
      await openMarket(tester, await _store());

      expect(find.text('The market'), findsOneWidget);
      expect(find.text('You have 26 coins'), findsOneWidget);
      expect(find.textContaining('Kannan'), findsWidgets);
      expect(find.text('Clay pot'), findsOneWidget);
      expect(find.text('6 coins'), findsWidgets);
      // Relaxed play keeps the list on show.
      expect(find.text('Ammal asked for:'), findsOneWidget);
      expect(find.text('New rice from this harvest'), findsOneWidget);
    });

    testWidgets('the sold-out thing says so on its own row', (tester) async {
      _phoneSized(tester);
      await openMarket(tester, await _store());

      await tester.scrollUntilVisible(find.text('Jaggery'), 200,
          maxScrolls: 20);
      await tester.pumpAndSettle();

      expect(find.text('Jaggery'), findsOneWidget);
      expect(find.text('Sold out'), findsOneWidget);
      // The alternative is right beside it, at its own price.
      expect(find.text('Palm sugar'), findsOneWidget);
    });

    testWidgets('buying takes the coins and fills a line of the list', (
      tester,
    ) async {
      _phoneSized(tester);
      final store = await _store();
      await openMarket(tester, store);

      await tester.tap(find.text('6 coins').first);
      await tester.pumpAndSettle();

      expect(find.text('You have 20 coins'), findsOneWidget);
      expect(store.progressFor(kPongalAdventure.id)!.hasItem('clay_pot'),
          isTrue);
      // The row now says it is already bought rather than offering it again.
      expect(find.text('Already in your basket'), findsOneWidget);
    });

    testWidgets('standard pace folds the list away, same goods', (
      tester,
    ) async {
      _phoneSized(tester);
      final store = await _store();

      await tester.pumpWidget(
        _host(
          AdventureScreen(
            adventure: kPongalAdventure,
            store: store,
            pace: AdventurePace.standard,
            resumeFrom: engine.newGame().copyWith(
              locationId: 'market',
              flags: {'has_list'},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('The stalls'));
      await tester.pumpAndSettle();

      expect(find.text('Ammal asked for:'), findsNothing);
      // The shop itself is identical: guidance changes, the game does not.
      expect(find.text('Clay pot'), findsOneWidget);
      expect(find.text('You have 26 coins'), findsOneWidget);
    });
  });

  group('the journal', () {
    testWidgets('holds the objective, the steps and the clues', (
      tester,
    ) async {
      _phoneSized(tester);
      final store = await _store();

      await tester.pumpWidget(
        _host(
          AdventureScreen(
            adventure: kPongalAdventure,
            store: store,
            resumeFrom: engine.newGame().copyWith(
              flags: {'has_list', 'heard_about_stencil'},
              clues: {'clue_basket'},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Journal'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Help Ammal and the village'), findsOneWidget);
      expect(find.text('Buy everything on the list'), findsWidgets);
      expect(find.text('Find the missing kolam stencil'), findsWidgets);
      // Important conversations are readable again, not heard once and gone.
      expect(find.text('What you have noticed'), findsOneWidget);
      expect(find.textContaining('flower basket'), findsWidgets);
      expect(find.text('Told by Selvi'), findsOneWidget);
    });

    testWidgets('a hint is always offered and never costs anything', (
      tester,
    ) async {
      _phoneSized(tester);
      final store = await _store();

      await tester.pumpWidget(
        _host(AdventureScreen(adventure: kPongalAdventure, store: store)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Hint'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Ammal is the woman'), findsOneWidget);
      final state = store.progressFor(kPongalAdventure.id)!;
      expect(state.hintsUsed, 1);
      expect(state.coins, 26, reason: 'a hint costs nothing');
    });
  });

  group('the mystery', () {
    testWidgets('a wrong answer is a nudge, and the screen stays open', (
      tester,
    ) async {
      _phoneSized(tester);
      final store = await _store();

      await tester.pumpWidget(
        _host(
          AdventureScreen(
            adventure: kPongalAdventure,
            store: store,
            resumeFrom: engine.newGame().copyWith(
              locationId: 'courtyard',
              clues: {'clue_basket', 'clue_dawn', 'clue_board'},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Say where the stencil went'));
      await tester.pumpAndSettle();

      expect(find.text('Where did the kolam stencil go?'), findsWidgets);

      // Name the wrong place, with a reason.
      await tester.tap(find.text('Village square'));
      await tester.pumpAndSettle();
      await _scrollSheetTo(tester, find.textContaining('packed the stencil'));
      await tester.tap(find.textContaining('packed the stencil'));
      await tester.pumpAndSettle();
      await _scrollSheetTo(tester, find.text('Say what you think'));
      await tester.tap(find.text('Say what you think'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Nothing there fits'), findsOneWidget);
      // And the screen says so before you try, not only afterwards.
      await _scrollSheetTo(
        tester,
        find.textContaining('If you are wrong, nothing is lost'),
      );
      expect(
        find.textContaining('If you are wrong, nothing is lost'),
        findsOneWidget,
      );
      expect(store.progressFor(kPongalAdventure.id)!.flags,
          isNot(contains('mystery_solved')));
    });

    testWidgets('the right place with the reasons finds the stencil', (
      tester,
    ) async {
      _phoneSized(tester);
      final store = await _store();

      await tester.pumpWidget(
        _host(
          AdventureScreen(
            adventure: kPongalAdventure,
            store: store,
            resumeFrom: engine.newGame().copyWith(
              locationId: 'courtyard',
              clues: {'clue_basket', 'clue_dawn', 'clue_board'},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Say where the stencil went'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Market'));
      await tester.pumpAndSettle();
      for (final clue in [
        'packed the stencil',
        'before it was light',
        'made of wood',
      ]) {
        await _scrollSheetTo(tester, find.textContaining(clue));
        await tester.tap(find.textContaining(clue));
        await tester.pumpAndSettle();
      }
      await _scrollSheetTo(tester, find.text('Say what you think'));
      await tester.tap(find.text('Say what you think'));
      await tester.pumpAndSettle();

      final state = store.progressFor(kPongalAdventure.id)!;
      expect(state.flags, contains('mystery_solved'));
      expect(state.hasItem('stencil'), isTrue);
    });
  });

  group('getting ready and finishing', () {
    AdventureState almostDone() => engine.newGame().copyWith(
      locationId: 'courtyard',
      inventory: {'clay_pot': 1, 'stencil': 1, 'sugarcane': 1},
      flags: {
        'has_list',
        'market_done',
        'heard_about_stencil',
        'mystery_solved',
        'invited_murugan',
      },
      clues: {'clue_basket', 'clue_dawn', 'clue_board'},
    );

    testWidgets('tap a thing, tap where it goes — no dragging', (
      tester,
    ) async {
      _phoneSized(tester);
      final store = await _store();

      await tester.pumpWidget(
        _host(
          AdventureScreen(
            adventure: kPongalAdventure,
            store: store,
            resumeFrom: almostDone(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Get the courtyard ready').last);
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Tap something you are carrying'),
        findsOneWidget,
      );

      await tester.tap(find.text('Clay pot'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Now tap where it should go'), findsOneWidget);

      await tester.tap(find.text('On the fire'));
      await tester.pumpAndSettle();

      expect(store.progressFor(kPongalAdventure.id)!.placed['slot_fire'],
          'clay_pot');
      expect(find.text('Take out'), findsOneWidget);
    });

    testWidgets('a full courtyard offers the arrangements, none of them wrong',
        (tester) async {
      _phoneSized(tester);
      final store = await _store();

      await tester.pumpWidget(
        _host(
          AdventureScreen(
            adventure: kPongalAdventure,
            store: store,
            resumeFrom: almostDone(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Get the courtyard ready').last);
      await tester.pumpAndSettle();

      for (final (item, slot) in [
        ('Clay pot', 'On the fire'),
        ('Kolam stencil', 'By the doorway'),
        ('Sugarcane', 'Against the pillar'),
      ]) {
        await tester.tap(find.text(item));
        await tester.pumpAndSettle();
        await tester.tap(find.text(slot));
        await tester.pumpAndSettle();
      }

      expect(find.text('How should it look?'), findsOneWidget);
      expect(
        find.textContaining('There is no wrong answer here'),
        findsOneWidget,
      );
      expect(find.text('Plain and bright'), findsOneWidget);
      expect(find.text('Ringed with lamps'), findsOneWidget);
    });

    testWidgets('finishing shows the ending and files the run', (
      tester,
    ) async {
      _phoneSized(tester);
      final store = await _store();

      await tester.pumpWidget(
        _host(
          AdventureScreen(
            adventure: kPongalAdventure,
            store: store,
            resumeFrom: almostDone(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Get the courtyard ready').last);
      await tester.pumpAndSettle();

      for (final (item, slot) in [
        ('Clay pot', 'On the fire'),
        ('Kolam stencil', 'By the doorway'),
        ('Sugarcane', 'Against the pillar'),
      ]) {
        await tester.tap(find.text(item));
        await tester.pumpAndSettle();
        await tester.tap(find.text(slot));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('Full of colour'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Begin the celebration'));
      await tester.pumpAndSettle();

      // The ending the player's decision earned.
      expect(find.text('The whole village came'), findsOneWidget);
      expect(find.textContaining('bells'), findsWidgets);
      expect(find.text('Your adventure'), findsOneWidget);
      expect(find.text('Clues you noticed'), findsOneWidget);
      // Honest on the way out as well as the way in.
      expect(find.textContaining('This story is made up'), findsOneWidget);

      // Filed, and no longer offered as something to continue.
      final runs = store.runs();
      expect(runs, hasLength(1));
      expect(runs.single.endingId, 'ending_together');
      expect(store.current(), isNull);
    });
  });

  group('saving and coming back', () {
    testWidgets('progress is written after every action', (tester) async {
      _phoneSized(tester);
      final store = await _store();

      await tester.pumpWidget(
        _host(AdventureScreen(adventure: kPongalAdventure, store: store)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('To the market'));
      await tester.pumpAndSettle();

      final saved = store.progressFor(kPongalAdventure.id);
      expect(saved, isNotNull);
      expect(saved!.locationId, 'market');
      expect(store.current()!.adventure.id, kPongalAdventure.id);
    });

    testWidgets('the home offers to continue where you left off', (
      tester,
    ) async {
      _phoneSized(tester);
      final store = await _store();
      await store.saveProgress(
        engine.newGame().copyWith(locationId: 'market', flags: {'has_list'}),
      );

      await tester.pumpWidget(
        _host(
          Scaffold(
            body: AdventureHomeScreen(
              store: store,
              onOpenQuickGames: () {},
              onOpenProgress: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Continue Adventure'), findsOneWidget);
      expect(find.textContaining('you are at the market'), findsOneWidget);
    });

    testWidgets('with no backend there is no "make me one" button', (
      tester,
    ) async {
      _phoneSized(tester);
      final store = await _store();

      await tester.pumpWidget(
        _host(
          Scaffold(
            body: AdventureHomeScreen(
              store: store,
              onOpenQuickGames: () {},
              onOpenProgress: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Absent rather than present and broken.
      expect(find.text('Make me a new adventure'), findsNothing);
      // And the bundled adventure is still right there.
      expect(find.text('Start Adventure'), findsOneWidget);
    });
  });
}
