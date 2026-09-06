import 'package:flutter/material.dart';

import '../sequence_pad.dart';

/// One big pad. Three states:
///   resting  -> solid colour, white shape
///   lit      -> near-white, big coloured shape, thick coloured ring
///   disabled -> resting, but not tappable (while the sequence plays)
///
/// The lit state inverts the colours rather than just brightening them. A
/// subtle glow is easy to miss; a full inversion is unmistakable even with
/// poor contrast vision, and it does not rely on motion.
class SequencePadTile extends StatelessWidget {
  const SequencePadTile({
    super.key,
    required this.pad,
    required this.isLit,
    required this.isEnabled,
    required this.onTap,
  });

  final SequencePad pad;
  final bool isLit;
  final bool isEnabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: pad.label,
      button: true,
      enabled: isEnabled,
      excludeSemantics: true,
      onTap: isEnabled ? onTap : null,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isEnabled ? onTap : null,
          borderRadius: BorderRadius.circular(18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            decoration: BoxDecoration(
              color: isLit ? Colors.white : pad.color,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: pad.color,
                width: isLit ? 6 : 2,
              ),
            ),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Icon(
                    pad.icon,
                    size: 64,
                    color: isLit ? pad.color : Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
