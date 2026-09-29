import '../engine/adventure_engine.dart';
import '../model/adventure.dart';
import '../model/requirement.dart';
import 'adventure_solver.dart';

/// What the validator found.
class ValidationReport {
  const ValidationReport({required this.problems, this.solve});

  /// Empty means the adventure is fit to play.
  final List<String> problems;

  /// The completability search, when the structure was sound enough to run it.
  final SolveReport? solve;

  bool get isValid => problems.isEmpty;

  @override
  String toString() =>
      isValid ? 'valid' : 'invalid:\n  ${problems.join('\n  ')}';
}

/// Checks that an adventure is playable before anybody plays it.
///
/// Two layers, and both matter:
///
///  1. **Structure** — every id resolves, the shapes are the right sizes, the
///     budget can cover the shopping, a character can always say something,
///     and the last ending is unconditional. These catch the mistakes a
///     language model makes most: referring to a stall it did not create, or
///     writing four clues where the game expects three.
///  2. **Completability** — `AdventureSolver` plays the whole reachable game
///     and confirms an ending can be reached. Structure being sound does not
///     mean the adventure can be finished: every id can resolve in an
///     adventure where the one item you need is behind a door that needs that
///     item.
///
/// Anything that fails is refused and the caller falls back to the bundled
/// adventure. Nothing half-checked reaches a player.
class AdventureValidator {
  const AdventureValidator({this.solver = const AdventureSolver()});

  final AdventureSolver solver;

  ValidationReport validate(Adventure adventure, {bool checkSolvable = true}) {
    final problems = <String>[];

    final locationIds = {for (final place in adventure.locations) place.id};
    final characterIds = {for (final person in adventure.characters) person.id};
    final itemIds = {for (final thing in adventure.items) thing.id};
    final clueIds = {for (final clue in adventure.mystery.clues) clue.id};
    final endingIds = {for (final ending in adventure.endings) ending.id};

    // ----------------------------------------------------------- the shape
    if (adventure.id.trim().isEmpty) problems.add('The adventure has no id.');
    if (adventure.title.trim().isEmpty) {
      problems.add('The adventure has no title.');
    }
    if (adventure.intro.trim().isEmpty) {
      problems.add('The adventure has no introduction.');
    }
    if (adventure.objective.trim().isEmpty) {
      problems.add('The adventure has no objective.');
    }

    _checkUnique(problems, 'location', adventure.locations.map((l) => l.id));
    _checkUnique(problems, 'character', adventure.characters.map((c) => c.id));
    _checkUnique(problems, 'item', adventure.items.map((i) => i.id));
    _checkUnique(problems, 'clue', adventure.mystery.clues.map((c) => c.id));
    _checkUnique(problems, 'ending', adventure.endings.map((e) => e.id));
    _checkUnique(problems, 'stall', adventure.market.stalls.map((s) => s.id));

    if (adventure.locations.length < 3) {
      problems.add(
        'Festival Quest needs three locations; this has '
        '${adventure.locations.length}.',
      );
    }
    if (adventure.characters.length < 4) {
      problems.add(
        'Festival Quest needs four characters; this has '
        '${adventure.characters.length}.',
      );
    }
    if (adventure.mystery.clues.length != 3) {
      problems.add(
        'The mystery needs exactly three clues; this has '
        '${adventure.mystery.clues.length}.',
      );
    }
    if (adventure.endings.length < 2) {
      problems.add(
        'There must be two endings; this has ${adventure.endings.length}.',
      );
    }
    if (!locationIds.contains(adventure.startLocationId)) {
      problems.add(
        'The adventure starts at "${adventure.startLocationId}", which is not '
        'a location.',
      );
    }

    // --------------------------------------------------- locations and scenes
    for (final place in adventure.locations) {
      if (place.name.trim().isEmpty) {
        problems.add('Location "${place.id}" has no name.');
      }
      for (final spot in place.hotspots) {
        final where = 'hotspot "${spot.id}" in "${place.id}"';
        if (spot.label.trim().isEmpty) problems.add('$where has no label.');
        if (spot.x < 0 || spot.x > 1 || spot.y < 0 || spot.y > 1) {
          problems.add('$where sits outside the scene.');
        }
        switch (spot.kind) {
          case HotspotKind.exit:
            if (!locationIds.contains(spot.targetId)) {
              problems.add('$where leads to "${spot.targetId}", which is not '
                  'a location.');
            }
          case HotspotKind.character:
            if (!characterIds.contains(spot.targetId)) {
              problems.add('$where points at "${spot.targetId}", who does not '
                  'exist.');
            }
          case HotspotKind.object:
          case HotspotKind.market:
          case HotspotKind.accuse:
          case HotspotKind.prepare:
            break;
        }
        _checkEffect(problems, where, spot.onInspect, itemIds, clueIds,
            locationIds, endingIds);
        _checkRequirement(problems, where, spot.visibleWhen, itemIds, clueIds);

        // A one-shot with no flag would never disappear, which is how an
        // infinite supply of a "unique" item gets created.
        if (!spot.repeatable && spot.onInspect.setFlags.isEmpty) {
          problems.add('$where is meant to be used once but sets no flag, so '
              'it can be used for ever.');
        }
      }
    }

    // ------------------------------------------------------------ characters
    for (final person in adventure.characters) {
      if (!locationIds.contains(person.locationId)) {
        problems.add('${person.name} is at "${person.locationId}", which is '
            'not a location.');
      }
      if (person.nodes.isEmpty) {
        problems.add('${person.name} has nothing to say.');
        continue;
      }
      if (!person.nodes.last.requires.isAlwaysMet) {
        // Otherwise a player can tap somebody and get silence.
        problems.add('${person.name}’s last line is conditional, so there '
            'are states in which they say nothing at all.');
      }

      // Exactly one unconditional line, and it must be the last.
      //
      // A character opens with the FIRST line whose condition is met, so an
      // unconditional line anywhere else silently shadows every line after it.
      // That is not a theoretical worry: Selvi originally greeted every new
      // player with the answer to a question they had not asked, because the
      // node meant to be reached by "tell me again" was unconditional and
      // listed above her opening line. A test caught it; this rule stops it
      // coming back, in hand-written and generated adventures alike.
      for (final node in person.nodes.take(person.nodes.length - 1)) {
        if (node.requires.isAlwaysMet) {
          problems.add(
            '${person.name}’s line "${node.id}" has no condition but is '
            'not the last one, so every line after it can never be reached.',
          );
        }
      }

      final nodeIds = {for (final node in person.nodes) node.id};
      _checkUnique(problems, 'node of ${person.name}',
          person.nodes.map((node) => node.id));

      for (final node in person.nodes) {
        final where = '${person.name}/"${node.id}"';
        if (node.lines.isEmpty) problems.add('$where has no lines.');
        _checkRequirement(problems, where, node.requires, itemIds, clueIds);
        _checkEffect(problems, where, node.onEnter, itemIds, clueIds,
            locationIds, endingIds);

        for (final choice in node.choices) {
          final choiceWhere = '$where choice "${choice.id}"';
          if (choice.text.trim().isEmpty) {
            problems.add('$choiceWhere has no text.');
          }
          if (choice.goTo != null && !nodeIds.contains(choice.goTo)) {
            problems.add('$choiceWhere goes to "${choice.goTo}", which is not '
                'one of ${person.name}’s lines.');
          }
          _checkRequirement(
              problems, choiceWhere, choice.requires, itemIds, clueIds);
          _checkEffect(problems, choiceWhere, choice.effect, itemIds, clueIds,
              locationIds, endingIds);
        }
      }
    }

    // ---------------------------------------------------------------- market
    final market = adventure.market;
    if (market.startingCoins <= 0) {
      problems.add('The market gives the player no coins.');
    }
    if (market.requests.isEmpty) {
      problems.add('There is nothing to shop for.');
    }
    for (final stall in market.stalls) {
      for (final id in stall.itemIds) {
        if (!itemIds.contains(id)) {
          problems.add('Stall "${stall.id}" sells "$id", which is not an '
              'item.');
        }
      }
      for (final id in stall.soldOutItemIds) {
        if (!stall.itemIds.contains(id)) {
          problems.add('Stall "${stall.id}" marks "$id" sold out but does not '
              'stock it.');
        }
      }
    }
    for (final request in market.requests) {
      if (request.acceptedItemIds.isEmpty) {
        problems.add('Request "${request.id}" accepts nothing.');
      }
      for (final id in request.acceptedItemIds) {
        if (!itemIds.contains(id)) {
          problems.add('Request "${request.id}" accepts "$id", which is not '
              'an item.');
        }
      }
      final buyable = request.acceptedItemIds.where(
        (id) => market.stalls.any(
          (stall) =>
              stall.itemIds.contains(id) &&
              !stall.soldOutItemIds.contains(id),
        ),
      );
      if (buyable.isEmpty) {
        problems.add('Nothing that satisfies "${request.label}" can actually '
            'be bought.');
      }
    }
    for (final id in itemIds) {
      final stocked = market.stalls.where((s) => s.itemIds.contains(id));
      for (final stall in stocked) {
        final item = adventure.item(id)!;
        if (item.price <= 0 && !stall.soldOutItemIds.contains(id)) {
          problems.add('"${item.name}" is for sale at ${stall.name} but costs '
              'nothing.');
        }
      }
    }

    // The budget must cover the cheapest complete basket, or the market is a
    // trap rather than a choice.
    if (problems.isEmpty) {
      final cheapest = AdventureEngine(adventure).cheapestBasketCost();
      if (cheapest < 0) {
        problems.add('The shopping list cannot be completed at any price.');
      } else if (cheapest > market.startingCoins) {
        problems.add('The cheapest basket costs $cheapest coins but the player '
            'is given ${market.startingCoins}.');
      }
    }

    // --------------------------------------------------------------- mystery
    final mystery = adventure.mystery;
    if (mystery.question.trim().isEmpty) {
      problems.add('The mystery has no question.');
    }
    if (mystery.candidateLocationIds.length < 2) {
      problems.add('The mystery offers fewer than two places to choose from, '
          'so there is nothing to work out.');
    }
    for (final id in mystery.candidateLocationIds) {
      if (!locationIds.contains(id)) {
        problems.add('The mystery offers "$id", which is not a location.');
      }
    }
    if (!mystery.candidateLocationIds.contains(mystery.solutionLocationId)) {
      problems.add('The answer to the mystery is not one of the places the '
          'player may name.');
    }
    if (mystery.supportingClueIds.isEmpty) {
      problems.add('The mystery has no supporting clues, so any guess would '
          'be accepted.');
    }
    for (final id in mystery.supportingClueIds) {
      if (!clueIds.contains(id)) {
        problems.add('The mystery is supported by "$id", which is not one of '
            'its clues.');
      }
    }
    if (!itemIds.contains(mystery.decorationItemId)) {
      problems.add('The missing decoration "${mystery.decorationItemId}" is '
          'not an item.');
    }

    // Every clue must be discoverable somewhere, or the mystery cannot be
    // explained however hard the player looks.
    final revealed = _allRevealedClues(adventure);
    for (final id in clueIds) {
      if (!revealed.contains(id)) {
        problems.add('Clue "$id" can never be discovered.');
      }
    }

    // ------------------------------------------------------------ courtyard
    final preparation = adventure.preparation;
    if (preparation.slots.isEmpty) {
      problems.add('The courtyard has nowhere to put anything.');
    }
    if (preparation.styles.length < 2) {
      problems.add('The courtyard offers fewer than two arrangements.');
    }
    for (final slot in preparation.slots) {
      if (slot.acceptedItemIds.isEmpty) {
        problems.add('Slot "${slot.id}" accepts nothing.');
      }
      for (final id in slot.acceptedItemIds) {
        if (!itemIds.contains(id)) {
          problems.add('Slot "${slot.id}" accepts "$id", which is not an '
              'item.');
        }
      }
    }

    // --------------------------------------------------------------- quests
    for (final step in adventure.quests) {
      final where = 'quest "${step.id}"';
      if (step.title.trim().isEmpty) problems.add('$where has no title.');
      _checkRequirement(problems, where, step.doneWhen, itemIds, clueIds);
      _checkRequirement(problems, where, step.activeWhen, itemIds, clueIds);
      if (step.doneWhen.isAlwaysMet) {
        problems.add('$where is done the moment the adventure starts.');
      }
    }

    // -------------------------------------------------------------- endings
    if (adventure.endings.isNotEmpty &&
        !adventure.endings.last.requires.isAlwaysMet) {
      problems.add('The last ending is conditional, so a player could finish '
          'the adventure and be shown nothing.');
    }
    for (final ending in adventure.endings) {
      if (ending.text.trim().isEmpty) {
        problems.add('Ending "${ending.id}" has no text.');
      }
      _checkRequirement(problems, 'ending "${ending.id}"', ending.requires,
          itemIds, clueIds);
    }

    // -------------------------------------------------------------- honesty
    if (adventure.culturalNote.festival.trim().isEmpty) {
      problems.add('The adventure does not say which festival it is about.');
    }
    if (adventure.culturalNote.summary.trim().isEmpty) {
      problems.add('The adventure has no cultural note.');
    }

    // ------------------------------------------------------ can it be played
    if (problems.isNotEmpty || !checkSolvable) {
      return ValidationReport(problems: problems);
    }

    final report = solver.solve(adventure);
    if (!report.isCompletable) {
      // "We could not show this works" is not a reason to hand it to a player,
      // so an inconclusive search is refused exactly like a proven failure.
      problems.add(
        report.provedUnfinishable
            ? 'The adventure cannot be completed: every possible way of playing '
                  'it was tried (${report.statesExplored} positions) and none '
                  'reached an ending.'
            : 'The adventure could not be shown to be completable within '
                  '${report.statesExplored} positions.',
      );
    } else if (report.unreachableEndings.isNotEmpty) {
      problems.add(
        'These endings can never happen: '
        '${report.unreachableEndings.join(', ')}. '
        'The player’s decisions would not change how it finishes.',
      );
    }

    return ValidationReport(problems: problems, solve: report);
  }

  /// Every clue id that some effect somewhere can reveal.
  Set<String> _allRevealedClues(Adventure adventure) {
    final revealed = <String>{};
    void collect(Effect effect) => revealed.addAll(effect.revealClues);

    for (final place in adventure.locations) {
      for (final spot in place.hotspots) {
        collect(spot.onInspect);
      }
    }
    for (final person in adventure.characters) {
      for (final node in person.nodes) {
        collect(node.onEnter);
        for (final choice in node.choices) {
          collect(choice.effect);
        }
      }
    }
    return revealed;
  }

  void _checkUnique(List<String> problems, String what, Iterable<String> ids) {
    final seen = <String>{};
    for (final id in ids) {
      if (id.trim().isEmpty) {
        problems.add('A $what has an empty id.');
      } else if (!seen.add(id)) {
        problems.add('Two ${what}s share the id "$id".');
      }
    }
  }

  void _checkRequirement(
    List<String> problems,
    String where,
    Requirement requirement,
    Set<String> itemIds,
    Set<String> clueIds,
  ) {
    for (final id in requirement.referencedItems) {
      if (!itemIds.contains(id)) {
        problems.add('$where needs item "$id", which does not exist.');
      }
    }
    for (final id in requirement.clues) {
      if (!clueIds.contains(id)) {
        problems.add('$where needs clue "$id", which does not exist.');
      }
    }
  }

  void _checkEffect(
    List<String> problems,
    String where,
    Effect effect,
    Set<String> itemIds,
    Set<String> clueIds,
    Set<String> locationIds,
    Set<String> endingIds,
  ) {
    for (final id in effect.referencedItems) {
      if (!itemIds.contains(id)) {
        problems.add('$where moves item "$id", which does not exist.');
      }
    }
    for (final id in effect.revealClues) {
      if (!clueIds.contains(id)) {
        problems.add('$where reveals clue "$id", which does not exist.');
      }
    }
    if (effect.goToLocation != null &&
        !locationIds.contains(effect.goToLocation)) {
      problems.add('$where moves the player to "${effect.goToLocation}", '
          'which is not a location.');
    }
    if (effect.ending != null && !endingIds.contains(effect.ending)) {
      problems.add('$where ends with "${effect.ending}", which is not an '
          'ending.');
    }
  }
}
