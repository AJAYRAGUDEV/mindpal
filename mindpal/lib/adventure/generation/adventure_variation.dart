/// Turning a bundled adventure plus some generated words into a new adventure.
///
/// **The AI writes words. It does not write rules.**
///
/// This is the whole safety argument for letting a language model near the
/// game. A generated adventure is not a new structure: it is the hand-written
/// template with its *text* replaced, slot by slot, and with one mechanical
/// choice (which thing has sold out) picked from a short list that was checked
/// in advance. The model never supplies a requirement, an effect, a price, a
/// coin total, a clue relationship, a quest dependency or an ending condition,
/// because there is nowhere in this file to put one.
///
/// It follows that a generated adventure cannot be unwinnable in a way the
/// bundled one is not — and `AdventureValidator` still runs over the result
/// anyway, because "it follows" is not the same as "it was checked".
///
/// Every slot is optional. A value that is missing, empty or too long keeps the
/// original wording, so a partial or partly-rejected response still produces a
/// complete, playable adventure rather than an adventure with holes in it.
library;

import '../content/pongal_adventure.dart';
import '../model/adventure.dart';

/// The mechanical choices a variation may make.
///
/// One field, and its value must come from [allowedSoldOutItems]. Anything else
/// is refused. Widening this list means checking the new option with the solver
/// first — `adventure_variation_test.dart` does exactly that for every entry.
class VariationPlan {
  const VariationPlan({required this.soldOutItemId});

  /// The thing the market has run out of, forcing the player to find an
  /// acceptable alternative.
  final String soldOutItemId;

  /// The options, and what each one pushes the player towards.
  ///
  /// Both are affordable: with jaggery gone the cheapest basket is 22 coins,
  /// with the clay pot gone it is 25, and the purse holds 26. The test asserts
  /// this rather than trusting the arithmetic in this comment.
  static const Map<String, String> allowedSoldOutItems = {
    'jaggery': 'palm_sugar',
    'clay_pot': 'brass_pot',
  };

  static bool isAllowed(String itemId) =>
      allowedSoldOutItems.containsKey(itemId);

  String get alternativeItemId => allowedSoldOutItems[soldOutItemId]!;

  static const VariationPlan standard = VariationPlan(
    soldOutItemId: 'jaggery',
  );
}

/// The words a generated adventure may replace, keyed by slot.
///
/// Slot names are built from the ids already in the adventure, so the list of
/// what may be rewritten is derived from the template rather than maintained by
/// hand — a slot cannot drift out of step with the thing it names.
class AdventureTextPack {
  const AdventureTextPack(this.values);

  final Map<String, String> values;

  static const AdventureTextPack empty = AdventureTextPack({});

  /// The replacement for [slot], or null to keep the original.
  ///
  /// Length is the only judgement made here, and it is deliberately blunt: a
  /// model that returns an essay where a tile label belongs would break the
  /// layout, and one that returns an empty string would leave a character
  /// silent. Either way the original text is kept.
  String? operator [](String slot) {
    final value = values[slot]?.trim();
    if (value == null || value.isEmpty) return null;
    if (value.length > _maxSlotLength) return null;
    return value;
  }

  static const int _maxSlotLength = 600;

  Map<String, dynamic> toMap() => values;

  factory AdventureTextPack.fromMap(Map<String, dynamic> map) =>
      AdventureTextPack({
        for (final entry in map.entries)
          if (entry.value is String) entry.key: entry.value as String,
      });
}

/// Every slot name in an adventure, in a stable order.
///
/// The server asks Gemini for exactly these keys. Generating the list from the
/// adventure means a new character or a new line is automatically offered for
/// rewriting, with no second list to remember to update.
List<String> slotNamesFor(Adventure adventure) => [
  'title',
  'intro',
  'objective',
  for (final person in adventure.characters) ...[
    'char.${person.id}.name',
    'char.${person.id}.role',
    for (final node in person.nodes) ...[
      for (var i = 0; i < node.lines.length; i++)
        'node.${person.id}.${node.id}.line.$i',
      for (final choice in node.choices) ...[
        'choice.${person.id}.${node.id}.${choice.id}.text',
        if (choice.reply != null)
          'choice.${person.id}.${node.id}.${choice.id}.reply',
      ],
    ],
  ],
  for (final request in adventure.market.requests)
    'request.${request.id}.label',
  for (final stall in adventure.market.stalls) 'stall.${stall.id}.keeperLine',
  'mystery.question',
  'mystery.reveal',
  'mystery.wrongLocation',
  'mystery.wrongClues',
  for (final clue in adventure.mystery.clues) 'clue.${clue.id}.text',
  for (final step in adventure.quests) ...[
    'quest.${step.id}.title',
    'quest.${step.id}.detail',
    if (step.hint != null) 'quest.${step.id}.hint',
  ],
  for (final ending in adventure.endings) ...[
    'ending.${ending.id}.title',
    'ending.${ending.id}.text',
    'ending.${ending.id}.celebration',
  ],
];

/// Builds a new adventure from the template, the plan and the words.
///
/// Note what is copied unchanged: every requirement, every effect, every price,
/// the starting coins, the hotspot positions, the clue relationships, the
/// mystery solution, the slot rules and the ending conditions. Only strings and
/// the sold-out item change.
Adventure applyVariation({
  required String id,
  Adventure base = kPongalAdventure,
  AdventureTextPack text = AdventureTextPack.empty,
  VariationPlan plan = VariationPlan.standard,
  AdventureSource source = AdventureSource.generated,
  DateTime? createdAt,
}) {
  String pick(String slot, String original) => text[slot] ?? original;

  return Adventure(
    id: id,
    source: source,
    createdAt: createdAt ?? DateTime.now(),
    title: pick('title', base.title),
    intro: pick('intro', base.intro),
    objective: pick('objective', base.objective),
    startLocationId: base.startLocationId,
    locations: base.locations,
    items: base.items,
    culturalNote: base.culturalNote,

    characters: [
      for (final person in base.characters)
        AdventureCharacter(
          id: person.id,
          name: pick('char.${person.id}.name', person.name),
          role: pick('char.${person.id}.role', person.role),
          locationId: person.locationId,
          icon: person.icon,
          color: person.color,
          nodes: [
            for (final node in person.nodes)
              DialogueNode(
                id: node.id,
                requires: node.requires,
                onEnter: node.onEnter,
                isKeyMoment: node.isKeyMoment,
                lines: [
                  for (var i = 0; i < node.lines.length; i++)
                    pick(
                      'node.${person.id}.${node.id}.line.$i',
                      node.lines[i],
                    ),
                ],
                choices: [
                  for (final choice in node.choices)
                    DialogueChoice(
                      id: choice.id,
                      requires: choice.requires,
                      effect: choice.effect,
                      goTo: choice.goTo,
                      isDecision: choice.isDecision,
                      text: pick(
                        'choice.${person.id}.${node.id}.${choice.id}.text',
                        choice.text,
                      ),
                      reply: choice.reply == null
                          ? null
                          : pick(
                              'choice.${person.id}.${node.id}.'
                              '${choice.id}.reply',
                              choice.reply!,
                            ),
                    ),
                ],
              ),
          ],
        ),
    ],

    market: MarketConfig(
      startingCoins: base.market.startingCoins,
      completedFlag: base.market.completedFlag,
      stalls: [
        for (final stall in base.market.stalls)
          MarketStall(
            id: stall.id,
            name: stall.name,
            icon: stall.icon,
            color: stall.color,
            itemIds: stall.itemIds,
            keeperLine: pick('stall.${stall.id}.keeperLine', stall.keeperLine),
            // The one mechanical change, and only from the checked list.
            soldOutItemIds: stall.itemIds.contains(plan.soldOutItemId)
                ? {plan.soldOutItemId}
                : const {},
          ),
      ],
      requests: [
        for (final request in base.market.requests)
          MarketRequest(
            id: request.id,
            acceptedItemIds: request.acceptedItemIds,
            label: pick('request.${request.id}.label', request.label),
          ),
      ],
    ),

    mystery: MysteryConfig(
      solvedFlag: base.mystery.solvedFlag,
      decorationItemId: base.mystery.decorationItemId,
      candidateLocationIds: base.mystery.candidateLocationIds,
      solutionLocationId: base.mystery.solutionLocationId,
      supportingClueIds: base.mystery.supportingClueIds,
      question: pick('mystery.question', base.mystery.question),
      revealText: pick('mystery.reveal', base.mystery.revealText),
      wrongLocationHint: pick(
        'mystery.wrongLocation',
        base.mystery.wrongLocationHint,
      ),
      wrongCluesHint: pick('mystery.wrongClues', base.mystery.wrongCluesHint),
      clues: [
        for (final clue in base.mystery.clues)
          Clue(
            id: clue.id,
            icon: clue.icon,
            source: clue.source,
            text: pick('clue.${clue.id}.text', clue.text),
          ),
      ],
    ),

    preparation: base.preparation,

    quests: [
      for (final step in base.quests)
        QuestStep(
          id: step.id,
          activeWhen: step.activeWhen,
          doneWhen: step.doneWhen,
          title: pick('quest.${step.id}.title', step.title),
          detail: pick('quest.${step.id}.detail', step.detail),
          hint: step.hint == null
              ? null
              : pick('quest.${step.id}.hint', step.hint!),
        ),
    ],

    endings: [
      for (final ending in base.endings)
        Ending(
          id: ending.id,
          requires: ending.requires,
          color: ending.color,
          icon: ending.icon,
          title: pick('ending.${ending.id}.title', ending.title),
          text: pick('ending.${ending.id}.text', ending.text),
          celebration: pick(
            'ending.${ending.id}.celebration',
            ending.celebration,
          ),
        ),
    ],
  );
}
