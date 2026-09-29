import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../model/adventure.dart';

/// The picture the player looks at: a place, with things in it to tap.
///
/// **There are no drawn backgrounds or character art.** The scene is painted
/// from two colours and the people and objects are Material icons on coloured
/// discs, each with its name printed underneath. That is a real limitation and
/// the report says so — but it is built so that replacing it with artwork later
/// changes this one file: every hotspot already carries a position, a colour and
/// a label, and nothing else in the game knows how a scene is drawn.
///
/// What it is NOT is a list of buttons. A scene fills the screen, the things in
/// it sit where they belong in the picture, and tapping one is tapping the
/// thing itself.
class AdventureScene extends StatelessWidget {
  const AdventureScene({
    super.key,
    required this.location,
    required this.hotspots,
    required this.onTap,
    this.highlight = false,
    this.reducedMotion = false,
  });

  final AdventureLocation location;

  /// Only what the player can currently see — the engine decides that.
  final List<Hotspot> hotspots;

  final void Function(Hotspot spot) onTap;

  /// Relaxed play draws a soft ring around everything that can be tapped, so
  /// nobody has to hunt for what to do next.
  final bool highlight;

  final bool reducedMotion;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;

        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                location.skyColor,
                location.skyColor,
                location.groundColor,
                location.groundColor,
              ],
              stops: const [0, 0.52, 0.62, 1],
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                // The horizon, so the two colours read as a place rather than
                // a gradient.
                Positioned(
                  left: 0,
                  right: 0,
                  top: height * 0.57,
                  child: Container(height: 2, color: Colors.black12),
                ),

                for (final spot in hotspots)
                  _HotspotMarker(
                    key: ValueKey(spot.id),
                    spot: spot,
                    left: spot.x * width,
                    top: spot.y * height,
                    highlight: highlight,
                    reducedMotion: reducedMotion,
                    onTap: () => onTap(spot),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// One tappable thing, centred on its point in the scene.
class _HotspotMarker extends StatelessWidget {
  const _HotspotMarker({
    super.key,
    required this.spot,
    required this.left,
    required this.top,
    required this.highlight,
    required this.reducedMotion,
    required this.onTap,
  });

  final Hotspot spot;
  final double left;
  final double top;
  final bool highlight;
  final bool reducedMotion;
  final VoidCallback onTap;

  static const double _size = 62;
  static const double _labelWidth = 116;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: (left - _labelWidth / 2).clamp(0.0, double.infinity),
      top: (top - _size / 2).clamp(0.0, double.infinity),
      width: _labelWidth,
      child: Semantics(
        button: true,
        label: spot.label,
        excludeSemantics: true,
        onTap: onTap,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Disc(
                    spot: spot,
                    highlight: highlight,
                    reducedMotion: reducedMotion,
                  ),
                  const SizedBox(height: 4),
                  // The name is always there. Nothing in this game is a
                  // guess-the-picture puzzle, and these pictures are icons.
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      spot.label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The coloured disc a hotspot is drawn on, with its attention ring.
///
/// **The ring is steady, not pulsing.** The first version breathed slowly on a
/// repeating animation, which was a mistake twice over: a permanently moving
/// thing on screen is exactly what the "less movement" setting exists to remove,
/// and an animation that never ends means the widget tree never settles, so
/// every test that waited for it hung. A still ring is calmer and just as easy
/// to find.
class _Disc extends StatelessWidget {
  const _Disc({
    required this.spot,
    required this.highlight,
    required this.reducedMotion,
  });

  final Hotspot spot;
  final bool highlight;
  final bool reducedMotion;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _HotspotMarker._size,
      height: _HotspotMarker._size,
      decoration: BoxDecoration(
        color: spot.color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          if (highlight)
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.9),
              spreadRadius: 4,
            ),
          const BoxShadow(
            color: Colors.black26,
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Icon(spot.icon, size: 32, color: Colors.white),
    );
  }
}
