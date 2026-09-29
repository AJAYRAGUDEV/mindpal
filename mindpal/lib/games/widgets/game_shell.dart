import 'package:flutter/material.dart';

import '../../l10n/language_scope.dart';
import '../../models/game_settings.dart';
import '../../services/voice/voice_controller.dart';
import '../../theme/app_sizes.dart';
import '../../theme/app_theme.dart';

/// The frame every game sits in, so the controls are in the same place and
/// behave the same way in all of them.
///
/// Before this existed, each game screen built its own AppBar and its own back
/// behaviour. Four games meant four chances for Pause to be missing from one of
/// them — and for a player who has learned where Pause is, missing is worse
/// than never having been there.
///
/// What it guarantees for every game:
///
///  * **Instructions in writing, always on screen.** Not a dialog that must be
///    dismissed before playing and can then never be read again.
///  * **A Listen button**, when the device actually has a voice. When it does
///    not, no button appears — better than a button that silently does nothing.
///  * **Pause, resume, start again and leave**, from one place, with no timer
///    running behind the overlay.
///  * **Leaving always returns the result**, so a game that was played is
///    recorded even when the player walks away from it.
class GameShell extends StatefulWidget {
  const GameShell({
    super.key,
    required this.title,
    required this.instructions,
    required this.child,
    required this.onExit,
    required this.onRestart,
    this.voice,
    this.settings = GameSettings.defaults,
    this.notes = const [],
    this.paused = false,
    this.onPausedChanged,
  });

  final String title;

  /// One or two plain sentences. This is the text the Listen button reads, so
  /// it must make sense heard as well as read — no "tap the button above".
  final String instructions;

  final Widget child;

  /// Leaves the game. The game itself decides what to return.
  final VoidCallback onExit;

  /// Starts the same game over.
  final VoidCallback onRestart;

  /// Null in tests and on devices with no speech engine.
  final VoiceController? voice;

  final GameSettings settings;

  /// Honest notes about this round: an unreviewed content pack, a board that
  /// had to be made smaller than the difficulty asked for. Shown quietly, in
  /// full, rather than hidden.
  final List<GameNote> notes;

  /// Games with a running clock or an animation pass true while paused so this
  /// shell can show the overlay. The game stays responsible for actually
  /// stopping its own timers.
  final bool paused;

  /// Told whenever the player pauses or resumes, so a game with a clock can
  /// stop it. The shell covers the board either way; this is what stops the
  /// pause being charged as playing time.
  final ValueChanged<bool>? onPausedChanged;

  @override
  State<GameShell> createState() => GameShellState();
}

class GameShellState extends State<GameShell> {
  bool _isPaused = false;

  bool get isPaused => _isPaused || widget.paused;

  @override
  void initState() {
    super.initState();
    // Read the instructions aloud only when the player asked for that. A voice
    // starting unbidden is startling, and startling is the opposite of what
    // this screen is for.
    if (widget.settings.spokenInstructions) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _speak());
    }
  }

  void _speak() {
    final voice = widget.voice;
    if (voice == null || !voice.speakerAvailable || !mounted) return;
    voice.speak(widget.instructions, LanguageScope.of(context).language);
  }

  void _togglePause() {
    setState(() => _isPaused = !_isPaused);
    if (_isPaused) widget.voice?.stopSpeaking();
    widget.onPausedChanged?.call(_isPaused);
  }

  @override
  Widget build(BuildContext context) {
    final voice = widget.voice;
    final canListen = voice != null && voice.speakerAvailable;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        // Replaces the default arrow so leaving still hands back the result
        // instead of throwing the session away.
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Leave this game',
          onPressed: () {
            voice?.stopSpeaking();
            widget.onExit();
          },
        ),
        actions: [
          // A word, not a bare symbol. Two of the accessibility notes in this
          // project come back to the same point: an icon alone is guessable,
          // an icon with its word is not.
          TextButton.icon(
            onPressed: _togglePause,
            icon: Icon(
              isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
              size: 26,
            ),
            label: Text(
              isPaused ? 'Resume' : 'Pause',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSizes.pagePadding),
              child: GameBoardLayout(
                header: Column(
                  children: [
                    _InstructionsCard(
                      text: widget.instructions,
                      onListen: canListen ? _speak : null,
                    ),
                    for (final note in widget.notes) ...[
                      const SizedBox(height: AppSizes.gapSmall),
                      _NoteRow(note: note),
                    ],
                  ],
                ),
                board: widget.child,
              ),
            ),
            if (isPaused)
              _PauseOverlay(
                onResume: _togglePause,
                onRestart: () {
                  setState(() => _isPaused = false);
                  widget.onPausedChanged?.call(false);
                  widget.onRestart();
                },
                onLeave: () {
                  voice?.stopSpeaking();
                  widget.onExit();
                },
              ),
          ],
        ),
      ),
    );
  }
}

/// A plain statement about this round that the player is entitled to see.
class GameNote {
  const GameNote(this.text, {this.icon = Icons.info_outline_rounded});

  final String text;
  final IconData icon;
}

class _NoteRow extends StatelessWidget {
  const _NoteRow({required this.note});

  final GameNote note;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(note.icon, size: 22, color: AppColors.textSecondary),
        const SizedBox(width: AppSizes.gapSmall),
        Expanded(
          child: Text(
            note.text,
            style: const TextStyle(fontSize: 16, color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }
}

class _InstructionsCard extends StatelessWidget {
  const _InstructionsCard({required this.text, this.onListen});

  final String text;

  /// Null when this device has no voice. The button is then absent rather than
  /// present and dead.
  final VoidCallback? onListen;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(AppSizes.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text,
            style: const TextStyle(
              fontSize: 20,
              height: 1.35,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          if (onListen != null) ...[
            const SizedBox(height: AppSizes.gapSmall),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: onListen,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, AppSizes.minTouchTarget),
                  side: const BorderSide(color: AppColors.primary, width: 2),
                ),
                icon: const Icon(Icons.volume_up_rounded, size: 26),
                label: const Text(
                  'Read this to me',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Covers the board so nothing can be tapped by accident while paused, and
/// offers the three things a paused player might want.
class _PauseOverlay extends StatelessWidget {
  const _PauseOverlay({
    required this.onResume,
    required this.onRestart,
    required this.onLeave,
  });

  final VoidCallback onResume;
  final VoidCallback onRestart;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        // Nearly opaque, not a light tint: a half-visible board invites taps
        // at something that will not respond.
        color: const Color(0xF2FFFFFF),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSizes.pagePadding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.pause_circle_filled_rounded,
                  size: 88,
                  color: AppColors.primary,
                ),
                const SizedBox(height: AppSizes.gap),
                Text(
                  'Paused',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: AppSizes.gapSmall),
                const Text(
                  'Nothing is running. Take as long as you like.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 19, color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSizes.gapLarge),
                FilledButton.icon(
                  onPressed: onResume,
                  icon: const Icon(Icons.play_arrow_rounded, size: 28),
                  label: const Text('Carry on playing'),
                ),
                const SizedBox(height: AppSizes.gap),
                OutlinedButton.icon(
                  onPressed: onRestart,
                  icon: const Icon(Icons.replay_rounded, size: 26),
                  label: const Text('Start again'),
                ),
                const SizedBox(height: AppSizes.gap),
                OutlinedButton.icon(
                  onPressed: onLeave,
                  icon: const Icon(Icons.home_rounded, size: 26),
                  label: const Text('Leave this game'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A game screen's shape: a header, a board that fills what is left, and an
/// optional footer.
///
/// **Why this exists.** Every game screen is a Column of some fixed rows plus an
/// `Expanded` board. That works until the system font size is turned up — and
/// the people this app is for are exactly the people who turn it up. At twice
/// the normal size the instructions, the score row and the feedback banner grow
/// until they no longer fit, the board is squeezed to nothing, and Flutter
/// reports a RenderFlex overflow: a yellow-and-black stripe across a screen
/// somebody is trying to play a game on. Tests at 2x caught this on all three
/// boards.
///
/// The fix is to cap the header and the footer to a fraction of the height and
/// let each scroll INSIDE ITSELF when its text needs more room. So:
///
///  * at normal text sizes nothing scrolls and nothing looks different — the
///    header asks for less than its cap and gets exactly what it asked for;
///  * at large text sizes the words stay full size and the header becomes a
///    small scrolling area, rather than the board disappearing;
///  * the board itself still never scrolls, which matters for Memory Match —
///    scrolling a memory board would hide the cards the player is trying to
///    remember.
///
/// Clamping the text scale instead would have been two lines. It would also
/// have meant deciding that a low-vision user may not have large text in the
/// one part of the app they came to use.
class GameBoardLayout extends StatelessWidget {
  const GameBoardLayout({
    super.key,
    required this.header,
    required this.board,
    this.footer,
    this.headerFraction = 0.45,
  });

  final Widget header;

  /// Fills whatever is left after the header and footer, and never scrolls.
  final Widget board;

  /// Pinned to the bottom at its natural height, and never scrolled.
  ///
  /// **It must be compact — buttons, not prose.** The footer holds the action
  /// the player needs next, so it is the one thing that must always be
  /// reachable. An earlier version capped it and let it scroll like the header,
  /// and Odd-One-Out's answer explanation pushed "Next question" off the bottom
  /// of the screen: the button was built, so tests found it, but it was outside
  /// the viewport and a tap on it hit nothing. Long explanatory text belongs in
  /// [header] or [board], which do scroll.
  final Widget? footer;

  /// The most of the available height the header may take before it starts
  /// scrolling inside itself.
  final double headerFraction;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;

        // An unbounded height means this is inside something already scrolling.
        // Capping against infinity is meaningless, so lay out plainly.
        if (!height.isFinite) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              header,
              const SizedBox(height: AppSizes.gap),
              board,
              if (footer != null) ...[
                const SizedBox(height: AppSizes.gap),
                footer!,
              ],
            ],
          );
        }

        return Column(
          children: [
            _Capped(maxHeight: height * headerFraction, child: header),
            const SizedBox(height: AppSizes.gap),
            Expanded(child: board),
            if (footer != null) ...[
              const SizedBox(height: AppSizes.gap),
              footer!,
            ],
          ],
        );
      },
    );
  }
}

/// Takes its natural height up to [maxHeight], then scrolls inside itself.
class _Capped extends StatelessWidget {
  const _Capped({required this.maxHeight, required this.child});

  final double maxHeight;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: SingleChildScrollView(
        // Bounces nowhere when the content already fits, so a header that is
        // not too tall does not feel loose.
        physics: const ClampingScrollPhysics(),
        child: child,
      ),
    );
  }
}
