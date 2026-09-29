import 'dart:convert';

import '../model/requirement.dart';

/// Everything about one playthrough that can change.
///
/// Immutable: every change returns a new state. That is what makes the solver
/// possible — it can hold thousands of states at once without any of them
/// quietly mutating — and it means "save the game" is just writing this object
/// out.
class AdventureState {
  AdventureState({
    required this.adventureId,
    required this.locationId,
    this.flags = const {},
    this.inventory = const {},
    this.coins = 0,
    this.clues = const {},
    this.decisions = const [],
    this.placed = const {},
    this.styleId,
    this.endingId,
    this.wrongAccusations = 0,
    this.hintsUsed = 0,
    this.startedAt,
    this.updatedAt,
  });

  final String adventureId;
  final String locationId;

  final Set<String> flags;

  /// itemId to how many are held. A count rather than a set because a player
  /// may buy two of something, and "you already have one" is a rule the market
  /// should not have to invent.
  final Map<String, int> inventory;

  final int coins;
  final Set<String> clues;

  /// The ids of choices marked `isDecision`, in the order they were made.
  /// Shown in the summary at the end so the player can see what shaped it.
  final List<String> decisions;

  /// slotId to the itemId put there.
  final Map<String, String> placed;

  final String? styleId;

  /// Null until the adventure is finished.
  final String? endingId;

  /// Counted, never punished. It is shown in the summary as a fact about the
  /// mystery, and nothing in the game reads it to make anything harder.
  final int wrongAccusations;

  final int hintsUsed;

  final DateTime? startedAt;
  final DateTime? updatedAt;

  bool get isFinished => endingId != null;

  bool hasItem(String id) => (inventory[id] ?? 0) > 0;

  Set<String> get ownedItemIds => {
    for (final entry in inventory.entries)
      if (entry.value > 0) entry.key,
  };

  int countOf(String id) => inventory[id] ?? 0;

  AdventureState copyWith({
    String? locationId,
    Set<String>? flags,
    Map<String, int>? inventory,
    int? coins,
    Set<String>? clues,
    List<String>? decisions,
    Map<String, String>? placed,
    String? styleId,
    String? endingId,
    int? wrongAccusations,
    int? hintsUsed,
    DateTime? updatedAt,
  }) => AdventureState(
    adventureId: adventureId,
    locationId: locationId ?? this.locationId,
    flags: flags ?? this.flags,
    inventory: inventory ?? this.inventory,
    coins: coins ?? this.coins,
    clues: clues ?? this.clues,
    decisions: decisions ?? this.decisions,
    placed: placed ?? this.placed,
    styleId: styleId ?? this.styleId,
    endingId: endingId ?? this.endingId,
    wrongAccusations: wrongAccusations ?? this.wrongAccusations,
    hintsUsed: hintsUsed ?? this.hintsUsed,
    startedAt: startedAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  /// Applies one [Effect] and returns the state that results.
  ///
  /// The order is fixed and matters: items are removed before they are added,
  /// so an effect that swaps one thing for another cannot be defeated by the
  /// order it happens to be written in; and coins are clamped at zero, so no
  /// path can leave the player owing money.
  AdventureState apply(Effect effect) {
    if (effect.isEmpty) return this;

    final nextFlags = {...flags, ...effect.setFlags}
      ..removeAll(effect.clearFlags);

    final nextInventory = {...inventory};
    for (final id in effect.removeItems) {
      final left = (nextInventory[id] ?? 0) - 1;
      if (left <= 0) {
        nextInventory.remove(id);
      } else {
        nextInventory[id] = left;
      }
    }
    for (final id in effect.addItems) {
      nextInventory[id] = (nextInventory[id] ?? 0) + 1;
    }

    final nextCoins = coins + effect.coins;

    return copyWith(
      flags: nextFlags,
      inventory: nextInventory,
      coins: nextCoins < 0 ? 0 : nextCoins,
      clues: {...clues, ...effect.revealClues},
      locationId: effect.goToLocation ?? locationId,
      endingId: effect.ending ?? endingId,
      updatedAt: DateTime.now(),
    );
  }

  /// Computed once and kept, because the solver asks for it on every state it
  /// creates. Building it eagerly in the constructor would pay for states the
  /// search throws away; recomputing it each time cost more than the rest of
  /// the search put together.
  String? _signature;

  /// A short string that identifies this state exactly.
  ///
  /// Used by the solver to recognise a position it has already searched. It
  /// deliberately leaves out the timestamps and the counters that no rule reads
  /// (hints, wrong guesses): including them would make every state look new and
  /// the search would never terminate.
  String get signature => _signature ??= _buildSignature();

  String _buildSignature() {
    final sortedFlags = flags.toList()..sort();
    final sortedItems = inventory.keys.toList()..sort();
    final sortedClues = clues.toList()..sort();
    final sortedSlots = placed.keys.toList()..sort();
    return [
      locationId,
      coins,
      sortedFlags.join(','),
      [for (final id in sortedItems) '$id:${inventory[id]}'].join(','),
      sortedClues.join(','),
      [for (final id in sortedSlots) '$id=${placed[id]}'].join(','),
      styleId ?? '',
      endingId ?? '',
    ].join('|');
  }

  Map<String, dynamic> toMap() => {
    'adventureId': adventureId,
    'locationId': locationId,
    'flags': flags.toList(),
    'inventory': inventory,
    'coins': coins,
    'clues': clues.toList(),
    'decisions': decisions,
    'placed': placed,
    if (styleId != null) 'styleId': styleId,
    if (endingId != null) 'endingId': endingId,
    'wrongAccusations': wrongAccusations,
    'hintsUsed': hintsUsed,
    if (startedAt != null) 'startedAt': startedAt!.toIso8601String(),
    if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
  };

  factory AdventureState.fromMap(Map<String, dynamic> map) => AdventureState(
    adventureId: map['adventureId'] as String? ?? '',
    locationId: map['locationId'] as String? ?? '',
    flags: {
      for (final value in (map['flags'] as List? ?? const []))
        if (value is String) value,
    },
    inventory: {
      for (final entry in (map['inventory'] as Map? ?? const {}).entries)
        if (entry.key is String && entry.value is num)
          entry.key as String: (entry.value as num).toInt(),
    },
    coins: (map['coins'] as num?)?.toInt() ?? 0,
    clues: {
      for (final value in (map['clues'] as List? ?? const []))
        if (value is String) value,
    },
    decisions: [
      for (final value in (map['decisions'] as List? ?? const []))
        if (value is String) value,
    ],
    placed: {
      for (final entry in (map['placed'] as Map? ?? const {}).entries)
        if (entry.key is String && entry.value is String)
          entry.key as String: entry.value as String,
    },
    styleId: map['styleId'] as String?,
    endingId: map['endingId'] as String?,
    wrongAccusations: (map['wrongAccusations'] as num?)?.toInt() ?? 0,
    hintsUsed: (map['hintsUsed'] as num?)?.toInt() ?? 0,
    startedAt: DateTime.tryParse(map['startedAt'] as String? ?? ''),
    updatedAt: DateTime.tryParse(map['updatedAt'] as String? ?? ''),
  );

  String toJson() => jsonEncode(toMap());

  factory AdventureState.fromJson(String source) =>
      AdventureState.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
