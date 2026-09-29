/// Turns pack content into the shapes the two adapted games already use.
///
/// This file is the ONLY place that knows about both sides. `cultural_pack.dart`
/// holds no game types and the game rules hold no cultural data, so a new pack
/// needs no code and a game redesign needs no content edits. Everything that
/// would otherwise be a bidirectional dependency lives in these forty lines.
library;

import '../../content/cultural_pack.dart';
import '../memory_match/memory_symbol.dart';
import '../odd_one_out/odd_one_out_item.dart';

/// A pack item's kind, expressed as the category the games group by.
///
/// Two enums rather than one is a real cost, paid on purpose: making the
/// content model import the game's enum would mean a pack could not be written
/// without the games, and making the game import the content enum would put
/// cultural data inside the rules. This function is the seam.
ItemCategory categoryFor(ItemKind kind) => switch (kind) {
  ItemKind.instrument => ItemCategory.instrument,
  ItemKind.food => ItemCategory.food,
  ItemKind.craft => ItemCategory.craft,
  ItemKind.farming => ItemCategory.farming,
};

/// Memory Match tiles for a cultural board.
///
/// `pairKey` is the item's id, not its name: two items could be given similar
/// names by a future pack, and matching on the name would let two different
/// objects count as a pair.
List<MemorySymbol> matchTilesFor(CulturalPack pack) => [
  for (final item in pack.items)
    MemorySymbol(
      item.name,
      item.icon,
      item.color,
      matchKey: item.id,
      description: item.description,
      // Facts are shown only after the pair is found, and only from a pack
      // whose facts are allowed to be shown at all — see [factsMayBeShown].
      fact: factsMayBeShown(pack) ? item.fact : null,
    ),
];

/// An Odd-One-Out deck for a cultural board.
OddOneOutDeck deckFor(CulturalPack pack) => OddOneOutDeck(
  packId: pack.id,
  label: pack.title,
  items: [
    for (final item in pack.items)
      OddOneOutItem(
        item.name,
        item.icon,
        categoryFor(item.kind),
        description: item.description,
        fact: factsMayBeShown(pack) ? item.fact : null,
      ),
  ],
);

/// Whether a pack's cultural facts may be shown as statements.
///
/// Currently true for every pack, with the review status shown on screen next
/// to them. It is a single function so that the stricter policy — show facts
/// only from a reviewed pack — is a one-line change here rather than a hunt
/// through the UI:
///
///     bool factsMayBeShown(CulturalPack pack) => pack.review.isReviewed;
///
/// The reason it is not that today: the starter pack is unreviewed, and a demo
/// with no facts at all would hide the feature rather than be honest about it.
/// The app instead labels every unreviewed fact as unchecked, which is the
/// truthful version of showing it.
bool factsMayBeShown(CulturalPack pack) => true;
