import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../memory_card.dart';

/// One tappable square on the board.
///
/// Three visual states, each distinguishable without relying on colour:
///   hidden  -> deep teal, large "?"
///   face up -> white, coloured picture + its name
///   matched -> green tint, picture + a tick
class MemoryCardTile extends StatelessWidget {
  const MemoryCardTile({
    super.key,
    required this.card,
    required this.position,
    required this.onTap,
    this.image,
    this.reducedMotion = false,
  });

  final MemoryCard card;

  /// Already-decoded bytes for a card built from one of the user's own photos.
  ///
  /// Passed in rather than loaded here: the screen reads every photo once
  /// before the board is dealt, so no tile does file I/O while the player is
  /// waiting for it to turn over. Null for every icon card, and also for a
  /// photo whose file has gone missing — in which case the tile falls back to
  /// the icon and its name, and the game carries on.
  final Uint8List? image;

  /// Shortens the reveal fade to nothing. For players who find movement
  /// distracting, and it makes the board feel quicker on an older phone.
  final bool reducedMotion;

  /// 1-based position on the board, spoken by TalkBack so a blind user can
  /// keep track of where they are.
  final int position;

  final VoidCallback onTap;

  static const Color _matchedGreen = Color(0xFF1B5E20);
  static const Color _matchedFill = Color(0xFFE3F1E4);

  String get _semanticLabel {
    // spokenLabel carries the plain description as well as the name, which is
    // what makes a cultural board usable with TalkBack: "Pitha" alone means
    // nothing read out, "Pitha. A cake made from rice flour" does.
    final name = card.symbol.spokenLabel;
    if (card.isMatched) return 'Card $position, $name, matched';
    if (card.isFaceUp) return 'Card $position, $name';
    return 'Card $position, face down';
  }

  @override
  Widget build(BuildContext context) {
    final isRevealed = card.isFaceUp || card.isMatched;

    return Semantics(
      label: _semanticLabel,
      button: !card.isMatched,
      // Hide the icon and its caption from TalkBack: the label above already
      // says both, and without this the card is announced twice.
      excludeSemantics: true,
      // Because excludeSemantics hides the InkWell too, the tap action has to
      // be re-declared here — otherwise a TalkBack user can hear the card but
      // cannot activate it.
      onTap: card.isMatched ? null : onTap,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: card.isMatched ? null : onTap,
          borderRadius: BorderRadius.circular(14),
          // A short, calm colour fade. No flip or bounce animation:
          // fast motion is disorienting and can mask what changed.
          child: AnimatedContainer(
            duration: Duration(milliseconds: reducedMotion ? 0 : 180),
            decoration: BoxDecoration(
              color: card.isMatched
                  ? _matchedFill
                  : (card.isFaceUp ? AppColors.surface : AppColors.primary),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: card.isMatched
                    ? _matchedGreen
                    : (card.isFaceUp
                          ? AppColors.border
                          : AppColors.primaryDark),
                width: card.isMatched ? 3 : 2,
              ),
            ),
            child: Center(
              child: isRevealed
                  ? _FaceUp(card: card, image: image)
                  : const _FaceDown(),
            ),
          ),
        ),
      ),
    );
  }
}

class _FaceDown extends StatelessWidget {
  const _FaceDown();

  @override
  Widget build(BuildContext context) {
    return const FittedBox(
      fit: BoxFit.scaleDown,
      child: Padding(
        padding: EdgeInsets.all(8),
        child: Text(
          '?',
          style: TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _FaceUp extends StatelessWidget {
  const _FaceUp({required this.card, this.image});

  final MemoryCard card;
  final Uint8List? image;

  @override
  Widget build(BuildContext context) {
    final photo = image;
    if (photo != null) {
      return Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.memory(
                photo,
                fit: BoxFit.cover,
                width: double.infinity,
                // A photo that will not decode must not take the board down
                // with it.
                errorBuilder: (_, _, _) =>
                    Icon(card.symbol.icon, size: 40, color: card.symbol.color),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Text(
              card.symbol.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      );
    }

    // FittedBox shrinks the whole group if the tile is small (Hard mode) so
    // nothing ever overflows, whatever the screen size or font setting.
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(card.symbol.icon, size: 44, color: card.symbol.color),
            const SizedBox(height: 4),
            Text(
              card.symbol.label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
