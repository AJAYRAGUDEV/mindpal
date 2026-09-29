import 'package:flutter/material.dart';

import '../../l10n/language_scope.dart';
import '../../services/voice/voice_controller.dart';
import '../../theme/app_sizes.dart';
import '../../theme/app_theme.dart';
import '../engine/adventure_state.dart';
import '../model/adventure.dart';

/// The celebration, and then what the player did.
///
/// The summary is a record of the adventure, never a mark out of ten. There is
/// no score, no rating and nothing that reads as a judgement — the same rule
/// the rest of MindPal follows. "You used a hint" is a fact about the story,
/// not a fault.
class AdventureEndingScreen extends StatelessWidget {
  const AdventureEndingScreen({
    super.key,
    required this.adventure,
    required this.state,
    this.voice,
  });

  final Adventure adventure;
  final AdventureState state;
  final VoiceController? voice;

  @override
  Widget build(BuildContext context) {
    final ending =
        adventure.ending(state.endingId ?? '') ?? adventure.endings.last;
    final style = adventure.preparation.styles
        .where((candidate) => candidate.id == state.styleId)
        .firstOrNull;
    final canSpeak = voice?.speakerAvailable ?? false;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('The celebration'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSizes.pagePadding),
          children: [
            // The celebration scene: one line, large, with the arrangement the
            // player chose actually showing.
            Container(
              padding: const EdgeInsets.all(AppSizes.cardPadding),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    ending.color,
                    style?.color ?? ending.color,
                  ],
                ),
              ),
              child: Column(
                children: [
                  Icon(ending.icon, size: 72, color: Colors.white),
                  const SizedBox(height: AppSizes.gapSmall),
                  Text(
                    ending.celebration,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      height: 1.4,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  if (style != null) ...[
                    const SizedBox(height: AppSizes.gapSmall),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(style.icon, size: 20, color: Colors.white),
                          const SizedBox(width: 6),
                          Text(
                            style.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: AppSizes.gapLarge),
            Text(
              ending.title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSizes.gap),
            Text(
              ending.text,
              style: const TextStyle(
                fontSize: 20,
                height: 1.5,
                color: AppColors.textPrimary,
              ),
            ),

            if (canSpeak) ...[
              const SizedBox(height: AppSizes.gap),
              OutlinedButton.icon(
                onPressed: () => voice!.speak(
                  '${ending.title}. ${ending.text}',
                  LanguageScope.of(context).language,
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, AppSizes.buttonHeight),
                ),
                icon: const Icon(Icons.volume_up_rounded, size: 26),
                label: const Text('Read this to me'),
              ),
            ],

            const SizedBox(height: AppSizes.gapLarge),
            Text(
              'Your adventure',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSizes.gap),

            _Fact(
              icon: Icons.search_rounded,
              label: 'Clues you noticed',
              value: '${state.clues.length} of '
                  '${adventure.mystery.clues.length}',
            ),
            _Fact(
              icon: Icons.shopping_basket_rounded,
              label: 'Things you brought back',
              value: '${state.ownedItemIds.length}',
            ),
            _Fact(
              icon: Icons.monetization_on_rounded,
              label: 'Coins left over',
              value: '${state.coins}',
            ),
            if (state.wrongAccusations > 0)
              _Fact(
                icon: Icons.replay_rounded,
                label: 'Times you thought again',
                value: '${state.wrongAccusations}',
              ),
            if (state.hintsUsed > 0)
              _Fact(
                icon: Icons.lightbulb_outline_rounded,
                label: 'Hints you asked for',
                value: '${state.hintsUsed}',
              ),

            if (_decisionLines(ending).isNotEmpty) ...[
              const SizedBox(height: AppSizes.gap),
              const Text(
                'What you decided',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSizes.gapSmall),
              for (final line in _decisionLines(ending))
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.arrow_right_rounded,
                          size: 24, color: AppColors.primaryDark),
                      Expanded(
                        child: Text(
                          line,
                          style: const TextStyle(
                            fontSize: 18,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],

            const SizedBox(height: AppSizes.gapLarge),
            // Honest about what the story is, on the way out as well as in.
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppSizes.radius),
                border: Border.all(color: AppColors.border, width: 1.5),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 22, color: AppColors.textSecondary),
                  const SizedBox(width: AppSizes.gapSmall),
                  Expanded(
                    child: Text(
                      'This story is made up. ${adventure.culturalNote.festival} '
                      'is real — there is a note about it on the '
                      'adventure’s first screen.',
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSizes.gapLarge),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.home_rounded, size: 28),
              label: const Text('Back to the adventures'),
            ),
            const SizedBox(height: AppSizes.gap),
          ],
        ),
      ),
    );
  }

  /// The decisions the player made, in their own terms.
  ///
  /// Read back out of the adventure rather than stored as sentences, so the
  /// summary always says what the choice actually was.
  List<String> _decisionLines(Ending ending) {
    final lines = <String>[];
    for (final id in state.decisions) {
      for (final person in adventure.characters) {
        for (final node in person.nodes) {
          for (final choice in node.choices) {
            if (choice.id == id) lines.add('You said: "${choice.text}"');
          }
        }
      }
    }
    // Which of the two endings this produced, said plainly.
    final others = adventure.endings.where((e) => e.id != ending.id);
    if (others.isNotEmpty) {
      lines.add('There is another way this can end.');
    }
    return lines;
  }
}

class _Fact extends StatelessWidget {
  const _Fact({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.gapSmall),
      child: Row(
        children: [
          Icon(icon, size: 26, color: AppColors.textSecondary),
          const SizedBox(width: AppSizes.gapSmall),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 18,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
