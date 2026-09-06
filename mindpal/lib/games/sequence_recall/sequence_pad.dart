import 'package:flutter/material.dart';

/// One of the big tiles the player watches and then taps.
///
/// Each pad has a colour AND a shape AND a spoken name, so nobody has to tell
/// two pads apart by colour alone.
class SequencePad {
  const SequencePad(this.label, this.icon, this.color);

  final String label;
  final IconData icon;
  final Color color;
}

/// The pad pool. Hard mode uses the first 6; Easy uses the first 4, so the
/// order matters — the four most distinct shapes come first.
///
/// This deliberately does NOT reuse MemorySymbol from the Memory Match folder.
/// Keeping each game's assets inside its own folder means you can redesign one
/// game without touching another, which is worth 15 lines of duplication.
const List<SequencePad> kSequencePads = [
  SequencePad('Blue circle', Icons.circle, Color(0xFF1565C0)),
  SequencePad('Red square', Icons.square, Color(0xFFC62828)),
  SequencePad('Yellow star', Icons.star, Color(0xFF9A6700)),
  SequencePad('Green triangle', Icons.change_history, Color(0xFF2E7D32)),
  SequencePad('Pink heart', Icons.favorite, Color(0xFFAD1457)),
  SequencePad('Purple diamond', Icons.diamond, Color(0xFF5E35B1)),
];
