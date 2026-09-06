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
  });

  final MemoryCard card;

  /// 1-based position on the board, spoken by TalkBack so a blind user can
  /// keep track of where they are.
  final int position;

  final VoidCallback onTap;

  static const Color _matchedGreen = Color(0xFF1B5E20);
  static const Color _matchedFill = Color(0xFFE3F1E4);

  String get _semanticLabel {
    if (card.isMatched) return 'Card $position, ${card.symbol.label}, matched';
    if (card.isFaceUp) return 'Card $position, ${card.symbol.label}';
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
            duration: const Duration(milliseconds: 180),
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
              child: isRevealed ? _FaceUp(card: card) : const _FaceDown(),
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
  const _FaceUp({required this.card});

  final MemoryCard card;

  @override
  Widget build(BuildContext context) {
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
