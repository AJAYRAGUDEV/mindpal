import 'cultural_pack.dart';
import 'packs/assam_bihu_pack.dart';

/// Every cultural pack the app actually ships with playable content for.
///
/// **One entry, on purpose.** It would be easy to list eight North-Eastern
/// states here and leave seven of them empty, and it would be dishonest: a
/// greyed-out "Manipur" button tells a user we have Manipuri content when we
/// do not. A pack appears in this list only once it has items and stories, so
/// the selector can never offer something that does not open.
///
/// Adding a pack is one file plus one line here. No game changes.
const List<CulturalPack> kCulturalPacks = [kAssamBihuPack];

/// What is genuinely not here yet, said out loud in the selector.
///
/// Kept as plain words rather than a list of half-built packs, because the
/// honest statement is "we have not written these", not "these are coming".
const String kPackCoverageNote =
    'Only Assam is available so far. Other states and communities each need '
    'their own pack, written with someone from that place — MindPal does not '
    'guess at them, and does not use one region’s pack to stand for '
    'another.';

/// The pack a game uses when the player has not chosen one.
const CulturalPack kDefaultPack = kAssamBihuPack;

/// Finds a pack by the id saved in a game result, or null if it is gone.
///
/// Null is a real case: a saved session may name a pack that a later version
/// removed. Callers show the session without a pack name rather than crashing.
CulturalPack? packById(String? id) {
  if (id == null || id.isEmpty) return null;
  for (final pack in kCulturalPacks) {
    if (pack.id == id) return pack;
  }
  return null;
}

/// The pack to PLAY for a saved id: the one named, or the default.
///
/// Every screen that is about to play something resolves the id through here.
/// Home and the hub used to each decide for themselves what a null id meant and
/// disagreed about it — Home said "Everyday things" while the hub dealt the
/// Assam pack. One function, one answer.
///
/// This is not the same question as [packById], which answers "which pack was
/// this old session played with?" and is allowed to say "none".
CulturalPack packFor(String? id) => packById(id) ?? kDefaultPack;
