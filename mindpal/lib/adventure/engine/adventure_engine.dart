import '../model/adventure.dart';
import '../model/requirement.dart';
import 'adventure_state.dart';

/// How a quest step stands right now.
enum QuestStatus { locked, active, done }

/// One thing the player can do from where they are.
///
/// The engine produces these; the UI draws them. That split is what lets the
/// solver play the game with no screen attached — it asks for the same list of
/// actions a player would see and picks one.
class AvailableAction {
  const AvailableAction({
    required this.kind,
    required this.id,
    required this.label,
    this.targetId,
  });

  final ActionKind kind;
  final String id;
  final String label;
  final String? targetId;
}

enum ActionKind { move, talk, inspect, buy, accuse, place, chooseStyle, finish }

/// What happened when the player did something.
class ActionResult {
  const ActionResult({
    required this.state,
    this.message,
    this.ok = true,
    this.gainedItemIds = const [],
    this.gainedClueIds = const [],
  });

  final AdventureState state;

  /// A sentence for the player. Null when the change speaks for itself.
  final String? message;

  /// False when the action was refused — not enough coins, a wrong accusation.
  /// The state still comes back, possibly changed (a wrong guess is counted),
  /// because **nothing in this game can fail in a way that ends it**.
  final bool ok;

  final List<String> gainedItemIds;
  final List<String> gainedClueIds;
}

/// The rules of Festival Quest.
///
/// Plain Dart with no Flutter import, like every other game in this project. It
/// holds no state of its own: each method takes the current [AdventureState]
/// and returns a new one, so there is exactly one copy of the playthrough in
/// the app and the engine can be driven by a test, by the UI, or by the solver
/// with no difference in behaviour.
///
/// **Everything the AI is not allowed to decide lives here**: what an action
/// costs, whether a purchase is affordable, which clue proves what, when a
/// quest is done, and which ending applies. Generated content supplies words
/// and arrangements of the fixed rule pieces; it never supplies logic.
class AdventureEngine {
  const AdventureEngine(this.adventure);

  final Adventure adventure;

  /// A fresh playthrough.
  AdventureState newGame() {
    final start = AdventureState(
      adventureId: adventure.id,
      locationId: adventure.startLocationId,
      coins: adventure.market.startingCoins,
      startedAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    // Arriving anywhere sets that location's visit flag, including the first.
    return _markVisited(start);
  }

  // ------------------------------------------------------------- moving

  AdventureState moveTo(AdventureState state, String locationId) {
    if (adventure.location(locationId) == null) return state;
    return _markVisited(
      state.copyWith(locationId: locationId, updatedAt: DateTime.now()),
    );
  }

  AdventureState _markVisited(AdventureState state) {
    final place = adventure.location(state.locationId);
    final flag = place?.visitFlag;
    if (flag == null || state.flags.contains(flag)) return state;
    return state.copyWith(flags: {...state.flags, flag});
  }

  // ---------------------------------------------------------- the scene

  /// The hotspots the player can actually see here.
  List<Hotspot> visibleHotspots(AdventureState state) {
    final place = adventure.location(state.locationId);
    if (place == null) return const [];
    return [
      for (final spot in place.hotspots)
        if (spot.visibleWhen.isMetBy(state) && !_isUsedUp(spot, state)) spot,
    ];
  }

  /// A one-shot hotspot disappears once its effect has run. It is recognised by
  /// the flag the effect sets, so there is no separate bookkeeping to keep in
  /// step with the state.
  bool _isUsedUp(Hotspot spot, AdventureState state) {
    if (spot.repeatable) return false;
    if (spot.onInspect.setFlags.isEmpty) return false;
    return spot.onInspect.setFlags.every(state.flags.contains);
  }

  /// Taps an object.
  ActionResult inspect(AdventureState state, String hotspotId) {
    final spot = visibleHotspots(
      state,
    ).where((candidate) => candidate.id == hotspotId).firstOrNull;
    if (spot == null) {
      return ActionResult(state: state, ok: false);
    }

    final before = state;
    final after = state.apply(spot.onInspect);
    return ActionResult(
      state: after,
      message: spot.inspectText,
      gainedItemIds: _newItems(before, after),
      gainedClueIds: _newClues(before, after),
    );
  }

  // --------------------------------------------------------- conversation

  /// The node a character opens with: the first whose requirement is met.
  ///
  /// Ordered most specific first, so a character says the thing that fits where
  /// the player has got to. The validator insists the last node is
  /// unconditional, so nobody can ever be tapped and say nothing.
  DialogueNode? openingNode(AdventureState state, String characterId) {
    final person = adventure.character(characterId);
    if (person == null) return null;
    for (final node in person.nodes) {
      if (node.requires.isMetBy(state)) return node;
    }
    return null;
  }

  DialogueNode? node(String characterId, String nodeId) {
    final person = adventure.character(characterId);
    if (person == null) return null;
    return person.nodes.where((node) => node.id == nodeId).firstOrNull;
  }

  /// Entering a node can itself change things — that is how simply being told
  /// something reveals a clue.
  ActionResult enterNode(AdventureState state, DialogueNode node) {
    final after = state.apply(node.onEnter);
    return ActionResult(
      state: after,
      gainedItemIds: _newItems(state, after),
      gainedClueIds: _newClues(state, after),
    );
  }

  /// The replies available on a node right now.
  List<DialogueChoice> choicesFor(AdventureState state, DialogueNode node) => [
    for (final choice in node.choices)
      if (choice.requires.isMetBy(state)) choice,
  ];

  ActionResult choose(AdventureState state, DialogueChoice choice) {
    final after = state.apply(choice.effect);
    return ActionResult(
      state: choice.isDecision
          ? after.copyWith(decisions: [...after.decisions, choice.id])
          : after,
      message: choice.reply,
      gainedItemIds: _newItems(state, after),
      gainedClueIds: _newClues(state, after),
    );
  }

  // --------------------------------------------------------------- market

  /// What a stall is showing, with the reason anything cannot be bought.
  List<StallEntry> stallEntries(AdventureState state, MarketStall stall) => [
    for (final id in stall.itemIds)
      if (adventure.item(id) != null)
        StallEntry(
          item: adventure.item(id)!,
          soldOut: stall.soldOutItemIds.contains(id),
          // "Affordable" means affordable AND leaving enough for the rest of
          // the list — so the stall shows the same answer the purchase would
          // give, rather than offering a button that then refuses.
          affordable: _canAfford(state, adventure.item(id)!),
          alreadyOwned: state.hasItem(id),
        ),
  ];

  bool _canAfford(AdventureState state, AdventureItem item) {
    if (state.coins < item.price) return false;
    if (state.hasItem(item.id)) return true;
    final after = state.apply(
      Effect(addItems: [item.id], coins: -item.price),
    );
    final needed = remainingBasketCost(after);
    return needed <= after.coins;
  }

  /// Buys one item.
  ///
  /// Every branch that refuses says why, in words the player can act on. A
  /// purchase that would leave the basket unfinishable is NOT refused, because
  /// the engine cannot know what the player intends — the budget is set so that
  /// every request can still be met, and `AdventureValidator` proves it.
  ActionResult buy(AdventureState state, String stallId, String itemId) {
    final stall = adventure.market.stalls
        .where((candidate) => candidate.id == stallId)
        .firstOrNull;
    final item = adventure.item(itemId);

    if (stall == null || item == null || !stall.itemIds.contains(itemId)) {
      return ActionResult(
        state: state,
        ok: false,
        message: 'That is not for sale here.',
      );
    }
    if (stall.soldOutItemIds.contains(itemId)) {
      return ActionResult(
        state: state,
        ok: false,
        message: '${item.name} has sold out. Ask whether anything else '
            'would do.',
      );
    }
    if (state.hasItem(itemId)) {
      return ActionResult(
        state: state,
        ok: false,
        message: 'You already have ${item.name}.',
      );
    }
    if (state.coins < item.price) {
      return ActionResult(
        state: state,
        ok: false,
        message: '${item.name} costs ${item.price} coins and you have '
            '${state.coins}.',
      );
    }

    final after = state
        .apply(Effect(addItems: [itemId], coins: -item.price))
        .copyWith(updatedAt: DateTime.now());

    // The purchase that would strand the player is the one thing the market
    // refuses.
    //
    // Everything on the list is affordable, but not everything in the market
    // is: buying both pots leaves too little for the rice, the milk and the
    // cane, and there is no way to sell anything back. That is a soft lock —
    // the adventure is still running but can no longer be finished — and it
    // was reachable in the shipped design until a test caught it.
    //
    // So a purchase is allowed only while what remains on the list is still
    // affordable afterwards. Every genuinely valid basket is still available;
    // only the ones that end the adventure quietly are not.
    final stillNeeded = remainingBasketCost(after);
    if (stillNeeded > after.coins) {
      return ActionResult(
        state: state,
        ok: false,
        message: 'You will need your coins for the rest of the list. '
            '${item.name} would leave you ${after.coins} when you still need '
            '$stillNeeded.',
      );
    }

    return ActionResult(
      state: _refreshMarketFlag(after),
      message: 'You buy ${item.name} for ${item.price} coins.',
      gainedItemIds: [itemId],
    );
  }

  /// Which requests are satisfied by what the player is carrying.
  List<RequestStatus> requestStatuses(AdventureState state) {
    final owned = state.ownedItemIds;
    return [
      for (final request in adventure.market.requests)
        RequestStatus(
          request: request,
          satisfiedBy: request.acceptedItemIds
              .where(owned.contains)
              .firstOrNull,
        ),
    ];
  }

  bool shoppingComplete(AdventureState state) =>
      requestStatuses(state).every((status) => status.isSatisfied);

  /// Sets the market's completion flag the moment the basket is complete, so a
  /// quest step can depend on it without the player having to hand anything in.
  AdventureState _refreshMarketFlag(AdventureState state) {
    final flag = adventure.market.completedFlag;
    if (!shoppingComplete(state) || state.flags.contains(flag)) return state;
    return state.copyWith(flags: {...state.flags, flag});
  }

  /// The cheapest total that still satisfies every request, from nothing.
  ///
  /// Used by the validator to prove the budget is enough before anybody plays.
  int cheapestBasketCost() => _cheapestFor(const {});

  /// The cheapest total that still satisfies whatever is left on the list.
  ///
  /// Returns -1 when some remaining request cannot be satisfied at any price,
  /// which the validator treats as a broken adventure.
  int remainingBasketCost(AdventureState state) =>
      _cheapestFor(state.ownedItemIds);

  int _cheapestFor(Set<String> owned) {
    var total = 0;
    for (final request in adventure.market.requests) {
      // Already covered by something in the basket.
      if (request.acceptedItemIds.any(owned.contains)) continue;

      var best = -1;
      for (final id in request.acceptedItemIds) {
        final item = adventure.item(id);
        if (item == null || !_isBuyable(id)) continue;
        if (best < 0 || item.price < best) best = item.price;
      }
      if (best < 0) return -1; // no way to satisfy this request at all
      total += best;
    }
    return total;
  }

  bool _isBuyable(String itemId) => adventure.market.stalls.any(
    (stall) =>
        stall.itemIds.contains(itemId) &&
        !stall.soldOutItemIds.contains(itemId),
  );

  // -------------------------------------------------------------- mystery

  /// Names a place and gives the reasons.
  ///
  /// Both halves must be right: the right place for the wrong reasons is not
  /// solving a mystery, it is a lucky guess. A wrong attempt costs nothing but
  /// a count and returns a nudge — the adventure cannot be lost here.
  ActionResult accuse(
    AdventureState state,
    String locationId,
    Set<String> clueIds,
  ) {
    final mystery = adventure.mystery;

    if (locationId != mystery.solutionLocationId) {
      return ActionResult(
        state: state.copyWith(wrongAccusations: state.wrongAccusations + 1),
        ok: false,
        message: mystery.wrongLocationHint,
      );
    }

    // The supporting clues must all be offered. Extra ones are not held
    // against the player: noticing more than you needed is not a mistake.
    final hasSupport = mystery.supportingClueIds.every(clueIds.contains);
    if (!hasSupport) {
      return ActionResult(
        state: state.copyWith(wrongAccusations: state.wrongAccusations + 1),
        ok: false,
        message: mystery.wrongCluesHint,
      );
    }

    final after = state.apply(
      Effect(
        setFlags: {mystery.solvedFlag},
        addItems: [mystery.decorationItemId],
      ),
    );

    return ActionResult(
      state: after,
      message: mystery.revealText,
      gainedItemIds: [mystery.decorationItemId],
    );
  }

  /// The clues found so far, in the order the adventure lists them.
  List<Clue> foundClues(AdventureState state) => [
    for (final clue in adventure.mystery.clues)
      if (state.clues.contains(clue.id)) clue,
  ];

  bool get mysteryClueCount => adventure.mystery.clues.length == 3;

  // ---------------------------------------------------------- preparation

  /// Puts an item in a slot. Tap the item, tap the place — never a drag.
  ActionResult place(AdventureState state, String slotId, String itemId) {
    final slot = adventure.preparation.slots
        .where((candidate) => candidate.id == slotId)
        .firstOrNull;
    if (slot == null) return ActionResult(state: state, ok: false);

    if (!slot.acceptedItemIds.contains(itemId)) {
      return ActionResult(
        state: state,
        ok: false,
        message: 'That does not belong ${slot.label.toLowerCase()}. '
            'Try somewhere else — nothing is lost.',
      );
    }
    if (!state.hasItem(itemId)) {
      return ActionResult(
        state: state,
        ok: false,
        message: 'You are not carrying that.',
      );
    }

    final placed = {...state.placed, slotId: itemId};
    final after = state.copyWith(placed: placed, updatedAt: DateTime.now());

    return ActionResult(
      state: _refreshReadyFlag(after),
      message: slot.filledText,
    );
  }

  /// Takes something back out of a slot. There is always a way back.
  AdventureState unplace(AdventureState state, String slotId) {
    if (!state.placed.containsKey(slotId)) return state;
    final placed = {...state.placed}..remove(slotId);
    final flag = adventure.preparation.readyFlag;
    return state.copyWith(
      placed: placed,
      flags: {...state.flags}..remove(flag),
      updatedAt: DateTime.now(),
    );
  }

  /// Picks how the courtyard looks. **Never wrong.** No requirement, no
  /// validation, no effect on the ending.
  AdventureState chooseStyle(AdventureState state, String styleId) =>
      state.copyWith(styleId: styleId, updatedAt: DateTime.now());

  bool courtyardReady(AdventureState state) =>
      adventure.preparation.slots.every(
        (slot) => state.placed.containsKey(slot.id),
      );

  AdventureState _refreshReadyFlag(AdventureState state) {
    final flag = adventure.preparation.readyFlag;
    if (!courtyardReady(state) || state.flags.contains(flag)) return state;
    return state.copyWith(flags: {...state.flags, flag});
  }

  // --------------------------------------------------------------- ending

  /// The ending that applies to this state — the first whose requirement is
  /// met. The last ending must be unconditional, which the validator enforces,
  /// so this can only return null if the adventure is not finishable yet.
  Ending? endingFor(AdventureState state) {
    for (final ending in adventure.endings) {
      if (ending.requires.isMetBy(state)) return ending;
    }
    return null;
  }

  /// Whether the celebration can begin.
  bool canFinish(AdventureState state) =>
      courtyardReady(state) && state.styleId != null && !state.isFinished;

  ActionResult finish(AdventureState state) {
    if (!canFinish(state)) {
      return ActionResult(
        state: state,
        ok: false,
        message: 'The courtyard is not ready yet.',
      );
    }
    final ending = endingFor(state);
    if (ending == null) {
      return ActionResult(state: state, ok: false);
    }
    return ActionResult(
      state: state.copyWith(endingId: ending.id, updatedAt: DateTime.now()),
      message: ending.celebration,
    );
  }

  // --------------------------------------------------------------- quests

  QuestStatus statusOf(AdventureState state, QuestStep step) {
    if (step.doneWhen.isMetBy(state)) return QuestStatus.done;
    if (step.activeWhen.isMetBy(state)) return QuestStatus.active;
    return QuestStatus.locked;
  }

  /// The journal: everything not still locked, with its status.
  List<({QuestStep step, QuestStatus status})> journal(AdventureState state) => [
    for (final step in adventure.quests)
      if (statusOf(state, step) != QuestStatus.locked)
        (step: step, status: statusOf(state, step)),
  ];

  /// The hint for the first unfinished step, or null when there is nothing
  /// left to do. Hints are always available and never cost anything — they are
  /// counted only so the summary can say whether they were used.
  String? currentHint(AdventureState state) {
    for (final step in adventure.quests) {
      if (statusOf(state, step) == QuestStatus.active) return step.hint;
    }
    return null;
  }

  QuestStep? currentStep(AdventureState state) {
    for (final step in adventure.quests) {
      if (statusOf(state, step) == QuestStatus.active) return step;
    }
    return null;
  }

  // ------------------------------------------------------------- actions

  /// Everything the player could do from here, as data.
  ///
  /// This is what the solver walks. It must list every action the UI offers and
  /// nothing the UI does not, or the proof that an adventure is completable
  /// would be a proof about a different game.
  List<AvailableAction> availableActions(AdventureState state) {
    if (state.isFinished) return const [];

    final actions = <AvailableAction>[];

    for (final spot in visibleHotspots(state)) {
      switch (spot.kind) {
        case HotspotKind.exit:
          actions.add(
            AvailableAction(
              kind: ActionKind.move,
              id: spot.id,
              label: spot.label,
              targetId: spot.targetId,
            ),
          );
        case HotspotKind.character:
          actions.add(
            AvailableAction(
              kind: ActionKind.talk,
              id: spot.id,
              label: spot.label,
              targetId: spot.targetId,
            ),
          );
        case HotspotKind.object:
          actions.add(
            AvailableAction(
              kind: ActionKind.inspect,
              id: spot.id,
              label: spot.label,
            ),
          );
        case HotspotKind.market:
          for (final stall in adventure.market.stalls) {
            for (final entry in stallEntries(state, stall)) {
              if (entry.canBuy) {
                actions.add(
                  AvailableAction(
                    kind: ActionKind.buy,
                    id: '${stall.id}/${entry.item.id}',
                    label: 'Buy ${entry.item.name}',
                    targetId: entry.item.id,
                  ),
                );
              }
            }
          }
        case HotspotKind.accuse:
          for (final locationId in adventure.mystery.candidateLocationIds) {
            actions.add(
              AvailableAction(
                kind: ActionKind.accuse,
                id: locationId,
                label: 'Say it was ${adventure.location(locationId)?.name}',
                targetId: locationId,
              ),
            );
          }
        case HotspotKind.prepare:
          for (final slot in adventure.preparation.slots) {
            if (state.placed.containsKey(slot.id)) continue;
            for (final itemId in slot.acceptedItemIds) {
              if (state.hasItem(itemId)) {
                actions.add(
                  AvailableAction(
                    kind: ActionKind.place,
                    id: '${slot.id}/$itemId',
                    label: 'Put it ${slot.label.toLowerCase()}',
                    targetId: itemId,
                  ),
                );
              }
            }
          }
          if (courtyardReady(state) && state.styleId == null) {
            for (final style in adventure.preparation.styles) {
              actions.add(
                AvailableAction(
                  kind: ActionKind.chooseStyle,
                  id: style.id,
                  label: style.name,
                ),
              );
            }
          }
          if (canFinish(state)) {
            actions.add(
              const AvailableAction(
                kind: ActionKind.finish,
                id: 'finish',
                label: 'Begin the celebration',
              ),
            );
          }
      }
    }

    return actions;
  }

  List<String> _newItems(AdventureState before, AdventureState after) => [
    for (final id in after.ownedItemIds)
      if (!before.hasItem(id)) id,
  ];

  List<String> _newClues(AdventureState before, AdventureState after) => [
    for (final id in after.clues)
      if (!before.clues.contains(id)) id,
  ];
}

/// One line on a stall.
class StallEntry {
  const StallEntry({
    required this.item,
    required this.soldOut,
    required this.affordable,
    required this.alreadyOwned,
  });

  final AdventureItem item;
  final bool soldOut;
  final bool affordable;
  final bool alreadyOwned;

  /// Already having one blocks a second.
  ///
  /// Nothing in Festival Quest needs two of anything, so a second purchase
  /// could only waste coins a player may still need — and it would turn the
  /// inventory into unbounded counts, which is what the solver has to search.
  /// One of each keeps the shopping honest and the proof of completability
  /// cheap.
  bool get canBuy => !soldOut && affordable && !alreadyOwned;

  /// Why it cannot be bought, or null when it can. Shown on the stall, so a
  /// disabled row always explains itself.
  String? get blockedReason {
    if (soldOut) return 'Sold out';
    if (alreadyOwned) return 'Already in your basket';
    if (!affordable) return 'Not enough coins';
    return null;
  }
}

/// One line of the shopping list, and what is covering it.
class RequestStatus {
  const RequestStatus({required this.request, required this.satisfiedBy});

  final MarketRequest request;

  /// The id of the item the player is carrying that meets it, or null.
  final String? satisfiedBy;

  bool get isSatisfied => satisfiedBy != null;
}
