/// Cultural game content, kept completely separate from game rules.
///
/// Nothing in this file knows how any game is played, and no game logic file
/// knows what a dhol is. That split is the point: adding a Manipuri pack means
/// writing one new data file, and fixing a wrong caption means editing data,
/// not code.
///
/// **Why Dart `const` data rather than JSON asset files.** The project already
/// keeps game content this way (`kMemorySymbols`, `kOddOneOutItems`), and const
/// data costs nothing at runtime, cannot fail to parse, and is checked by the
/// compiler — a missing field is a build error today instead of a blank tile in
/// front of a judge. The shapes below are plain data with no behaviour, so a
/// JSON loader can be added later and hand back the same objects without any
/// game changing. What we lose is editability by a non-programmer, which is a
/// real cost and the reason [CulturalPack.review] exists.
library;

import 'package:flutter/material.dart';

/// How far a pack's words and pictures have actually been checked.
///
/// This is the honest part of the model. Facts about someone's culture that
/// nobody from that culture has read are not "content", they are a draft, and
/// the app says so on screen rather than presenting them as established.
enum PackReview {
  /// Read and approved by someone who speaks the language / knows the region.
  reviewed('Checked by a reviewer', Icons.verified_rounded),

  /// Written from published sources but NOT yet signed off by a reviewer.
  /// Playable, and labelled as unchecked wherever its facts are shown.
  pendingReview('Facts not checked yet', Icons.hourglass_bottom_rounded);

  const PackReview(this.label, this.icon);

  final String label;
  final IconData icon;

  bool get isReviewed => this == PackReview.reviewed;
}

/// Where a piece of content came from.
enum ContentOrigin {
  /// A traditional story or practice, recorded from published sources.
  traditional,

  /// Written for MindPal. Depicts real customs, but is not itself a
  /// traditional tale — so the app must never call it one.
  original,
}

/// What kind of thing an item is. Used by Odd-One-Out to build a group with an
/// unambiguous rule ("three of these are instruments, one is food") and by the
/// match game only as a label.
///
/// Every value is a plain, physical category. There is deliberately no
/// "belongs to culture X" grouping: deciding which tradition an object belongs
/// to is contested, and a game is the wrong place to settle it.
enum ItemKind {
  instrument('Musical instruments', 'a musical instrument'),
  food('Food and drink', 'a food'),
  craft('Handmade things', 'a handmade thing'),
  farming('Farming and the land', 'used for farming');

  const ItemKind(this.plural, this.singular);

  /// "Musical instruments" — used in the explanation of an answer.
  final String plural;

  /// "a musical instrument" — used mid-sentence.
  final String singular;
}

/// One culturally specific object a game can show.
class CulturalItem {
  const CulturalItem({
    required this.id,
    required this.name,
    required this.kind,
    required this.icon,
    required this.color,
    required this.description,
    this.fact,
    this.source,
  });

  /// Stable, unique inside a pack. Used as the match key, so two items with
  /// similar names can never be treated as a pair.
  final String id;

  /// Shown on the tile, always. A picture without its name turns every game
  /// into an eyesight test.
  final String name;

  final ItemKind kind;

  /// A stand-in picture, not a photograph — see [CulturalPack.artworkNote].
  final IconData icon;

  /// Tiles differ by name and by symbol first; colour is decoration only, so
  /// nobody has to distinguish two tiles by colour alone.
  final Color color;

  /// Read by TalkBack in place of the icon, and shown under the name on the
  /// larger layouts. One plain sentence, no jargon.
  final String description;

  /// One short sentence offered AFTER a correct answer, never before. Null
  /// when we have nothing worth saying.
  final String? fact;

  /// Where [fact] came from, so a reviewer can check it.
  final String? source;

  bool get hasFact => fact != null && fact!.trim().isNotEmpty;
}

/// One scene in a story the player puts in order.
class StoryScene {
  const StoryScene({
    required this.id,
    required this.caption,
    required this.icon,
    required this.color,
    required this.description,
  });

  final String id;

  /// One short line: "The loom is set up in the morning."
  final String caption;

  final IconData icon;
  final Color color;

  /// For screen readers, in place of the picture.
  final String description;
}

/// A short story told in ordered scenes.
///
/// [scenes] are in the CORRECT order as written. The game shuffles a copy; the
/// source data is always the answer key, so there is one place to look when a
/// sequence seems wrong.
class CulturalStory {
  const CulturalStory({
    required this.id,
    required this.title,
    required this.origin,
    required this.text,
    required this.scenes,
    required this.explanation,
    required this.hint,
    this.attribution,
  });

  final String id;
  final String title;

  /// Traditional tale or written for MindPal. The UI shows this, because
  /// presenting an invented story as folklore would be a lie about a culture.
  final ContentOrigin origin;

  /// The story, to be read or listened to before playing. A few sentences —
  /// long enough to hold the order in mind, short enough to hear twice.
  final String text;

  /// In the correct order.
  final List<StoryScene> scenes;

  /// Why that order is right, in plain language. Shown after a wrong attempt
  /// and on the result screen — a puzzle you got wrong and never understood is
  /// just a failure.
  final String explanation;

  /// One nudge, offered on request and counted.
  final String hint;

  final String? attribution;

  int get sceneCount => scenes.length;
}

/// A complete, self-contained set of cultural content for the games.
class CulturalPack {
  const CulturalPack({
    required this.id,
    required this.title,
    required this.region,
    required this.languageNote,
    required this.review,
    required this.items,
    required this.stories,
    required this.sources,
    required this.artworkNote,
  });

  /// Stable across releases: it is written into saved progress, so renaming it
  /// would orphan every session already recorded against it.
  final String id;

  final String title;

  /// "Assam, North-East India". Named specifically, never "the North East" as
  /// though one pack could stand for eight states.
  final String region;

  /// What language the content is actually written in, said plainly. The app
  /// must not imply a pack is available in a language it is not.
  final String languageNote;

  final PackReview review;

  final List<CulturalItem> items;
  final List<CulturalStory> stories;

  /// Published references a reviewer can check the facts against.
  final List<String> sources;

  /// What the pictures actually are. Honest by design: these are stand-in
  /// symbols from the Material icon set (Apache 2.0), not photographs or
  /// commissioned artwork, and the app says so rather than implying the
  /// pictures are authentic depictions.
  final String artworkNote;

  List<CulturalItem> itemsOfKind(ItemKind kind) =>
      items.where((item) => item.kind == kind).toList();

  /// The kinds this pack can actually build an Odd-One-Out group from: at
  /// least two items, so a group has a majority and an odd one.
  List<ItemKind> get playableKinds => [
    for (final kind in ItemKind.values)
      if (itemsOfKind(kind).length >= 2) kind,
  ];

  /// The largest board Odd-One-Out can honestly fill from this pack.
  ///
  /// A board of nine needs eight items of one kind. Rather than quietly
  /// serving a smaller board than the difficulty promised, the game asks this
  /// and says what it is doing.
  int get largestGroupSize {
    var smallest = 0;
    for (final kind in playableKinds) {
      final count = itemsOfKind(kind).length;
      if (smallest == 0 || count < smallest) smallest = count;
    }
    return smallest == 0 ? 0 : smallest + 1;
  }

  /// Enough distinct items to fill a matching board of [pairs] pairs.
  bool canFillMatchBoard(int pairs) => items.length >= pairs;

  bool get hasStories => stories.isNotEmpty;
}
