import 'package:flutter/material.dart';

import '../../l10n/language_scope.dart';
import '../../services/voice/voice_controller.dart';
import '../../theme/app_sizes.dart';
import '../../theme/app_theme.dart';

/// Choosing which voice reads things aloud.
///
/// The voices belong to the phone, not to MindPal: what is on offer is whatever
/// the person has installed, so the list is read from the engine every time and
/// is different on every device. Where there is nothing to choose between, this
/// screen says so plainly instead of showing an empty list.
///
/// Every voice has a **Try it** button, because an engine voice name tells
/// nobody anything — the only way to choose a voice is to hear it.
class VoiceScreen extends StatefulWidget {
  const VoiceScreen({super.key, required this.voice});

  final VoiceController voice;

  @override
  State<VoiceScreen> createState() => _VoiceScreenState();
}

class _VoiceScreenState extends State<VoiceScreen> {
  @override
  void initState() {
    super.initState();
    widget.voice.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.voice.removeListener(_onChanged);
    widget.voice.stopSpeaking();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  /// The sample is a real sentence in the language being chosen, not "testing
  /// one two three" — the point is to hear whether this voice is pleasant to
  /// listen to for a whole story.
  static const String _sample =
      'Good morning. The pot is on the fire, and there is a lot to do before '
      'noon.';

  @override
  Widget build(BuildContext context) {
    final language = LanguageScope.of(context).language;
    final voices = widget.voice.voicesFor(language);
    final chosen = widget.voice.chosenVoice;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('The reading voice')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSizes.pagePadding),
          children: [
            if (!widget.voice.speakerAvailable) ...[
              _Note(
                icon: Icons.volume_off_rounded,
                title: 'Nothing can be read aloud on this phone',
                detail: widget.voice.speakerUnavailableReason,
              ),
              const SizedBox(height: AppSizes.gap),
              const Text(
                'Everything MindPal says is always on screen in writing as '
                'well, so nothing is lost.',
                style: TextStyle(fontSize: 18, color: AppColors.textSecondary),
              ),
            ] else if (voices.isEmpty) ...[
              _Note(
                icon: Icons.record_voice_over_outlined,
                title: 'This phone offers one voice for ${language.englishName}',
                detail:
                    'There is nothing to choose between. More voices can be '
                    'added in the phone’s own settings, under speech or '
                    'text-to-speech.',
              ),
              const SizedBox(height: AppSizes.gap),
              _TryRow(
                label: 'Hear the voice you have',
                onTry: () => widget.voice.speak(_sample, language),
              ),
            ] else ...[
              Text(
                'Voices for ${language.englishName}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              const Text(
                'Tap Try it to hear each one, then choose the one you like.',
                style: TextStyle(fontSize: 17, color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSizes.gap),

              _VoiceRow(
                title: 'The usual voice',
                detail: 'Whatever this phone normally uses.',
                selected: chosen == null,
                onChoose: () => widget.voice.useVoice(null),
                onTry: () async {
                  await widget.voice.useVoice(null);
                  if (mounted) await widget.voice.speak(_sample, language);
                },
              ),
              const SizedBox(height: AppSizes.gapSmall),

              for (final voice in voices) ...[
                _VoiceRow(
                  title: voice.label,
                  detail: voice.isOffline
                      ? 'Works with no internet.'
                      : 'Needs an internet connection.',
                  selected: chosen == voice,
                  onChoose: () => widget.voice.useVoice(voice),
                  onTry: () async {
                    await widget.voice.useVoice(voice);
                    if (mounted) await widget.voice.speak(_sample, language);
                  },
                ),
                const SizedBox(height: AppSizes.gapSmall),
              ],

              const SizedBox(height: AppSizes.gap),
              const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 20, color: AppColors.textSecondary),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'A voice that needs the internet will not read anything '
                      'when you are offline. The games and the adventure still '
                      'work; they simply stay quiet.',
                      style: TextStyle(
                        fontSize: 15,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: AppSizes.gapLarge),
            // Where the chosen voice applies. Said out loud so nobody has to
            // discover it.
            const Text(
              'The voice you choose here reads the adventure, the games and '
              'the assistant.',
              style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSizes.gapLarge),
          ],
        ),
      ),
    );
  }
}

class _VoiceRow extends StatelessWidget {
  const _VoiceRow({
    required this.title,
    required this.detail,
    required this.selected,
    required this.onChoose,
    required this.onTry,
  });

  final String title;
  final String detail;
  final bool selected;
  final VoidCallback onChoose;
  final VoidCallback onTry;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$title. $detail ${selected ? "Chosen" : "Not chosen"}',
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onChoose,
          borderRadius: BorderRadius.circular(AppSizes.radius),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: selected ? AppColors.primarySoft : AppColors.surface,
              borderRadius: BorderRadius.circular(AppSizes.radius),
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.border,
                width: selected ? 3 : 1.5,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 28,
                  color: selected ? AppColors.primary : AppColors.textSecondary,
                ),
                const SizedBox(width: AppSizes.gapSmall),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        detail,
                        style: const TextStyle(
                          fontSize: 15,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSizes.gapSmall),
                OutlinedButton.icon(
                  onPressed: onTry,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 52),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  icon: const Icon(Icons.play_arrow_rounded, size: 22),
                  label: const Text('Try it', style: TextStyle(fontSize: 16)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TryRow extends StatelessWidget {
  const _TryRow({required this.label, required this.onTry});

  final String label;
  final VoidCallback onTry;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTry,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, AppSizes.buttonHeight),
      ),
      icon: const Icon(Icons.play_arrow_rounded, size: 26),
      label: Text(label),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radius),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 28, color: AppColors.textSecondary),
          const SizedBox(width: AppSizes.gapSmall),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  detail,
                  style: const TextStyle(
                    fontSize: 17,
                    height: 1.35,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
