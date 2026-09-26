import 'package:flutter/material.dart';

import '../l10n/app_language.dart';
import '../services/voice/speech_output_service.dart';
import '../services/voice/voice_controller.dart';
import '../theme/app_sizes.dart';
import '../theme/app_theme.dart';

/// Play / Pause / Stop / Replay for one spoken answer.
///
/// Sits under the answer it belongs to, so "replay" is unambiguous even when
/// several answers are on screen. Only one of them can be speaking at a time
/// — VoiceController enforces that — so the others simply show Play.
class SpeechControls extends StatelessWidget {
  const SpeechControls({
    super.key,
    required this.voice,
    required this.text,
    required this.language,
  });

  final VoiceController voice;
  final String text;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    if (!voice.speakerAvailable) return const SizedBox.shrink();

    final state = voice.speaking;

    return Padding(
      padding: const EdgeInsets.only(top: AppSizes.gapSmall),
      child: Wrap(
        spacing: AppSizes.gapSmall,
        runSpacing: AppSizes.gapSmall,
        children: [
          if (state == SpeakingState.speaking) ...[
            _SpeechButton(
              icon: Icons.pause_rounded,
              label: 'Pause',
              onTap: voice.pauseSpeaking,
            ),
            _SpeechButton(
              icon: Icons.stop_rounded,
              label: 'Stop',
              onTap: voice.stopSpeaking,
            ),
          ] else ...[
            _SpeechButton(
              icon: Icons.volume_up_rounded,
              label: state == SpeakingState.paused ? 'Continue' : 'Read aloud',
              onTap: () => voice.speak(text, language),
            ),
            if (voice.canReplay)
              _SpeechButton(
                icon: Icons.replay_rounded,
                label: 'Again',
                onTap: () => voice.speak(text, language),
              ),
          ],
        ],
      ),
    );
  }
}

class _SpeechButton extends StatelessWidget {
  const _SpeechButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 24),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 52),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// The one switch that turns automatic reading on and off.
///
/// Separate from the per-answer controls on purpose: a user who finds the
/// voice tiring should be able to silence it everywhere in one tap, without
/// losing the ability to play an individual answer when they want it.
class AutoSpeakToggle extends StatelessWidget {
  const AutoSpeakToggle({super.key, required this.voice});

  final VoiceController voice;

  @override
  Widget build(BuildContext context) {
    if (!voice.speakerAvailable) return const SizedBox.shrink();

    return SwitchListTile.adaptive(
      value: voice.autoSpeak,
      onChanged: (value) => voice.autoSpeak = value,
      contentPadding: EdgeInsets.zero,
      title: const Text(
        'Read answers aloud',
        style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        voice.autoSpeak
            ? 'Answers are read to you automatically.'
            : 'Answers are shown as text. Tap Read aloud to hear one.',
        style: const TextStyle(fontSize: 16, color: AppColors.textSecondary),
      ),
    );
  }
}
