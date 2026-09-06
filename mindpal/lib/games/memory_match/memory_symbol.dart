import 'package:flutter/material.dart';

/// One picture that can appear on a memory card.
///
/// Every symbol has a distinct SHAPE as well as a distinct COLOUR. That is
/// deliberate: roughly 1 in 12 men has some colour-vision deficiency, and it
/// becomes more common with age. A player must never need to tell two cards
/// apart by colour alone.
class MemorySymbol {
  const MemorySymbol(this.label, this.icon, this.color);

  /// Read out by TalkBack, and shown under the icon.
  final String label;
  final IconData icon;
  final Color color;
}

/// The pool the game draws from. Everyday objects, not abstract shapes —
/// familiar images are easier to hold in memory.
///
/// Hard mode needs 8, so this list must always have at least 8 entries.
const List<MemorySymbol> kMemorySymbols = [
  MemorySymbol('Sun', Icons.wb_sunny_rounded, Color(0xFFD97706)),
  MemorySymbol('Flower', Icons.local_florist_rounded, Color(0xFFBE185D)),
  MemorySymbol('Cup', Icons.local_cafe_rounded, Color(0xFF6D4C41)),
  MemorySymbol('House', Icons.home_rounded, Color(0xFF1565C0)),
  MemorySymbol('Star', Icons.star_rounded, Color(0xFF9A6700)),
  MemorySymbol('Heart', Icons.favorite_rounded, Color(0xFFC62828)),
  MemorySymbol('Umbrella', Icons.beach_access_rounded, Color(0xFF00838F)),
  MemorySymbol('Key', Icons.vpn_key_rounded, Color(0xFF5D4037)),
  MemorySymbol('Clock', Icons.access_time_filled_rounded, Color(0xFF37474F)),
  MemorySymbol('Bell', Icons.notifications_rounded, Color(0xFF8F5000)),
  MemorySymbol('Car', Icons.directions_car_rounded, Color(0xFF2E7D32)),
  MemorySymbol('Boat', Icons.sailing_rounded, Color(0xFF4527A0)),
];
