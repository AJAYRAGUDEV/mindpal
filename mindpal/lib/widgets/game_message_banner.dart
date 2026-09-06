import 'package:flutter/material.dart';

import '../theme/app_sizes.dart';
import '../theme/app_theme.dart';

/// How a message should feel.
enum MessageTone { neutral, positive, negative }

/// The single line of feedback a game shows: "Good match!", "Try again."
///
/// Two accessibility decisions here:
///
/// 1. The banner never disappears — it always shows *something*. A message
///    that pops in and out is easy to miss and makes the layout jump.
/// 2. Tone is carried by an icon AND wording, not just colour.
class GameMessageBanner extends StatelessWidget {
  const GameMessageBanner({
    super.key,
    required this.message,
    this.tone = MessageTone.neutral,
  });

  final String message;
  final MessageTone tone;

  Color get _color => switch (tone) {
    MessageTone.neutral => AppColors.textSecondary,
    MessageTone.positive => const Color(0xFF1B5E20),
    MessageTone.negative => AppColors.reminder,
  };

  IconData get _icon => switch (tone) {
    MessageTone.neutral => Icons.info_outline_rounded,
    MessageTone.positive => Icons.check_circle_outline_rounded,
    MessageTone.negative => Icons.refresh_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return Semantics(
      // liveRegion tells TalkBack to read the new text out as soon as it
      // changes, without the user having to go looking for it.
      liveRegion: true,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 60),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSizes.radius),
          border: Border.all(color: _color, width: 2),
        ),
        child: Row(
          children: [
            Icon(_icon, color: _color, size: 28),
            const SizedBox(width: AppSizes.gapSmall),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: _color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
