import 'package:flutter_test/flutter_test.dart';
import 'package:mindpal/adventure/content/festivals.dart';
import 'package:mindpal/adventure/content/pongal_adventure.dart';
import 'package:mindpal/adventure/engine/adventure_engine.dart';
import 'package:mindpal/adventure/generation/adventure_variation.dart';
import 'package:mindpal/adventure/model/adventure.dart';
import 'package:mindpal/adventure/model/adventure_icons.dart';
import 'package:mindpal/adventure/validation/adventure_validator.dart';

/// Every festival, checked as hard as the bundled adventure is.
///
/// A festival skin is content, and content is where mistakes hide: a mistyped
/// slot name does not fail to compile, it silently leaves a Pongal line in the
/// middle of a Bihu story. These tests are what make that loud.
void main() {
  const validator = AdventureValidator();

  Adventure adventureFor(festival) => applyVariation(
    id: 'festival_${festival.id}',
    festival: festival,
    source: AdventureSource.bundled,
  );

  group('every festival is a real, playable adventure', () {
    for (final festival in kFestivals) {
      group(festival.name, () {
        final adventure = adventureFor(festival);

        test('passes every check and can be completed both ways', () {
          final report = validator.validate(adventure);

          expect(report.problems, isEmpty, reason: report.toString());
          expect(report.solve!.reachableEndings, hasLength(2));
        });

        test('the mechanics are identical to the skeleton', () {
          // A skin may change every word and every picture. It may not change
          // a single number, requirement or relationship — that is what lets
          // the budget proof and the solver result carry over.
          expect(
            adventure.market.startingCoins,
            kPongalAdventure.market.startingCoins,
          );
          expect(
            AdventureEngine(adventure).cheapestBasketCost(),
            AdventureEngine(kPongalAdventure).cheapestBasketCost(),
          );
          for (final item in adventure.items) {
            expect(
              item.price,
              kPongalAdventure.item(item.id)!.price,
              reason: item.id,
            );
          }
          expect(
            adventure.mystery.solutionLocationId,
            kPongalAdventure.mystery.solutionLocationId,
          );
          expect(
            adventure.mystery.supportingClueIds,
            kPongalAdventure.mystery.supportingClueIds,
          );
          expect(
            adventure.endings.first.requires.flags,
            kPongalAdventure.endings.first.requires.flags,
          );
          for (final slot in adventure.preparation.slots) {
            expect(
              slot.acceptedItemIds,
              kPongalAdventure.preparation.slots
                  .firstWhere((other) => other.id == slot.id)
                  .acceptedItemIds,
              reason: slot.id,
            );
          }
        });

        test('says which festival it is, and that the note is unchecked', () {
          expect(adventure.culturalNote.festival, isNotEmpty);
          expect(adventure.culturalNote.summary, isNotEmpty);
          expect(adventure.culturalNote.reviewed, isFalse);
          expect(
            adventure.culturalNote.references.first.toLowerCase(),
            contains('invented'),
          );
        });

        test('every picture it names is in the registry', () {
          for (final item in adventure.items) {
            expect(
              adventureIconName(item.icon),
              isNot('unknown'),
              reason: item.name,
            );
          }
        });
      });
    }
  });

  group('the Bihu skin is complete, not half-applied', () {
    final bihu = kBihuFestival;
    final adventure = adventureFor(bihu);

    test('every slot it names really exists', () {
      // The failure this catches: a mistyped key is silently ignored and the
      // Pongal line stays, so a Bihu adventure quietly talks about sugarcane.
      final real = slotNamesFor(kPongalAdventure).toSet();
      final unknown = bihu.text.keys.where((slot) => !real.contains(slot));

      expect(
        unknown,
        isEmpty,
        reason: 'these slot names do not exist: ${unknown.join(', ')}',
      );
    });

    test('it rewrites essentially all of the words', () {
      // A skin that covered half the slots would read as two stories spliced
      // together. 95% leaves room for a line that genuinely needs no change.
      final all = slotNamesFor(kPongalAdventure);
      final covered = all.where(bihu.text.containsKey).length;

      expect(
        covered / all.length,
        greaterThanOrEqualTo(0.95),
        reason: '$covered of ${all.length} slots covered',
      );
    });

    test('and every item, place and courtyard slot', () {
      for (final item in kPongalAdventure.items) {
        expect(bihu.itemLabels.keys, contains(item.id));
      }
      for (final place in kPongalAdventure.locations) {
        expect(bihu.locationLabels.keys, contains(place.id));
      }
      for (final slot in kPongalAdventure.preparation.slots) {
        expect(bihu.slotLabels.keys, contains(slot.id));
      }
      for (final style in kPongalAdventure.preparation.styles) {
        expect(bihu.styleLabels.keys, contains(style.id));
      }
    });

    test('no Pongal word survives into the Bihu adventure', () {
      // The real test of the skin: read everything a player can see and look
      // for the other festival.
      final everything = [
        adventure.title,
        adventure.intro,
        adventure.objective,
        for (final place in adventure.locations) ...[
          place.name,
          place.description,
        ],
        for (final item in adventure.items) ...[item.name, item.description],
        for (final person in adventure.characters) ...[
          person.name,
          person.role,
          for (final node in person.nodes) ...[
            ...node.lines,
            for (final choice in node.choices) ...[
              choice.text,
              choice.reply ?? '',
            ],
          ],
        ],
        for (final request in adventure.market.requests) request.label,
        for (final stall in adventure.market.stalls) ...[
          stall.name,
          stall.keeperLine,
        ],
        adventure.mystery.question,
        adventure.mystery.revealText,
        for (final clue in adventure.mystery.clues) ...[clue.text, clue.source],
        for (final step in adventure.quests) ...[
          step.title,
          step.detail,
          step.hint ?? '',
        ],
        for (final slot in adventure.preparation.slots) ...[
          slot.label,
          slot.filledText ?? '',
        ],
        for (final style in adventure.preparation.styles) ...[
          style.name,
          style.description,
        ],
        for (final ending in adventure.endings) ...[
          ending.title,
          ending.text,
          ending.celebration,
        ],
      ].join(' ').toLowerCase();

      // Note "jaggery" is deliberately absent: it is the ordinary English
      // word, and glossing gur as "dark cane jaggery" is correct and useful.
      // What must not survive is a Pongal-specific thing or name.
      for (final pongalWord in [
        'pongal',
        'kolam',
        'sugarcane',
        'ammal',
        'selvi',
        'kannan',
        'murugan',
        'kalvayal',
        'stencil',
      ]) {
        expect(
          everything,
          isNot(contains(pongalWord)),
          reason: 'the Bihu adventure still says "$pongalWord"',
        );
      }

      // And it does say the Bihu things.
      for (final bihuWord in ['bihu', 'japi', 'gamosa', 'pitha', 'gur']) {
        expect(everything, contains(bihuWord), reason: bihuWord);
      }
    });

    test('the sold-out item is named for this festival', () {
      // "The gur went by first light", not "the jaggery".
      final engine = AdventureEngine(adventure);
      final refusal = engine.buy(engine.newGame(), 'grain', 'jaggery');

      expect(refusal.ok, isFalse);
      expect(refusal.message, contains('Gur'));
      expect(refusal.message, isNot(contains('Jaggery')));
    });

    test('it survives being saved and reopened', () {
      final restored = Adventure.fromJson(adventure.toJson());

      expect(restored.title, adventure.title);
      expect(restored.item('sugarcane')!.name, 'Gamosa');
      expect(restored.character('selvi')!.name, 'Rupali');
      expect(validator.validate(restored).isValid, isTrue);
    });
  });

  group('generated text sits on top of the festival, not under it', () {
    test('a Bihu adventure reworded is still Bihu', () {
      final reworded = applyVariation(
        id: 'bihu_reworded',
        festival: kBihuFestival,
        text: const AdventureTextPack({'title': 'A Spring Morning'}),
      );

      expect(reworded.title, 'A Spring Morning');
      // Everything the generation did not touch is still the festival's.
      expect(reworded.character('ammal')!.name, 'Nirmali');
      expect(reworded.item('stencil')!.name, 'Japi');
      expect(reworded.culturalNote.festival, 'Bohag Bihu');
      expect(validator.validate(reworded).isValid, isTrue);
    });

    test('no festival chosen means the bundled Pongal adventure', () {
      final plain = applyVariation(id: 'plain');

      expect(plain.title, kPongalAdventure.title);
      expect(plain.item('stencil')!.name, 'Kolam stencil');
      expect(festivalById(null).id, 'pongal');
      expect(festivalById('not_a_festival').id, 'pongal');
    });
  });
}
