import 'package:flutter/material.dart';

import '../../models/game_settings.dart';
import '../../theme/app_sizes.dart';
import '../../theme/app_theme.dart';

/// The accessibility switches for games, as a bottom sheet.
///
/// Returns the new settings, or null when the sheet is dismissed without a
/// change. A sheet rather than a screen because these are adjustments made in
/// passing — the player is on their way to a game, not visiting Settings.
Future<GameSettings?> showGameSettingsSheet(
  BuildContext context, {
  required GameSettings settings,
  required bool canSpeak,
}) {
  return showModalBottomSheet<GameSettings>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _GameSettingsSheet(settings: settings, canSpeak: canSpeak),
  );
}

class _GameSettingsSheet extends StatefulWidget {
  const _GameSettingsSheet({required this.settings, required this.canSpeak});

  final GameSettings settings;

  /// False when this device has no installed voice. The spoken-instructions
  /// switch is then shown as unavailable WITH the reason, rather than being
  /// hidden (leaving the player wondering where it went) or offered (leaving
  /// them wondering why it does nothing).
  final bool canSpeak;

  @override
  State<_GameSettingsSheet> createState() => _GameSettingsSheetState();
}

class _GameSettingsSheetState extends State<_GameSettingsSheet> {
  late GameSettings _settings = widget.settings;

  void _update(GameSettings next) => setState(() => _settings = next);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSizes.pagePadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'How games behave',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSizes.gap),

            _SettingSwitch(
              title: 'Sounds and buzzes',
              detail:
                  'A short click and a gentle buzz when something is right or '
                  'wrong. It follows your phone: on silent, it stays silent.',
              value: _settings.soundOn,
              onChanged: (value) => _update(_settings.copyWith(soundOn: value)),
            ),
            _SettingSwitch(
              title: 'Less movement',
              detail:
                  'Cards change without fading. Helpful if movement is '
                  'distracting.',
              value: _settings.reducedMotion,
              onChanged: (value) =>
                  _update(_settings.copyWith(reducedMotion: value)),
            ),
            _SettingSwitch(
              title: 'Read instructions aloud',
              detail: widget.canSpeak
                  ? 'The instructions are read out when a game opens. There is '
                        'a button to hear them again at any time.'
                  : 'This phone has no voice installed, so nothing can be read '
                        'aloud. The instructions are always on screen in '
                        'writing.',
              value: widget.canSpeak && _settings.spokenInstructions,
              onChanged: widget.canSpeak
                  ? (value) =>
                        _update(_settings.copyWith(spokenInstructions: value))
                  : null,
            ),
            _SettingSwitch(
              title: 'Suggest a different level',
              detail:
                  'After several games, MindPal may offer an easier or harder '
                  'level. It never changes the level on its own.',
              value: _settings.acceptDifficultySuggestions,
              onChanged: (value) => _update(
                _settings.copyWith(acceptDifficultySuggestions: value),
              ),
            ),

            const SizedBox(height: AppSizes.gap),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(_settings),
              child: const Text('Done'),
            ),
            const SizedBox(height: AppSizes.gapSmall),
          ],
        ),
      ),
    );
  }
}

/// One switch with its explanation. The words are as large as the rest of the
/// app, and the whole row is the touch target.
class _SettingSwitch extends StatelessWidget {
  const _SettingSwitch({
    required this.title,
    required this.detail,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String detail;
  final bool value;

  /// Null shows the row as unavailable. The detail line says why.
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.gapSmall),
      child: SwitchListTile.adaptive(
        value: value,
        onChanged: onChanged,
        contentPadding: EdgeInsets.zero,
        title: Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: enabled ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
        subtitle: Text(
          detail,
          style: const TextStyle(fontSize: 16, color: AppColors.textSecondary),
        ),
      ),
    );
  }
}
