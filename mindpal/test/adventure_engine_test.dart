import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindpal/adventure/content/pongal_adventure.dart';
import 'package:mindpal/adventure/engine/adventure_engine.dart';
import 'package:mindpal/adventure/engine/adventure_state.dart';
import 'package:mindpal/adventure/model/adventure.dart';
import 'package:mindpal/adventure/model/adventure_icons.dart';
import 'package:mindpal/adventure/validation/adventure_solver.dart';
import 'package:mindpal/adventure/validation/adventure_validator.dart';

/// Plays the bundled adventure the way a person would, and checks the rules
/// hold. Everything here is plain Dart — no widgets, no storage, no network.
void main() {
  final adventure = kPongalAdventure;
  final engine = AdventureEngine(adventure);

  group('the bundled adventure is fit to play', () {
    test('it passes every structural check and can be completed', () {
      final report = const AdventureValidator().validate(adventure);

      expect(report.problems, isEmpty, reason: report.toString());
      expect(report.solve, isNotNull);
      expect(report.solve!.isCompletable, isTrue);
      expect(report.solve!.reachableEndings, {
        'ending_together',
        'ending_quiet',
      });
    });

    test('the solver finds a real route, and reports what it did', () {
      final report = const AdventureSolver().solve(adventure);

      expect(report.isCompletable, isTrue);
      expect(report.examplePath, isNotEmpty);
      // Printed so a failure shows the route it actually took.
      // ignore: avoid_print
      print(
        'solver: ${report.statesExplored} positions, '
        'endings ${report.reachableEndings}, '
        'example route of ${report.examplePath.length} actions',
      );
      expect(report.statesExplored, lessThan(80000));
    });

    test('it has the shape Festival Quest asks for', () {
      expect(adventure.locations, hasLength(3));
      expect(adventure.characters, hasLength(4));
      expect(adventure.mystery.clues, hasLength(3));
      expect(adventure.endings, hasLength(2));
      expect(
        adventure.locations.map((place) => place.id),
        containsAll(['square', 'market', 'courtyard']),
      );
    });

    test('the story is labelled as fiction and the note as unchecked', () {
      final note = adventure.culturalNote;
      expect(note.festival, 'Pongal');
      expect(note.reviewed, isFalse);
      expect(note.references.first, contains('invented'));
    });

    test('every character can always say something', () {
      // The rule the validator enforces, checked here against real states too:
      // an empty state and a finished one.
      final fresh = engine.newGame();
      final finished = fresh.copyWith(
        flags: {
          'has_list',
          'market_done',
          'heard_about_stencil',
          'mystery_solved',
          'courtyard_ready',
          'invited_murugan',
        },
      );
      for (final person in adventure.characters) {
        expect(engine.openingNode(fresh, person.id), isNotNull,
            reason: person.name);
        expect(engine.openingNode(finished, person.id), isNotNull,
            reason: person.name);
      }
    });
  });

  group('money and shopping', () {
    AdventureState withList() {
      var state = engine.newGame();
      final node = engine.openingNode(state, 'ammal')!;
      state = engine.enterNode(state, node).state;
      final ask = engine
          .choicesFor(state, node)
          .firstWhere((choice) => choice.id == 'ammal_ask_list');
      return engine.choose(state, ask).state;
    }

    test('the player starts with the coins the story says', () {
      expect(engine.newGame().coins, 26);
      expect(adventure.market.startingCoins, 26);
    });

    test('the cheapest complete basket fits the purse', () {
      // clay pot 6 + rice 4 + palm sugar 6 + milk 3 + cane 3
      expect(engine.cheapestBasketCost(), 22);
      expect(engine.cheapestBasketCost(),
          lessThanOrEqualTo(adventure.market.startingCoins));
    });

    test('buying takes exactly the marked price', () {
      var state = withList();
      final result = engine.buy(state, 'pottery', 'clay_pot');

      expect(result.ok, isTrue);
      expect(result.state.coins, 26 - 6);
      expect(result.state.hasItem('clay_pot'), isTrue);
      expect(result.message, contains('6 coins'));
      state = result.state;

      // and again for something else
      final second = engine.buy(state, 'grain', 'rice');
      expect(second.state.coins, 26 - 6 - 4);
    });

    test('the jaggery is sold out, and says so', () {
      final result = engine.buy(withList(), 'grain', 'jaggery');

      expect(result.ok, isFalse);
      expect(result.state.hasItem('jaggery'), isFalse);
      expect(result.state.coins, 26, reason: 'a refused sale costs nothing');
      expect(result.message, contains('sold out'));
    });

    test('palm sugar is an accepted alternative to the jaggery', () {
      final sweet = adventure.market.requests
          .firstWhere((request) => request.id == 'req_sweet');

      expect(sweet.acceptedItemIds, containsAll(['jaggery', 'palm_sugar']));
      expect(sweet.isSatisfiedBy({'palm_sugar'}), isTrue);
      expect(sweet.isSatisfiedBy({'rice'}), isFalse);
    });

    test('an unaffordable thing is refused with the numbers', () {
      final poor = withList().copyWith(coins: 2);
      final result = engine.buy(poor, 'pottery', 'brass_pot');

      expect(result.ok, isFalse);
      expect(result.message, contains('9 coins'));
      expect(result.message, contains('you have 2'));
    });

    test('you cannot buy a second of something', () {
      var state = engine.buy(withList(), 'grain', 'rice').state;
      final again = engine.buy(state, 'grain', 'rice');

      expect(again.ok, isFalse);
      expect(again.state.coins, state.coins);
      expect(again.state.countOf('rice'), 1);
    });

    test('there is more than one valid basket', () {
      // The clay pot and the brass pot both satisfy the same request, and both
      // leave enough for everything else.
      for (final pot in ['clay_pot', 'brass_pot']) {
        var state = withList();
        for (final (stall, item) in [
          (pot == 'clay_pot' ? 'pottery' : 'pottery', pot),
          ('grain', 'rice'),
          ('grain', 'palm_sugar'),
          ('dairy', 'milk'),
          ('grain', 'sugarcane'),
        ]) {
          final result = engine.buy(state, stall, item);
          expect(result.ok, isTrue, reason: '$pot: $item — ${result.message}');
          state = result.state;
        }
        expect(engine.shoppingComplete(state), isTrue, reason: pot);
        expect(state.coins, greaterThanOrEqualTo(0), reason: pot);
        expect(state.flags, contains('market_done'), reason: pot);
      }
    });

    test('the shopping list is only complete when every line is covered', () {
      var state = withList();
      state = engine.buy(state, 'pottery', 'clay_pot').state;
      state = engine.buy(state, 'grain', 'rice').state;

      final statuses = engine.requestStatuses(state);
      expect(statuses.where((s) => s.isSatisfied), hasLength(2));
      expect(engine.shoppingComplete(state), isFalse);
      expect(state.flags, isNot(contains('market_done')));
    });
  });

  group('the mystery', () {
    AdventureState withAllClues() => engine.newGame().copyWith(
      clues: {'clue_basket', 'clue_dawn', 'clue_board'},
    );

    test('every clue can be discovered somewhere', () {
      // Proved properly by the validator; asserted here as the specific claim.
      final report = const AdventureValidator().validate(adventure);
      expect(report.problems, isEmpty);
      expect(adventure.mystery.clues.map((clue) => clue.id), [
        'clue_basket',
        'clue_dawn',
        'clue_board',
      ]);
    });

    test('the right place with all the reasons solves it', () {
      final result = engine.accuse(
        withAllClues(),
        'market',
        {'clue_basket', 'clue_dawn', 'clue_board'},
      );

      expect(result.ok, isTrue);
      expect(result.state.flags, contains('mystery_solved'));
      expect(result.state.hasItem('stencil'), isTrue);
      expect(result.message, contains('stencil'));
    });

    test('a wrong place is a nudge, never an ending', () {
      final result = engine.accuse(withAllClues(), 'square', {'clue_basket'});

      expect(result.ok, isFalse);
      expect(result.state.isFinished, isFalse);
      expect(result.state.hasItem('stencil'), isFalse);
      expect(result.message, isNotEmpty);
      // Counted, so the summary can mention it. Nothing else reads it.
      expect(result.state.wrongAccusations, 1);
    });

    test('the right place for the wrong reasons is not solving it', () {
      final result = engine.accuse(withAllClues(), 'market', {'clue_basket'});

      expect(result.ok, isFalse);
      expect(result.state.flags, isNot(contains('mystery_solved')));
      expect(result.message, contains('say why'));
    });

    test('noticing more than you needed is not held against you', () {
      final extra = withAllClues();
      final result = engine.accuse(extra, 'market', {
        'clue_basket',
        'clue_dawn',
        'clue_board',
      });
      expect(result.ok, isTrue);
    });

    test('the clues actually support the answer', () {
      // The solution is the market, and all three clues point there: the
      // basket went out, it was seen going to the market, and the board is
      // sitting at the market now.
      expect(adventure.mystery.solutionLocationId, 'market');
      expect(adventure.mystery.supportingClueIds, hasLength(3));
      expect(adventure.clue('clue_dawn')!.text, contains('market'));
      expect(adventure.clue('clue_board')!.text, contains('Kannan'));
    });
  });

  group('getting the courtyard ready', () {
    AdventureState ready() => engine.newGame().copyWith(
      locationId: 'courtyard',
      inventory: {'clay_pot': 1, 'stencil': 1, 'sugarcane': 1},
    );

    test('tap the thing, tap the place', () {
      final result = engine.place(ready(), 'slot_fire', 'clay_pot');

      expect(result.ok, isTrue);
      expect(result.state.placed['slot_fire'], 'clay_pot');
      expect(result.message, contains('fire'));
    });

    test('the wrong place is refused kindly and loses nothing', () {
      final result = engine.place(ready(), 'slot_fire', 'stencil');

      expect(result.ok, isFalse);
      expect(result.state.placed, isEmpty);
      expect(result.state.hasItem('stencil'), isTrue);
      expect(result.message, contains('nothing is lost'));
    });

    test('anything placed can be taken back out again', () {
      var state = engine.place(ready(), 'slot_fire', 'clay_pot').state;
      state = engine.unplace(state, 'slot_fire');

      expect(state.placed, isEmpty);
      expect(state.flags, isNot(contains('courtyard_ready')));
    });

    test('filling every slot makes the courtyard ready', () {
      var state = ready();
      state = engine.place(state, 'slot_fire', 'clay_pot').state;
      state = engine.place(state, 'slot_doorway', 'stencil').state;
      expect(engine.courtyardReady(state), isFalse);

      state = engine.place(state, 'slot_pillar', 'sugarcane').state;
      expect(engine.courtyardReady(state), isTrue);
      expect(state.flags, contains('courtyard_ready'));
    });

    test('no arrangement is ever wrong', () {
      var state = ready();
      for (final style in adventure.preparation.styles) {
        state = engine.chooseStyle(state, style.id);
        expect(state.styleId, style.id);
      }
      // And none of them is referred to by any requirement anywhere, so none
      // can change what the player is allowed to do.
      final styleIds = {
        for (final style in adventure.preparation.styles) style.id,
      };
      for (final ending in adventure.endings) {
        expect(ending.requires.flags.intersection(styleIds), isEmpty);
      }
    });

    test('the celebration waits for the courtyard and a choice', () {
      var state = ready();
      state = engine.place(state, 'slot_fire', 'clay_pot').state;
      state = engine.place(state, 'slot_doorway', 'stencil').state;
      state = engine.place(state, 'slot_pillar', 'sugarcane').state;

      expect(engine.canFinish(state), isFalse, reason: 'no style chosen yet');
      state = engine.chooseStyle(state, 'style_plain');
      expect(engine.canFinish(state), isTrue);
    });
  });

  group('the two endings', () {
    AdventureState finishable({required bool invited}) {
      var state = engine.newGame().copyWith(
        locationId: 'courtyard',
        inventory: {'clay_pot': 1, 'stencil': 1, 'sugarcane': 1},
        flags: invited ? {'invited_murugan'} : {'declined_murugan'},
      );
      state = engine.place(state, 'slot_fire', 'clay_pot').state;
      state = engine.place(state, 'slot_doorway', 'stencil').state;
      state = engine.place(state, 'slot_pillar', 'sugarcane').state;
      return engine.chooseStyle(state, 'style_colour');
    }

    test('inviting Murugan changes how it ends', () {
      final result = engine.finish(finishable(invited: true));

      expect(result.ok, isTrue);
      expect(result.state.endingId, 'ending_together');
      expect(
        adventure.ending('ending_together')!.text,
        contains('bells'),
      );
    });

    test('turning him down still ends well', () {
      final result = engine.finish(finishable(invited: false));

      expect(result.state.endingId, 'ending_quiet');
      // Not a punishment: a different, good day.
      expect(adventure.ending('ending_quiet')!.text, contains('good one'));
    });

    test('never deciding at all still reaches an ending', () {
      var state = engine.newGame().copyWith(
        locationId: 'courtyard',
        inventory: {'brass_pot': 1, 'stencil': 1, 'sugarcane': 1},
      );
      state = engine.place(state, 'slot_fire', 'brass_pot').state;
      state = engine.place(state, 'slot_doorway', 'stencil').state;
      state = engine.place(state, 'slot_pillar', 'sugarcane').state;
      state = engine.chooseStyle(state, 'style_lamps');

      expect(engine.endingFor(state)!.id, 'ending_quiet');
    });

    test('the last ending is unconditional, so nobody finishes with nothing', () {
      expect(adventure.endings.last.requires.isAlwaysMet, isTrue);
    });
  });

  group('the journal and hints', () {
    test('it starts with one thing to do and no spoilers', () {
      final journal = engine.journal(engine.newGame());

      expect(journal, hasLength(1));
      expect(journal.single.step.id, 'q_list');
      expect(journal.single.status, QuestStatus.active);
    });

    test('steps open up as the adventure moves', () {
      final shopping = engine.newGame().copyWith(flags: {'has_list'});
      final ids = engine.journal(shopping).map((row) => row.step.id);

      expect(ids, containsAll(['q_list', 'q_shop']));
      expect(
        engine.journal(shopping).firstWhere((r) => r.step.id == 'q_list').status,
        QuestStatus.done,
      );
    });

    test('status is derived, so the journal cannot drift from the game', () {
      // Nothing marks a step done. It is done because its condition holds.
      final state = engine.newGame().copyWith(
        flags: {'has_list', 'market_done'},
      );
      final shop = adventure.quests.firstWhere((q) => q.id == 'q_shop');
      expect(engine.statusOf(state, shop), QuestStatus.done);

      final without = engine.newGame().copyWith(flags: {'has_list'});
      expect(engine.statusOf(without, shop), QuestStatus.active);
    });

    test('a hint is always available while there is something to do', () {
      expect(engine.currentHint(engine.newGame()), isNotNull);
      expect(
        engine.currentHint(engine.newGame().copyWith(flags: {'has_list'})),
        contains('Kannan'),
      );
    });
  });

  group('conversations react to what has happened', () {
    test('Ammal has a different line before and after the shopping', () {
      final before = engine.openingNode(engine.newGame(), 'ammal')!;
      final after = engine.openingNode(
        engine.newGame().copyWith(flags: {'has_list', 'market_done'}),
        'ammal',
      )!;

      expect(before.id, 'ammal_first');
      expect(after.id, 'ammal_done');
    });

    test('important conversations can be heard again', () {
      // Ammal repeats the list on request; Selvi repeats the description of
      // the stencil. Neither is a one-time announcement.
      final shopping = engine.newGame().copyWith(flags: {'has_list'});
      final node = engine.openingNode(shopping, 'ammal')!;
      final repeat = engine.choicesFor(shopping, node);

      expect(repeat.map((choice) => choice.goTo), contains('ammal_list'));
    });

    test('a decision changes a later conversation, not only the ending', () {
      // Selvi mentions the cows only to a player who invited Murugan.
      final invited = engine.newGame().copyWith(
        flags: {'heard_about_stencil', 'invited_murugan'},
      );
      final declined = engine.newGame().copyWith(
        flags: {'heard_about_stencil', 'declined_murugan'},
      );

      expect(engine.openingNode(invited, 'selvi')!.id, 'selvi_murugan');
      expect(engine.openingNode(declined, 'selvi')!.id, 'selvi_stencil');
    });

    test('talking to Murugan reveals his clue without a choice being needed', () {
      final state = engine.newGame().copyWith(flags: {'has_list'});
      final node = engine.openingNode(state, 'murugan')!;
      final after = engine.enterNode(state, node);

      expect(after.state.clues, contains('clue_dawn'));
      expect(after.gainedClueIds, ['clue_dawn']);
    });

    test('Kannan explains the alternative once the list is known', () {
      final state = engine.newGame().copyWith(flags: {'has_list'});
      final node = engine.openingNode(state, 'kannan')!;

      expect(node.id, 'kannan_list');
      expect(node.lines.join(' '), contains('palm sugar'));
      expect(engine.enterNode(state, node).state.flags,
          contains('knows_alternative'));
    });
  });

  group('the scene', () {
    test('a hotspot that is not yet relevant is absent, not dead', () {
      final fresh = engine.newGame().copyWith(locationId: 'market');
      final labels = engine.visibleHotspots(fresh).map((spot) => spot.label);
      expect(labels, isNot(contains('A stack of boards')));

      final knowing = fresh.copyWith(clues: {'clue_basket'});
      expect(
        engine.visibleHotspots(knowing).map((spot) => spot.label),
        contains('A stack of boards'),
      );
    });

    test('a one-shot object is used up', () {
      var state = engine.newGame().copyWith(
        locationId: 'market',
        clues: {'clue_basket'},
      );
      final result = engine.inspect(state, 'mk_boards');

      expect(result.gainedClueIds, ['clue_board']);
      state = result.state;
      expect(
        engine.visibleHotspots(state).map((spot) => spot.id),
        isNot(contains('mk_boards')),
      );
    });

    test('arriving somewhere is remembered', () {
      final state = engine.moveTo(engine.newGame(), 'market');
      expect(state.flags, contains('been_market'));
      expect(state.locationId, 'market');
    });
  });

  group('no action can make the adventure unwinnable', () {
    test('spending every coin badly still leaves an ending reachable', () {
      // The worst basket: the expensive pot and nothing else useful.
      var state = engine.newGame().copyWith(flags: {'has_list'});
      state = engine.buy(state, 'pottery', 'brass_pot').state;
      expect(state.coins, 26 - 9);

      // Even from here the remaining list is affordable: rice 4 + palm sugar 6
      // + milk 3 + cane 3 = 16, and 17 coins are left.
      for (final (stall, item) in [
        ('grain', 'rice'),
        ('grain', 'palm_sugar'),
        ('dairy', 'milk'),
        ('grain', 'sugarcane'),
      ]) {
        final result = engine.buy(state, stall, item);
        expect(result.ok, isTrue, reason: '$item: ${result.message}');
        state = result.state;
      }
      expect(engine.shoppingComplete(state), isTrue);
    });

    test('you cannot buy your way into a basket you cannot finish', () {
      // The soft lock this rule exists for: both pots cost 15 of 26 coins,
      // and the rest of the list then costs 16. Nothing can be sold back, so
      // without this check the adventure would still be running and no longer
      // finishable. A player would not find out for several minutes.
      var state = engine.newGame().copyWith(flags: {'has_list'});
      state = engine.buy(state, 'pottery', 'brass_pot').state;
      expect(state.coins, 17);

      final second = engine.buy(state, 'pottery', 'clay_pot');

      expect(second.ok, isFalse);
      expect(second.state.coins, 17, reason: 'a refused sale costs nothing');
      expect(second.state.hasItem('clay_pot'), isFalse);
      expect(second.message, contains('rest of the list'));

      // And the list is still completable from where they are.
      for (final (stall, item) in [
        ('grain', 'rice'),
        ('grain', 'palm_sugar'),
        ('dairy', 'milk'),
        ('grain', 'sugarcane'),
      ]) {
        final result = engine.buy(state, stall, item);
        expect(result.ok, isTrue, reason: '$item: ${result.message}');
        state = result.state;
      }
      expect(engine.shoppingComplete(state), isTrue);
    });

    test('the stall shows the same answer the purchase would give', () {
      // A button that is offered and then refuses is worse than one that
      // explains itself up front.
      var state = engine.newGame().copyWith(flags: {'has_list'});
      state = engine.buy(state, 'pottery', 'brass_pot').state;

      final pottery = adventure.market.stalls
          .firstWhere((stall) => stall.id == 'pottery');
      final clay = engine
          .stallEntries(state, pottery)
          .firstWhere((entry) => entry.item.id == 'clay_pot');

      expect(clay.canBuy, isFalse);
      expect(clay.blockedReason, 'Not enough coins');
    });

    test('what is left to buy is costed from where the player is', () {
      var state = engine.newGame().copyWith(flags: {'has_list'});
      expect(engine.remainingBasketCost(state), 22);

      state = engine.buy(state, 'grain', 'rice').state;
      expect(engine.remainingBasketCost(state), 18, reason: 'rice covered');

      state = engine.buy(state, 'dairy', 'milk').state;
      expect(engine.remainingBasketCost(state), 15);
    });

    test('wrong guesses and wrong placements cost nothing but a count', () {
      var state = engine.newGame().copyWith(
        clues: {'clue_basket'},
        inventory: {'clay_pot': 1},
      );
      final before = state.coins;

      for (var i = 0; i < 5; i++) {
        state = engine.accuse(state, 'square', {'clue_basket'}).state;
        state = engine.place(state, 'slot_doorway', 'clay_pot').state;
      }

      expect(state.coins, before);
      expect(state.hasItem('clay_pot'), isTrue);
      expect(state.isFinished, isFalse);
      expect(state.wrongAccusations, 5);
    });
  });

  group('saving and restoring', () {
    test('a half-played game survives a round trip', () {
      var state = engine.newGame().copyWith(flags: {'has_list'});
      state = engine.buy(state, 'pottery', 'clay_pot').state;
      state = engine.moveTo(state, 'courtyard');
      state = engine.enterNode(
        state,
        engine.openingNode(state, 'selvi')!,
      ).state;
      state = engine.place(state, 'slot_fire', 'clay_pot').state;
      state = engine.chooseStyle(state, 'style_lamps');

      final restored = AdventureState.fromJson(state.toJson());

      expect(restored.locationId, 'courtyard');
      expect(restored.coins, 20);
      expect(restored.inventory, {'clay_pot': 1});
      expect(restored.flags, contains('heard_about_stencil'));
      expect(restored.clues, contains('clue_basket'));
      expect(restored.placed, {'slot_fire': 'clay_pot'});
      expect(restored.styleId, 'style_lamps');
      expect(restored.signature, state.signature);
    });

    test('pictures survive a round trip, by name', () {
      // Icons used to be saved as font code points and rebuilt from the
      // number. That compiles and passes tests, and then the release build
      // refuses it: a non-constant IconData makes the whole Material icon font
      // un-shakeable. They are saved as names from a fixed registry now.
      final saved = adventure.toMap();
      final firstSpot =
          (saved['locations'] as List).first as Map<String, dynamic>;
      final icon = ((firstSpot['hotspots'] as List).first
          as Map<String, dynamic>)['icon'];

      expect(icon, isA<String>(), reason: 'a name, not a number');
      expect(kAdventureIcons.keys, contains(icon));

      final restored = Adventure.fromJson(adventure.toJson());
      expect(
        restored.character('ammal')!.icon,
        adventure.character('ammal')!.icon,
      );
      expect(restored.item('clay_pot')!.icon, adventure.item('clay_pot')!.icon);
      expect(restored.clue('clue_dawn')!.icon, adventure.clue('clue_dawn')!.icon);
    });

    test('every picture the adventure uses is in the registry', () {
      // An icon outside the registry would save as "unknown" and come back a
      // question mark, so the bundled adventure must only use registered ones.
      final used = <IconData>[
        for (final place in adventure.locations)
          for (final spot in place.hotspots) spot.icon,
        for (final person in adventure.characters) person.icon,
        for (final item in adventure.items) item.icon,
        for (final clue in adventure.mystery.clues) clue.icon,
        for (final style in adventure.preparation.styles) style.icon,
        for (final ending in adventure.endings) ending.icon,
        for (final stall in adventure.market.stalls) stall.icon,
      ];

      for (final icon in used) {
        expect(
          adventureIconName(icon),
          isNot('unknown'),
          reason: 'code point ${icon.codePoint} is not registered',
        );
      }
    });

    test('an unknown picture name opens as a question mark, not a crash', () {
      expect(adventureIcon('a_name_from_a_later_version'),
          Icons.help_outline_rounded);
      expect(adventureIcon(null), Icons.help_outline_rounded);
    });

    test('the whole adventure survives a round trip', () {
      final restored = Adventure.fromJson(adventure.toJson());

      expect(restored.id, adventure.id);
      expect(restored.locations, hasLength(3));
      expect(restored.characters, hasLength(4));
      expect(restored.items.map((i) => i.id),
          adventure.items.map((i) => i.id));
      expect(restored.market.startingCoins, 26);
      expect(restored.mystery.solutionLocationId, 'market');
      expect(restored.mystery.supportingClueIds, hasLength(3));

      // And it is still playable after the round trip, which is what matters
      // for a generated adventure saved and reloaded offline.
      final report = const AdventureValidator().validate(restored);
      expect(report.problems, isEmpty, reason: report.toString());
    });
  });

  group('the validator catches broken adventures', () {
    Adventure broken(Map<String, dynamic> Function(Map<String, dynamic>) edit) =>
        Adventure.fromMap(edit(adventure.toMap()));

    test('a dangling exit', () {
      final bad = broken((map) {
        final locations = map['locations'] as List;
        final square = locations.first as Map<String, dynamic>;
        final hotspots = square['hotspots'] as List;
        (hotspots.first as Map<String, dynamic>)['targetId'] = 'nowhere';
        (hotspots.first as Map<String, dynamic>)['kind'] = 'exit';
        return map;
      });

      final report = const AdventureValidator().validate(bad);
      expect(report.isValid, isFalse);
      expect(report.problems.join(' '), contains('nowhere'));
    });

    test('a clue nobody can find', () {
      final bad = broken((map) {
        final mystery = map['mystery'] as Map<String, dynamic>;
        (mystery['clues'] as List).add({
          'id': 'clue_ghost',
          'text': 'Something nobody can ever learn.',
          'source': 'Nowhere',
        });
        return map;
      });

      final report = const AdventureValidator().validate(bad);
      expect(report.isValid, isFalse);
      expect(
        report.problems.join(' '),
        anyOf(
          contains('can never be discovered'),
          contains('exactly three clues'),
        ),
      );
    });

    test('a budget that cannot cover the list', () {
      final bad = broken((map) {
        (map['market'] as Map<String, dynamic>)['startingCoins'] = 5;
        return map;
      });

      final report = const AdventureValidator().validate(bad);
      expect(report.isValid, isFalse);
      expect(report.problems.join(' '), contains('cheapest basket'));
    });

    test('a request nothing on sale can satisfy', () {
      final bad = broken((map) {
        final market = map['market'] as Map<String, dynamic>;
        for (final stall in market['stalls'] as List) {
          final entry = stall as Map<String, dynamic>;
          if (entry['id'] == 'dairy') entry['soldOutItemIds'] = ['milk'];
        }
        return map;
      });

      final report = const AdventureValidator().validate(bad);
      expect(report.isValid, isFalse);
      expect(report.problems.join(' '), contains('can actually be bought'));
    });

    test('a character who can fall silent', () {
      final bad = broken((map) {
        final characters = map['characters'] as List;
        final ammal = characters.first as Map<String, dynamic>;
        final nodes = ammal['nodes'] as List;
        (nodes.last as Map<String, dynamic>)['requires'] = {
          'flags': ['a_flag_never_set'],
        };
        return map;
      });

      final report = const AdventureValidator().validate(bad);
      expect(report.isValid, isFalse);
      expect(report.problems.join(' '), contains('say nothing at all'));
    });

    test('an ending nobody can reach', () {
      final bad = broken((map) {
        final endings = map['endings'] as List;
        (endings.last as Map<String, dynamic>)['requires'] = {
          'flags': ['impossible_flag'],
        };
        return map;
      });

      final report = const AdventureValidator().validate(bad);
      expect(report.isValid, isFalse);
      expect(report.problems.join(' '), contains('last ending is conditional'));
    });

    test('an adventure that simply cannot be finished', () {
      // Remove the stencil from the mystery's reward and the courtyard can
      // never be completed, so no ending is reachable — structurally fine,
      // unplayable in fact. This is the case only the solver catches.
      final bad = broken((map) {
        final preparation = map['preparation'] as Map<String, dynamic>;
        for (final slot in preparation['slots'] as List) {
          final entry = slot as Map<String, dynamic>;
          if (entry['id'] == 'slot_doorway') {
            entry['acceptedItemIds'] = ['jaggery'];
          }
        }
        return map;
      });

      final report = const AdventureValidator().validate(bad);
      expect(report.isValid, isFalse);
      expect(
        report.problems.join(' '),
        anyOf(contains('cannot be completed'), contains('could not be shown')),
      );
    });

    test('a valid adventure is not rejected', () {
      expect(const AdventureValidator().validate(adventure).isValid, isTrue);
    });
  });
}
