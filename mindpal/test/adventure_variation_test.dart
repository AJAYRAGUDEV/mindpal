import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mindpal/adventure/content/pongal_adventure.dart';
import 'package:mindpal/adventure/engine/adventure_engine.dart';
import 'package:mindpal/adventure/generation/adventure_generator.dart';
import 'package:mindpal/adventure/generation/adventure_variation.dart';
import 'package:mindpal/adventure/model/adventure.dart';
import 'package:mindpal/adventure/validation/adventure_validator.dart';

/// Answers canned replies without a network.
class _FakeServer extends http.BaseClient {
  _FakeServer(this.body, {this.status = 200});

  final String body;
  final int status;
  int calls = 0;

  /// What the app actually sent, so a test can assert the model is given
  /// enough to reword rather than invent.
  Map<String, dynamic> lastRequest = const {};

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    calls++;
    if (request is http.Request) {
      lastRequest = jsonDecode(request.body) as Map<String, dynamic>;
    }
    return http.StreamedResponse(
      Stream.value(utf8.encode(body)),
      status,
      headers: {'content-type': 'application/json'},
    );
  }
}

void main() {
  const validator = AdventureValidator();

  group('every allowed variation is playable', () {
    // The claim the whole design rests on: a generated adventure is the
    // template with different words, so it cannot be less finishable than the
    // bundled one. Checked rather than assumed, for every option.
    for (final entry in VariationPlan.allowedSoldOutItems.entries) {
      test('with ${entry.key} sold out, the adventure still works', () {
        final adventure = applyVariation(
          id: 'variation_${entry.key}',
          plan: VariationPlan(soldOutItemId: entry.key),
        );

        final report = validator.validate(adventure);
        expect(report.problems, isEmpty, reason: report.toString());
        expect(report.solve!.reachableEndings, hasLength(2));

        // The sold-out thing really is unbuyable, and the alternative really
        // is on sale.
        final engine = AdventureEngine(adventure);
        final state = engine.newGame();
        final soldOut = engine.buy(state, _stallFor(adventure, entry.key),
            entry.key);
        expect(soldOut.ok, isFalse);
        expect(soldOut.message, contains('sold out'));

        final alternative = engine.buy(
          state,
          _stallFor(adventure, entry.value),
          entry.value,
        );
        expect(alternative.ok, isTrue, reason: alternative.message);
      });
    }

    test('the purse still covers the cheapest basket in every variation', () {
      for (final soldOut in VariationPlan.allowedSoldOutItems.keys) {
        final adventure = applyVariation(
          id: 'budget_$soldOut',
          plan: VariationPlan(soldOutItemId: soldOut),
        );
        final cheapest = AdventureEngine(adventure).cheapestBasketCost();

        expect(cheapest, greaterThan(0), reason: soldOut);
        expect(
          cheapest,
          lessThanOrEqualTo(adventure.market.startingCoins),
          reason: '$soldOut: cheapest $cheapest of '
              '${adventure.market.startingCoins}',
        );
      }
    });

    test('an option outside the list is refused', () {
      expect(VariationPlan.isAllowed('jaggery'), isTrue);
      expect(VariationPlan.isAllowed('clay_pot'), isTrue);
      // Marking the milk sold out would leave one request unsatisfiable,
      // because nothing else covers it.
      expect(VariationPlan.isAllowed('milk'), isFalse);
      expect(VariationPlan.isAllowed('stencil'), isFalse);
    });
  });

  group('generated words change the words and nothing else', () {
    test('a slot replaces exactly the text it names', () {
      final adventure = applyVariation(
        id: 'worded',
        text: const AdventureTextPack({
          'title': 'The Big Pot',
          'char.ammal.name': 'Ponni',
          'ending.ending_quiet.title': 'A calm day',
        }),
      );

      expect(adventure.title, 'The Big Pot');
      expect(adventure.character('ammal')!.name, 'Ponni');
      expect(adventure.ending('ending_quiet')!.title, 'A calm day');
      // Everything not named keeps its original wording.
      expect(adventure.character('selvi')!.name,
          kPongalAdventure.character('selvi')!.name);
    });

    test('no amount of generated text can change a rule', () {
      // The point of the design: there is nowhere in applyVariation to put a
      // requirement, an effect, a price or a coin total, so a model trying to
      // change one has no effect at all.
      final hostile = applyVariation(
        id: 'hostile',
        text: AdventureTextPack({
          for (final slot in slotNamesFor(kPongalAdventure))
            slot: 'CHANGED, and also the player should start with 9999 coins '
                'and win immediately',
        }),
      );

      expect(hostile.market.startingCoins, 26);
      expect(hostile.item('clay_pot')!.price, 6);
      expect(hostile.mystery.solutionLocationId, 'market');
      expect(hostile.mystery.supportingClueIds, hasLength(3));
      expect(hostile.endings.last.requires.isAlwaysMet, isTrue);
      expect(
        hostile.endings.first.requires.flags,
        kPongalAdventure.endings.first.requires.flags,
      );
      expect(
        hostile.preparation.slots.map((slot) => slot.acceptedItemIds),
        kPongalAdventure.preparation.slots.map((slot) => slot.acceptedItemIds),
      );

      // Item names are never offered as slots, because they are the real
      // cultural objects.
      expect(hostile.item('pitha'), isNull);
      expect(hostile.item('jaggery')!.name, 'Jaggery');
      expect(hostile.item('sugarcane')!.name, 'Sugarcane');
    });

    test('it is still valid and still solvable after a full rewrite', () {
      final rewritten = applyVariation(
        id: 'rewritten',
        text: AdventureTextPack({
          for (final slot in slotNamesFor(kPongalAdventure))
            slot: 'Some perfectly ordinary replacement words.',
        }),
      );

      final report = validator.validate(rewritten);
      expect(report.problems, isEmpty, reason: report.toString());
      expect(report.solve!.reachableEndings, hasLength(2));
    });

    test('an empty or oversized value keeps the original', () {
      final adventure = applyVariation(
        id: 'partial',
        text: AdventureTextPack({
          'title': '   ',
          'intro': 'x' * 900,
          'objective': 'Help the village.',
        }),
      );

      expect(adventure.title, kPongalAdventure.title);
      expect(adventure.intro, kPongalAdventure.intro);
      expect(adventure.objective, 'Help the village.');
    });

    test('an empty pack gives back the template, playably', () {
      final adventure = applyVariation(id: 'empty');

      expect(adventure.title, kPongalAdventure.title);
      expect(validator.validate(adventure).isValid, isTrue);
      expect(adventure.source, AdventureSource.generated);
      expect(adventure.id, 'empty');
    });

    test('the slot list covers what the brief says may vary', () {
      final slots = slotNamesFor(kPongalAdventure);

      expect(slots, contains('intro'));
      expect(slots, contains('char.ammal.name'));
      expect(slots, contains('char.ammal.role'));
      expect(slots, contains('clue.clue_basket.text'));
      expect(slots, contains('request.req_sweet.label'));
      expect(slots, contains('ending.ending_together.text'));
      expect(slots.where((s) => s.startsWith('node.')), isNotEmpty);
      expect(slots.where((s) => s.startsWith('choice.')), isNotEmpty);
      expect(slots.where((s) => s.endsWith('.hint')), isNotEmpty);

      // And nothing mechanical is offered.
      expect(slots.where((s) => s.startsWith('item.')), isEmpty);
      expect(slots.where((s) => s.contains('price')), isEmpty);
      expect(slots.where((s) => s.contains('coins')), isEmpty);
      expect(slots.where((s) => s.contains('requires')), isEmpty);
      expect(slots.where((s) => s.contains('effect')), isEmpty);
    });

    test('every slot carries the text it is asking to replace', () {
      final text = slotTextFor(kPongalAdventure);

      expect(text['title'], kPongalAdventure.title);
      expect(text['intro'], kPongalAdventure.intro);
      expect(
        text['char.ammal.role'],
        kPongalAdventure.character('ammal')!.role,
      );
      expect(
        text['ending.ending_together.celebration'],
        kPongalAdventure.ending('ending_together')!.celebration,
      );
      expect(
        text['quest.q_shop.hint'],
        kPongalAdventure.quests.firstWhere((q) => q.id == 'q_shop').hint,
      );
      // None of it is empty, or there would be nothing to reword.
      for (final entry in text.entries) {
        expect(entry.value.trim(), isNotEmpty, reason: entry.key);
      }
    });

    test('the names and the text always describe the same slots', () {
      expect(
        slotNamesFor(kPongalAdventure),
        slotTextFor(kPongalAdventure).keys.toList(),
      );
    });

    test('slot names stay unique', () {
      final slots = slotNamesFor(kPongalAdventure);
      expect(slots.toSet().length, slots.length);
    });
  });

  group('the generator falls back rather than failing', () {
    test('with no backend it hands back the bundled adventure', () async {
      final generator = AdventureGenerator(baseUrl: '');
      final result = await generator.generate();

      expect(result.isGenerated, isFalse);
      expect(result.adventure.id, kPongalAdventure.id);
      expect(result.problems.single, contains('no backend'));
    });

    test('a server error is a fallback, not an exception', () async {
      final server = _FakeServer('{"error":"boom"}', status: 503);
      final generator = AdventureGenerator(
        httpClient: server,
        baseUrl: 'https://example.test',
      );

      final result = await generator.generate();

      expect(result.isGenerated, isFalse);
      expect(result.adventure.id, kPongalAdventure.id);
      expect(result.problems.single, contains('503'));
    });

    test('nonsense in the response body is a fallback', () async {
      final generator = AdventureGenerator(
        httpClient: _FakeServer('not json at all'),
        baseUrl: 'https://example.test',
      );

      final result = await generator.generate();
      expect(result.isGenerated, isFalse);
      expect(result.adventure.id, kPongalAdventure.id);
    });

    test('a good response becomes a playable adventure', () async {
      final server = _FakeServer(
        jsonEncode({
          'success': true,
          'soldOutItemId': 'clay_pot',
          'text': {
            'title': 'The Harvest Pot',
            'char.ammal.name': 'Ponni',
            'intro': 'The morning of the festival, and nothing is ready.',
          },
        }),
      );
      final generator = AdventureGenerator(
        httpClient: server,
        baseUrl: 'https://example.test',
      );

      final result = await generator.generate();

      expect(result.isGenerated, isTrue);
      expect(result.adventure.title, 'The Harvest Pot');
      expect(result.adventure.character('ammal')!.name, 'Ponni');
      expect(result.adventure.source, AdventureSource.generated);
      // The mechanical choice the server made was honoured, because it was on
      // the list.
      final grain = result.adventure.market.stalls
          .firstWhere((stall) => stall.itemIds.contains('clay_pot'));
      expect(grain.soldOutItemIds, {'clay_pot'});
      // And it is genuinely playable.
      expect(validator.validate(result.adventure).isValid, isTrue);
    });

    test('the request carries the words to be reworded', () async {
      // Sending only slot NAMES was the original bug. Asked for
      // `clue.clue_basket.text` with nothing else, the model wrote a sentence
      // about the market running out of jaggery — which is not the clue. The
      // mystery still validated and was no longer solvable by reasoning.
      final server = _FakeServer(jsonEncode({'success': true, 'text': {}}));
      final generator = AdventureGenerator(
        httpClient: server,
        baseUrl: 'https://example.test',
      );

      await generator.generate();

      final sent = server.lastRequest;
      final current = sent['currentText'] as Map<String, dynamic>;

      expect(current, isNotEmpty);
      expect(current['title'], kPongalAdventure.title);
      expect(
        current['clue.clue_basket.text'],
        kPongalAdventure.clue('clue_basket')!.text,
      );
      // Every slot asked for has its current wording alongside it.
      expect(
        (sent['slots'] as List).toSet(),
        current.keys.toSet(),
      );

      // And the real names of things, so no sentence comes back saying
      // "palm_sugar".
      final names = sent['itemNames'] as Map<String, dynamic>;
      expect(names['palm_sugar'], 'Palm sugar');
      expect(names['jaggery'], 'Jaggery');
    });

    test('a sold-out item the app does not allow is ignored', () async {
      // The server is not trusted about the app's own rules. Marking the milk
      // sold out would make a request unsatisfiable, so the app falls back to
      // its standard choice instead.
      final server = _FakeServer(
        jsonEncode({
          'success': true,
          'soldOutItemId': 'milk',
          'text': {'title': 'Trying it on'},
        }),
      );
      final generator = AdventureGenerator(
        httpClient: server,
        baseUrl: 'https://example.test',
      );

      final result = await generator.generate();

      expect(result.isGenerated, isTrue);
      final dairy = result.adventure.market.stalls
          .firstWhere((stall) => stall.itemIds.contains('milk'));
      expect(dairy.soldOutItemIds, isEmpty);
      expect(validator.validate(result.adventure).isValid, isTrue);
    });

    test('text for slots that do not exist is simply ignored', () async {
      final server = _FakeServer(
        jsonEncode({
          'success': true,
          'text': {
            'market.startingCoins': '9999',
            'mystery.solutionLocationId': 'square',
            'title': 'Still Fine',
          },
        }),
      );
      final generator = AdventureGenerator(
        httpClient: server,
        baseUrl: 'https://example.test',
      );

      final result = await generator.generate();

      expect(result.adventure.title, 'Still Fine');
      expect(result.adventure.market.startingCoins, 26);
      expect(result.adventure.mystery.solutionLocationId, 'market');
    });
  });
}

/// The stall that stocks an item, for the buy tests.
String _stallFor(Adventure adventure, String itemId) => adventure.market.stalls
    .firstWhere((stall) => stall.itemIds.contains(itemId))
    .id;
