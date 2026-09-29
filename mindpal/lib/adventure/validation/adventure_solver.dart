import '../engine/adventure_engine.dart';
import '../engine/adventure_state.dart';
import '../model/adventure.dart';

/// What an exhaustive play of an adventure found.
class SolveReport {
  const SolveReport({
    required this.statesExplored,
    required this.reachableEndings,
    required this.unreachableEndings,
    required this.exhausted,
    this.examplePath = const [],
  });

  final int statesExplored;

  /// Every ending id the search actually reached.
  final Set<String> reachableEndings;

  /// Endings the search could not reach. Non-empty means either the adventure
  /// really cannot produce them, or the search ran out of budget — [exhausted]
  /// says which, and a caller must not read one as the other.
  final Set<String> unreachableEndings;

  /// True when every search that failed to find its ending had first covered
  /// the entire reachable game. Only then is "not reachable" a fact rather
  /// than an absence of evidence.
  final bool exhausted;

  /// One real route from the start to an ending, as the labels of the actions
  /// taken. Not the shortest — this search is guided, not optimal — but a
  /// genuine playable path, which is what the tests print.
  final List<String> examplePath;

  bool get isCompletable => reachableEndings.isNotEmpty;

  /// True only when the search covered everything and found no way to finish.
  bool get provedUnfinishable =>
      exhausted && reachableEndings.isEmpty;
}

/// Plays an adventure to prove it can be finished, and that every ending can
/// actually happen.
///
/// **Why this exists.** Gemini writes adventures. A generated adventure that
/// reads beautifully and cannot be completed — an item nobody can buy, a clue
/// nobody can find, a door whose key is behind that door — is worse than no
/// adventure at all, because the player only discovers it after ten minutes of
/// trying. Structural checks (`AdventureValidator`) catch dangling ids; only
/// actually playing it catches an unwinnable arrangement of valid pieces.
///
/// It walks the reachable state space through
/// [AdventureEngine.availableActions] — the same list the UI offers, so the
/// thing being proved is the game people actually play.
///
/// **One guided search per ending.** The obvious approach, a single
/// breadth-first sweep, does not survive the shopping: six buyable things make
/// sixty-four baskets, and multiplied by the flags, clues and placements that
/// is hundreds of thousands of positions before the search reaches the
/// courtyard. Instead each ending gets its own depth-first search, ordered by
/// how close a position is to that particular ending. Nothing is ever pruned —
/// the ordering decides only what is looked at first — so an adventure that can
/// be finished is still found, and one that cannot is still explored in full
/// before being called broken.
class AdventureSolver {
  const AdventureSolver({this.stateCap = 40000, this.dialogueDepth = 12});

  /// Positions per ending. The point is to fail fast on something pathological
  /// rather than to bound a normal search: the bundled adventure settles each
  /// ending in a few thousand.
  final int stateCap;

  /// How deep one conversation may be followed. Dialogue is a graph and could
  /// in principle loop, so a single conversation is bounded separately from the
  /// walk through the game.
  final int dialogueDepth;

  SolveReport solve(Adventure adventure) {
    final engine = AdventureEngine(adventure);

    final reached = <String>{};
    final unreachable = <String>{};
    var explored = 0;
    var exhausted = true;
    var examplePath = const <String>[];

    for (final ending in adventure.endings) {
      if (reached.contains(ending.id)) continue;

      final result = _search(engine, adventure, target: ending);
      explored += result.explored;
      reached.addAll(result.endings);

      if (!result.endings.contains(ending.id)) {
        unreachable.add(ending.id);
        // Only a search that ran to completion proves anything negative.
        if (!result.exhausted) exhausted = false;
      }
      if (examplePath.isEmpty && result.path.isNotEmpty) {
        examplePath = result.path;
      }
    }

    return SolveReport(
      statesExplored: explored,
      reachableEndings: reached,
      unreachableEndings: unreachable,
      exhausted: exhausted,
      examplePath: examplePath,
    );
  }

  /// Every ending the adventure can actually produce.
  Set<String> reachableEndings(Adventure adventure) =>
      solve(adventure).reachableEndings;

  ({int explored, Set<String> endings, bool exhausted, List<String> path})
  _search(
    AdventureEngine engine,
    Adventure adventure, {
    required Ending target,
  }) {
    final start = engine.newGame();
    final seen = <String>{start.signature};
    final stack = <(AdventureState, List<String>)>[(start, const [])];
    final endings = <String>{};
    var explored = 0;
    var path = const <String>[];

    // What this particular search is steering towards.
    final wantedFlags = target.requires.flags;
    final wantedItems = target.requires.items;
    final wantedClues = target.requires.clues;

    int score(AdventureState state) {
      var value =
          state.flags.length +
          state.clues.length * 2 +
          state.ownedItemIds.length * 2 +
          state.placed.length * 3 +
          (state.styleId == null ? 0 : 3);

      // A large bonus for whatever this ending needs, so the second search
      // goes looking for the decision the first one happened not to make.
      for (final flag in wantedFlags) {
        if (state.flags.contains(flag)) value += 20;
      }
      for (final item in wantedItems) {
        if (state.hasItem(item)) value += 20;
      }
      for (final clue in wantedClues) {
        if (state.clues.contains(clue)) value += 20;
      }
      if (state.endingId == target.id) value += 200;
      if (state.isFinished) value += 50;
      return value;
    }

    while (stack.isNotEmpty) {
      if (explored >= stateCap) {
        return (
          explored: explored,
          endings: endings,
          exhausted: false,
          path: path,
        );
      }

      final (state, taken) = stack.removeLast();
      explored++;

      if (state.isFinished) {
        endings.add(state.endingId!);
        if (path.isEmpty) path = taken;
        if (state.endingId == target.id) {
          return (
            explored: explored,
            endings: endings,
            exhausted: false,
            path: path.isEmpty ? taken : path,
          );
        }
        continue;
      }

      // Pushed least-promising first, so the most promising is on top.
      final successors = <(AdventureState, List<String>)>[];
      for (final action in engine.availableActions(state)) {
        for (final next in _outcomesOf(engine, state, action)) {
          if (!seen.add(next.signature)) continue;
          successors.add((next, [...taken, action.label]));
        }
      }
      successors.sort((a, b) => score(a.$1).compareTo(score(b.$1)));
      stack.addAll(successors);
    }

    return (explored: explored, endings: endings, exhausted: true, path: path);
  }

  /// The states one action can lead to.
  ///
  /// Everything except talking has exactly one outcome. A conversation can have
  /// many, because the player picks replies — so it is expanded into one
  /// outcome per way through it.
  List<AdventureState> _outcomesOf(
    AdventureEngine engine,
    AdventureState state,
    AvailableAction action,
  ) {
    switch (action.kind) {
      case ActionKind.move:
        return [engine.moveTo(state, action.targetId ?? '')];

      case ActionKind.inspect:
        return [engine.inspect(state, action.id).state];

      case ActionKind.buy:
        final parts = action.id.split('/');
        return [engine.buy(state, parts.first, parts.last).state];

      case ActionKind.accuse:
        // The solver names each candidate place while offering every clue it
        // has found. A player reasons about which clues support the answer;
        // the solver only has to establish that a correct answer is possible.
        return [engine.accuse(state, action.id, state.clues).state];

      case ActionKind.place:
        final parts = action.id.split('/');
        return [engine.place(state, parts.first, parts.last).state];

      case ActionKind.chooseStyle:
        return [engine.chooseStyle(state, action.id)];

      case ActionKind.finish:
        return [engine.finish(state).state];

      case ActionKind.talk:
        return _conversationOutcomes(engine, state, action.targetId ?? '');
    }
  }

  /// Walks one conversation to its ends.
  List<AdventureState> _conversationOutcomes(
    AdventureEngine engine,
    AdventureState state,
    String characterId,
  ) {
    final opening = engine.openingNode(state, characterId);
    if (opening == null) return const [];

    final results = <AdventureState>[];

    /// [onThisBranch] holds the node ids already walked on this branch. A
    /// conversation that came back to the same line would loop for ever, and
    /// there is nothing to learn from hearing it twice.
    void walk(
      AdventureState current,
      DialogueNode node,
      int depth,
      Set<String> onThisBranch,
    ) {
      if (depth > dialogueDepth || onThisBranch.contains(node.id)) {
        results.add(current);
        return;
      }
      final branch = {...onThisBranch, node.id};

      final entered = engine.enterNode(current, node).state;
      final choices = engine.choicesFor(entered, node);

      if (choices.isEmpty) {
        results.add(entered);
        return;
      }

      for (final choice in choices) {
        final after = engine.choose(entered, choice).state;
        final next = choice.goTo == null
            ? null
            : engine.node(characterId, choice.goTo!);
        if (next == null) {
          results.add(after);
        } else {
          walk(after, next, depth + 1, branch);
        }
      }
    }

    walk(state, opening, 0, const {});
    return results;
  }
}
