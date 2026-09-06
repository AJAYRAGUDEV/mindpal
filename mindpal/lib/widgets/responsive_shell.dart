import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Keeps the app looking like a phone app when it is opened on a laptop.
///
/// This is a demo of a mobile product. Stretched across a 1920px browser the
/// layout would look wrong — 100-character lines of body text, buttons a metre
/// wide, and an elder-friendly design that suddenly reads as a web dashboard.
///
/// So on a wide screen the app is centred in a phone-sized column with a soft
/// frame around it. On an actual phone or a narrow window the frame disappears
/// completely and the app fills the screen as normal.
///
/// The important detail is the MediaQuery override. Constraining the width with
/// a SizedBox alone would leave `MediaQuery.sizeOf(context)` reporting the full
/// browser width, so any widget sizing itself as a fraction of the screen — the
/// chat bubbles, for one — would spill outside the frame. Overriding the size
/// makes the app genuinely believe it is on a narrow device.
class ResponsiveShell extends StatelessWidget {
  const ResponsiveShell({super.key, required this.child});

  final Widget child;

  /// Below this, the browser window is already phone-shaped: no frame.
  static const double _frameBreakpoint = 620;

  /// A comfortable large-phone width. Wide enough for the 64dp touch targets
  /// and 20sp body text this app is built around.
  static const double _appWidth = 430;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    if (media.size.width < _frameBreakpoint) return child;

    // Leave breathing room top and bottom on a laptop, but never so much that
    // the app has to scroll the page itself.
    final frameHeight = media.size.height.clamp(0.0, 940.0);

    return ColoredBox(
      // A darker ground than the app so the phone frame reads as a device
      // sitting on a surface, rather than as a floating white box.
      color: const Color(0xFF0E1A18),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: _appWidth,
            maxHeight: frameHeight,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(28),
              ),
              child: MediaQuery(
                // Tell the app it is on a narrow device.
                data: media.copyWith(
                  size: Size(_appWidth, frameHeight),
                  // Inside the frame there is no notch and no system bar, so
                  // the padding the browser reports would push content
                  // inwards for no reason.
                  padding: EdgeInsets.zero,
                  viewPadding: EdgeInsets.zero,
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
