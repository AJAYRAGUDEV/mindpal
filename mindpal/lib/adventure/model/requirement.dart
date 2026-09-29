/// A condition on the player's state, and a change to it.
///
/// These two little classes are the whole rule language of Festival Quest.
/// Every door, every line of dialogue, every purchase and both endings are
/// expressed as "this [Requirement] must hold" and "this [Effect] happens".
///
/// **Why so small a vocabulary.** The adventure content can be written by
/// Gemini, and generated content has to be checkable before anybody plays it.
/// A rule language with loops or arithmetic could express things a validator
/// cannot reason about; this one is finite, so
/// `AdventureValidator` can confirm every id resolves and `AdventureSolver` can
/// prove by exhaustive search that the adventure is completable. The AI writes
/// the WORDS; it can only assemble rules out of these fixed pieces, and it
/// cannot invent a new one halfway through.
library;

import '../engine/adventure_state.dart';

/// Something that must be true before an action is offered.
///
/// All parts must hold at once — it is an AND, never an OR. An empty
/// requirement is always met, which is the common case and why [none] exists.
class Requirement {
  const Requirement({
    this.flags = const {},
    this.notFlags = const {},
    this.items = const {},
    this.notItems = const {},
    this.clues = const {},
    this.minCoins,
  });

  /// Flags that must all be set.
  final Set<String> flags;

  /// Flags that must all be unset. This is how a piece of dialogue stops being
  /// offered once it has been used.
  final Set<String> notFlags;

  /// Items the player must be carrying.
  final Set<String> items;

  /// Items the player must NOT be carrying — used for "you have already given
  /// me that" branches.
  final Set<String> notItems;

  /// Clues that must have been discovered.
  final Set<String> clues;

  final int? minCoins;

  static const Requirement none = Requirement();

  bool get isAlwaysMet =>
      flags.isEmpty &&
      notFlags.isEmpty &&
      items.isEmpty &&
      notItems.isEmpty &&
      clues.isEmpty &&
      minCoins == null;

  bool isMetBy(AdventureState state) {
    for (final flag in flags) {
      if (!state.flags.contains(flag)) return false;
    }
    for (final flag in notFlags) {
      if (state.flags.contains(flag)) return false;
    }
    for (final item in items) {
      if (!state.hasItem(item)) return false;
    }
    for (final item in notItems) {
      if (state.hasItem(item)) return false;
    }
    for (final clue in clues) {
      if (!state.clues.contains(clue)) return false;
    }
    if (minCoins != null && state.coins < minCoins!) return false;
    return true;
  }

  /// Every id this requirement mentions, for the validator to resolve.
  Set<String> get referencedItems => {...items, ...notItems};
  Set<String> get referencedFlags => {...flags, ...notFlags};

  Map<String, dynamic> toMap() => {
    if (flags.isNotEmpty) 'flags': flags.toList(),
    if (notFlags.isNotEmpty) 'notFlags': notFlags.toList(),
    if (items.isNotEmpty) 'items': items.toList(),
    if (notItems.isNotEmpty) 'notItems': notItems.toList(),
    if (clues.isNotEmpty) 'clues': clues.toList(),
    if (minCoins != null) 'minCoins': minCoins,
  };

  factory Requirement.fromMap(Map<String, dynamic>? map) {
    if (map == null) return none;
    return Requirement(
      flags: _stringSet(map['flags']),
      notFlags: _stringSet(map['notFlags']),
      items: _stringSet(map['items']),
      notItems: _stringSet(map['notItems']),
      clues: _stringSet(map['clues']),
      minCoins: (map['minCoins'] as num?)?.toInt(),
    );
  }
}

/// A change to the player's state.
///
/// Applied all at once and in a fixed order (see [AdventureState.apply]), so
/// the same effect always produces the same result — which is what lets the
/// solver search the game tree and the tests assert exact outcomes.
class Effect {
  const Effect({
    this.setFlags = const {},
    this.clearFlags = const {},
    this.addItems = const [],
    this.removeItems = const [],
    this.coins = 0,
    this.revealClues = const {},
    this.goToLocation,
    this.ending,
  });

  final Set<String> setFlags;
  final Set<String> clearFlags;
  final List<String> addItems;
  final List<String> removeItems;

  /// A change to the purse, positive or negative.
  final int coins;

  final Set<String> revealClues;

  /// Moves the player. Used by dialogue that walks them somewhere.
  final String? goToLocation;

  /// Ends the adventure with this ending. The only way an adventure finishes.
  final String? ending;

  static const Effect none = Effect();

  bool get isEmpty =>
      setFlags.isEmpty &&
      clearFlags.isEmpty &&
      addItems.isEmpty &&
      removeItems.isEmpty &&
      coins == 0 &&
      revealClues.isEmpty &&
      goToLocation == null &&
      ending == null;

  Set<String> get referencedItems => {...addItems, ...removeItems};

  Map<String, dynamic> toMap() => {
    if (setFlags.isNotEmpty) 'setFlags': setFlags.toList(),
    if (clearFlags.isNotEmpty) 'clearFlags': clearFlags.toList(),
    if (addItems.isNotEmpty) 'addItems': addItems,
    if (removeItems.isNotEmpty) 'removeItems': removeItems,
    if (coins != 0) 'coins': coins,
    if (revealClues.isNotEmpty) 'revealClues': revealClues.toList(),
    if (goToLocation != null) 'goToLocation': goToLocation,
    if (ending != null) 'ending': ending,
  };

  factory Effect.fromMap(Map<String, dynamic>? map) {
    if (map == null) return none;
    return Effect(
      setFlags: _stringSet(map['setFlags']),
      clearFlags: _stringSet(map['clearFlags']),
      addItems: _stringList(map['addItems']),
      removeItems: _stringList(map['removeItems']),
      coins: (map['coins'] as num?)?.toInt() ?? 0,
      revealClues: _stringSet(map['revealClues']),
      goToLocation: map['goToLocation'] as String?,
      ending: map['ending'] as String?,
    );
  }
}

Set<String> _stringSet(Object? raw) => {
  if (raw is List)
    for (final value in raw)
      if (value is String && value.isNotEmpty) value,
};

List<String> _stringList(Object? raw) => [
  if (raw is List)
    for (final value in raw)
      if (value is String && value.isNotEmpty) value,
];
