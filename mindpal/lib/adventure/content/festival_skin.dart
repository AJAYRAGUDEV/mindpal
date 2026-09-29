import 'package:flutter/material.dart';

import '../model/adventure.dart';

/// One festival's worth of content, laid over the same adventure.
///
/// **What a skin may change: every word and every picture. What it may not
/// change: anything mechanical.** Prices, coin totals, requirements, effects,
/// hotspot positions, clue relationships, the mystery's answer, the slot rules
/// and the ending conditions all come from the skeleton and are copied through
/// untouched.
///
/// That is what makes a second festival cheap and safe. The budget proof, the
/// soft-lock guard and the solver's finding that both endings are reachable were
/// established for the skeleton; a skin cannot invalidate any of them, because
/// there is nowhere here to put a number. The tests run the full validator over
/// every festival anyway.
///
/// The cost is honest and worth naming: two festivals share one plot. Nirmali
/// stands where Ammal stands and wants the same five things in the same order.
/// A genuinely different story needs a different skeleton, not a different
/// skin — but a village preparing for a feast, losing a decoration and finding
/// it again is a shape that fits a great many festivals, and it lets each one
/// be written as content by somebody who knows it rather than as code.
class FestivalSkin {
  const FestivalSkin({
    required this.id,
    required this.name,
    required this.region,
    required this.blurb,
    required this.icon,
    required this.colour,
    required this.culturalNote,
    this.text = const {},
    this.itemLabels = const {},
    this.locationLabels = const {},
    this.slotLabels = const {},
    this.styleLabels = const {},
    this.stallNames = const {},
    this.clueSources = const {},
  });

  /// Stable: it is written into saved progress and finished runs.
  final String id;

  /// "Pongal", "Bohag Bihu". Shown in the chooser.
  final String name;

  final String region;

  /// One line for the chooser, so somebody can tell the two apart before
  /// committing five minutes to one.
  final String blurb;

  final IconData icon;
  final Color colour;

  final CulturalNote culturalNote;

  /// Slot name to replacement text, exactly as the AI variation uses.
  final Map<String, String> text;

  /// Item id to what it is called here, what it is, and its picture. **Never
  /// its price** — prices belong to the skeleton, and the budget proof with
  /// them.
  final Map<String, ({String name, String description, IconData icon})>
  itemLabels;

  final Map<String, ({String name, String description})> locationLabels;

  /// Courtyard slot id to its label and the line shown once it is filled.
  final Map<String, ({String label, String filledText})> slotLabels;

  final Map<String, ({String name, String description})> styleLabels;

  final Map<String, String> stallNames;

  /// Clue id to who or where it came from, for the journal.
  final Map<String, String> clueSources;
}
