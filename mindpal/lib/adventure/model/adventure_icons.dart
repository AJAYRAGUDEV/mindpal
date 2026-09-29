/// The pictures an adventure may use, by name.
///
/// **Why a registry instead of saving the code point.** The first version wrote
/// `icon.codePoint` into the saved JSON and rebuilt `IconData` from the number.
/// It worked in tests and in debug, and then the release build refused to
/// compile:
///
///     This application cannot tree shake icons fonts. It has non-constant
///     instances of IconData at the following locations: ...
///
/// Flutter can only strip the unused 99% of the Material icon font if every
/// `IconData` is a compile-time constant it can see. One built from a variable
/// makes the whole font un-shakeable, and the build fails rather than shipping
/// 1.6MB of glyphs.
///
/// So an adventure stores a NAME, and a name is looked up in this table of
/// const values. Three things follow, all of them good:
///
///  * the release build tree-shakes the font as it always did;
///  * a generated or saved adventure can only name a picture that exists here,
///    so it cannot ask for a glyph that renders as an empty box;
///  * the set of pictures the game can draw is a list somebody can read.
///
/// An unknown name falls back to a question mark rather than failing, because a
/// saved adventure from a future version should still open.
library;

import 'package:flutter/material.dart';

/// Every picture, by the name that is written into saved data.
///
/// Names are descriptive rather than mechanical (`pot`, not
/// `soup_kitchen_rounded`), so the saved file reads as content and a picture
/// can be swapped for a better one without rewriting old saves.
const Map<String, IconData> kAdventureIcons = {
  // people
  'person': Icons.person_rounded,
  'woman': Icons.face_3_rounded,
  'woman_2': Icons.face_2_rounded,
  'man': Icons.face_6_rounded,
  'boy': Icons.face_rounded,

  // places and ways between them
  'village': Icons.holiday_village_rounded,
  'market': Icons.storefront_rounded,
  'courtyard': Icons.deck_rounded,
  'home': Icons.home_rounded,
  'place': Icons.place_rounded,
  'well': Icons.water_drop_rounded,
  'fire': Icons.local_fire_department_rounded,

  // things
  'pot': Icons.soup_kitchen_rounded,
  'brass_pot': Icons.emoji_food_beverage_rounded,
  'rice': Icons.rice_bowl_rounded,
  'sweet': Icons.cookie_rounded,
  'cake': Icons.bakery_dining_rounded,
  'milk': Icons.local_drink_rounded,
  'cane': Icons.grass_rounded,
  'stencil': Icons.grid_on_rounded,
  'basket': Icons.shopping_basket_rounded,
  'boards': Icons.dashboard_rounded,
  'bundle': Icons.inventory_2_rounded,

  // the mystery
  'clue': Icons.search_rounded,
  'dawn': Icons.wb_twilight_rounded,

  // arrangements and endings
  'bright': Icons.brightness_5_rounded,
  'colour': Icons.palette_rounded,
  'lamp': Icons.light_rounded,
  'celebration': Icons.celebration_rounded,
  'sun': Icons.wb_sunny_rounded,
  'sparkle': Icons.auto_awesome_rounded,
  'story': Icons.auto_stories_rounded,
  'trophy': Icons.emoji_events_rounded,

  // fallback
  'unknown': Icons.help_outline_rounded,
};

/// The picture for a saved name.
IconData adventureIcon(String? name) =>
    kAdventureIcons[name] ?? Icons.help_outline_rounded;

/// The name to save for a picture.
///
/// Built once, lazily, by turning the table round. A picture that somehow is
/// not in the table saves as `unknown`, which draws a question mark — visible,
/// harmless, and obviously wrong rather than quietly wrong.
String adventureIconName(IconData icon) =>
    _namesByIcon[icon.codePoint] ?? 'unknown';

final Map<int, String> _namesByIcon = {
  for (final entry in kAdventureIcons.entries) entry.value.codePoint: entry.key,
};
