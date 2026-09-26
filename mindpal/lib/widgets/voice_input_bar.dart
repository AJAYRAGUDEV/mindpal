import 'package:flutter/material.dart';

import '../l10n/app_language.dart';
import '../services/voice/speech_recognition_service.dart';
import '../services/voice/voice_controller.dart';
import '../theme/app_sizes.dart';
import '../theme/app_theme.dart';

/// The microphone button, the listening indicator, and the correction step.
///
/// The correction step is the important part. Speech recognition gets names
/// and medicine words wrong often, and this app's whole purpose is to be
/// trusted about exactly those. So nothing is ever sent straight from the
/// microphone: what was heard appears as ordinary editable text with a Send
/// button, and the user confirms or fixes it first.
class VoiceInputBar extends StatelessWidget {
  const VoiceInputBar({
    super.key,
    required this.voice,
    required this.language,
    required this.onTextReady,
    this.enabled = true,
  });

  final VoiceController voice;
  final AppLanguage language;

  /// Called with the confirmed text, once the user taps Send.
  final ValueChanged<String> onTextReady;

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!voice.micAvailable) {
      return _UnavailableNote(reason: voice.micUnavailableReason);
    }

    final isListening = voice.listening != ListeningState.idle;
    if (isListening) return _ListeningPanel(voice: voice);

    if (voice.heard.trim().isNotEmpty) {
      return _ConfirmPanel(
        voice: voice,
        onSend: onTextReady,
        language: language,
      );
    }

    return _MicButton(
      enabled: enabled,
      onTap: () => _start(context),
    );
  }

  Future<void> _start(BuildContext context) async {
    final block = await voice.checkMic(language);
    if (!context.mounted) return;

    if (block == VoiceBlock.languageUnsupported) {
      _say(
        context,
        'This device cannot listen in ${language.englishName} yet. '
        'You can still type your question.',
      );
      return;
    }
    if (block != VoiceBlock.none) {
      _say(context, voice.micUnavailableReason);
      return;
    }

    // Say what the microphone is for BEFORE the system dialog appears. The
    // OS prompt says only "allow microphone", which is not a reason.
    final agreed = await _explainAndAsk(context);
    if (!agreed || !context.mounted) return;

    final started = await voice.startListening(language);
    if (!started && context.mounted) {
      _say(
        context,
        'The microphone could not start. Please check it is allowed in '
        'Settings, or type your question.',
      );
    }
  }

  /// Shown once per session, before the OS permission dialog.
  Future<bool> _explainAndAsk(BuildContext context) async {
    if (_explained) return true;

    final answer = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Speak your question?',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'MindPal will listen only while you hold the conversation '
              'open, and turns what you say into text you can check before '
              'sending.\n\n'
              'Nothing you say is recorded or saved. Your phone does the '
              'listening.',
              style: TextStyle(fontSize: 19, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Continue'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Not now'),
            ),
          ],
        ),
      ),
    );

    if (answer == true) _explained = true;
    return answer ?? false;
  }

  /// Session-scoped: the OS remembers the real answer, this only stops the
  /// explanation repeating on every tap.
  static bool _explained = false;

  static void _say(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message, style: const TextStyle(fontSize: 18)),
          duration: const Duration(seconds: 5),
        ),
      );
  }
}

class _MicButton extends StatelessWidget {
  const _MicButton({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Speak your question',
      child: SizedBox(
        width: double.infinity,
        height: 72,
        child: FilledButton.icon(
          onPressed: enabled ? onTap : null,
          icon: const Icon(Icons.mic_rounded, size: 34),
          label: const Text(
            'Speak',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

class _ListeningPanel extends StatelessWidget {
  const _ListeningPanel({required this.voice});

  final VoiceController voice;

  @override
  Widget build(BuildContext context) {
    final heard = voice.heard.trim();

    return Container(
      padding: const EdgeInsets.all(AppSizes.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(AppSizes.radius),
        border: Border.all(color: AppColors.primary, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              // Grows with the sound level, so silence looks different from
              // speech. Without this a user cannot tell a dead microphone
              // from one that simply has not heard them.
              _LevelDot(level: voice.soundLevel),
              const SizedBox(width: AppSizes.gapSmall),
              const Expanded(
                child: Text(
                  'Listening…',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.gapSmall),
          Text(
            heard.isEmpty ? 'Go ahead, I am listening.' : heard,
            style: TextStyle(
              fontSize: 20,
              color: heard.isEmpty
                  ? AppColors.textSecondary
                  : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSizes.gap),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: voice.stopListening,
                  icon: const Icon(Icons.stop_rounded, size: 28),
                  label: const Text('Stop'),
                ),
              ),
              const SizedBox(width: AppSizes.gapSmall),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: voice.cancelListening,
                  icon: const Icon(Icons.close_rounded, size: 28),
                  label: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LevelDot extends StatelessWidget {
  const _LevelDot({required this.level});

  final double level;

  @override
  Widget build(BuildContext context) {
    final size = 20 + (level * 18);
    return SizedBox(
      width: 40,
      height: 40,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: size,
          height: size,
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.mic_rounded, size: 16, color: Colors.white),
        ),
      ),
    );
  }
}

/// What was heard, as editable text, with Send.
class _ConfirmPanel extends StatefulWidget {
  const _ConfirmPanel({
    required this.voice,
    required this.onSend,
    required this.language,
  });

  final VoiceController voice;
  final ValueChanged<String> onSend;
  final AppLanguage language;

  @override
  State<_ConfirmPanel> createState() => _ConfirmPanelState();
}

class _ConfirmPanelState extends State<_ConfirmPanel> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.voice.heard.trim());
  }

  @override
  void didUpdateWidget(_ConfirmPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final heard = widget.voice.heard.trim();
    // Only follow the recogniser while the user has not started editing.
    if (heard.isNotEmpty && _controller.text.isEmpty) {
      _controller.text = heard;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radius),
        border: Border.all(color: AppColors.border, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'I heard this. Change it if it is wrong.',
            style: TextStyle(fontSize: 17, color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSizes.gapSmall),
          TextField(
            controller: _controller,
            style: const TextStyle(fontSize: 20),
            maxLines: 3,
            minLines: 1,
            autofocus: false,
          ),
          const SizedBox(height: AppSizes.gap),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    final text = _controller.text.trim();
                    if (text.isEmpty) return;
                    widget.voice.clearHeard();
                    widget.onSend(text);
                  },
                  icon: const Icon(Icons.send_rounded, size: 28),
                  label: const Text('Send'),
                ),
              ),
              const SizedBox(width: AppSizes.gapSmall),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: widget.voice.clearHeard,
                  icon: const Icon(Icons.delete_outline_rounded, size: 28),
                  label: const Text('Discard'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UnavailableNote extends StatelessWidget {
  const _UnavailableNote({required this.reason});

  final String reason;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.mic_off_rounded,
          size: 22,
          color: AppColors.textSecondary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            reason,
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
