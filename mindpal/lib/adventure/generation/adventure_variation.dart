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

import '../content/festival_skin.dart';
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

/// Every slot in an adventure, with the words currently in it.
///
/// **The current text is the important half.** Sending only the slot NAMES was
/// the first version, and it produced exactly what you would expect: asked for
/// `clue.clue_basket.text` with no further information, the model wrote a
/// sentence about the market running out of jaggery. That is not the clue. The
/// mystery still validated — the structure was untouched — and was no longer
/// solvable by reasoning, because its evidence no longer pointed anywhere.
///
/// With the original words in hand the job becomes rewording, which is what
/// "bounded variation" was always supposed to mean.
///
/// Generating this from the adventure means a new character or a new line is
/// automatically offered for rewriting, with no second list to maintain.
Map<String, String> slotTextFor(Adventure adventure) => {
  'title': adventure.title,
  'intro': adventure.intro,
  'objective': adventure.objective,
  for (final person in adventure.characters) ...{
    'char.${person.id}.name': person.name,
    'char.${person.id}.role': person.role,
    for (final node in person.nodes) ...{
      for (var i = 0; i < node.lines.length; i++)
        'node.${person.id}.${node.id}.line.$i': node.lines[i],
      for (final choice in node.choices) ...{
        'choice.${person.id}.${node.id}.${choice.id}.text': choice.text,
        if (choice.reply != null)
          'choice.${person.id}.${node.id}.${choice.id}.reply': choice.reply!,
      },
    },
  },
  for (final request in adventure.market.requests)
    'request.${request.id}.label': request.label,
  for (final stall in adventure.market.stalls)
    'stall.${stall.id}.keeperLine': stall.keeperLine,
  'mystery.question': adventure.mystery.question,
  'mystery.reveal': adventure.mystery.revealText,
  'mystery.wrongLocation': adventure.mystery.wrongLocationHint,
  'mystery.wrongClues': adventure.mystery.wrongCluesHint,
  for (final clue in adventure.mystery.clues)
    'clue.${clue.id}.text': clue.text,
  for (final step in adventure.quests) ...{
    'quest.${step.id}.title': step.title,
    'quest.${step.id}.detail': step.detail,
    if (step.hint != null) 'quest.${step.id}.hint': step.hint!,
  },
  for (final ending in adventure.endings) ...{
    'ending.${ending.id}.title': ending.title,
    'ending.${ending.id}.text': ending.text,
    'ending.${ending.id}.celebration': ending.celebration,
  },
};

/// The slot names, in a stable order. Always the keys of [slotTextFor], so the
/// two can never disagree about what exists.
List<String> slotNamesFor(Adventure adventure) =>
    slotTextFor(adventure).keys.toList();

/// What every item is actually called, so the prompt can talk about "jaggery"
/// rather than leaking `palm_sugar` into a sentence a player reads.
Map<String, String> itemNamesFor(Adventure adventure) => {
  for (final item in adventure.items) item.id: item.name,
};

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
  FestivalSkin? festival,
  AdventureSource source = AdventureSource.generated,
  DateTime? createdAt,
}) {
  // Two layers, in this order: the festival decides what the adventure is
  // about, then generated text rewords whatever the festival left. So asking
  // for a new Bihu adventure rewords Bihu, not Pongal.
  String pick(String slot, String original) =>
      text[slot] ?? festival?.text[slot] ?? original;

  return Adventure(
    id: id,
    source: source,
    createdAt: createdAt ?? DateTime.now(),
    title: pick('title', base.title),
    intro: pick('intro', base.intro),
    objective: pick('objective', base.objective),
    startLocationId: base.startLocationId,
    culturalNote: festival?.culturalNote ?? base.culturalNote,

    // Names and pictures only. Prices, ids and everything mechanical come
    // straight from the skeleton, so the budget proof and the soft-lock guard
    // hold for every festival without being re-established.
    items: [
      for (final item in base.items)
        if (festival?.itemLabels[item.id] case final label?)
          AdventureItem(
            id: item.id,
            price: item.price,
            color: item.color,
            name: label.name,
            description: label.description,
            icon: label.icon,
          )
        else
          item,
    ],

    locations: [
      for (final place in base.locations)
        if (festival?.locationLabels[place.id] case final label?)
          AdventureLocation(
            id: place.id,
            hotspots: place.hotspots,
            skyColor: place.skyColor,
            groundColor: place.groundColor,
            visitFlag: place.visitFlag,
            name: label.name,
            description: label.description,
          )
        else
          place,
    ],

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
            name: festival?.stallNames[stall.id] ?? stall.name,
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
            source: festival?.clueSources[clue.id] ?? clue.source,
            text: pick('clue.${clue.id}.text', clue.text),
          ),
      ],
    ),

    preparation: PreparationConfig(
      readyFlag: base.preparation.readyFlag,
      slots: [
        for (final slot in base.preparation.slots)
          if (festival?.slotLabels[slot.id] case final label?)
            PreparationSlot(
              id: slot.id,
              acceptedItemIds: slot.acceptedItemIds,
              x: slot.x,
              y: slot.y,
              label: label.label,
              filledText: label.filledText,
            )
          else
            slot,
      ],
      styles: [
        for (final style in base.preparation.styles)
          if (festival?.styleLabels[style.id] case final label?)
            DecorationStyle(
              id: style.id,
              color: style.color,
              icon: style.icon,
              name: label.name,
              description: label.description,
            )
          else
            style,
      ],
    ),

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
