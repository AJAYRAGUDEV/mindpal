import 'package:flutter/services.dart';

import '../../models/game_settings.dart';

/// A short sound and a gentle buzz when something is right or wrong.
///
/// **Why the platform's own click and haptics rather than audio files.** No
/// sound assets, no audio package, nothing to bundle, and it works offline on
/// every device — which matters for an app whose games must run with no network
/// at all. It also means the feedback follows whatever the phone is already set
/// to: silent mode stays silent, and a device with no vibrator simply does not
/// buzz.
///
/// What it is not: a chime, a fanfare, or a buzzer. `SystemSoundType.click` is a
/// click. It is enough to confirm that a tap registered — which is the thing a
/// player with reduced hearing or an unsteady hand actually needs — and the
/// settings sheet describes it in those words rather than promising music.
///
/// Every method is a no-op when the player has switched sounds off, and every
/// call is fire-and-forget: feedback must never delay the board redrawing, and a
/// platform that refuses to make a noise must never fail a game.
class GameFeedback {
  const GameFeedback(this.settings);

  final GameSettings settings;

  bool get _on => settings.soundOn;

  /// A pair found, the odd one spotted, a scene placed correctly.
  void good() {
    if (!_on) return;
    SystemSound.play(SystemSoundType.click);
    HapticFeedback.lightImpact();
  }

  /// Not that one. Deliberately the same quiet click as [good] plus a lighter
  /// buzz, not a harsher noise: a game for someone with memory difficulty
  /// should not punish a wrong tap with a sound that feels like a telling-off.
  void notYet() {
    if (!_on) return;
    HapticFeedback.selectionClick();
  }

  /// The whole board finished.
  void finished() {
    if (!_on) return;
    SystemSound.play(SystemSoundType.click);
    HapticFeedback.mediumImpact();
  }
}
