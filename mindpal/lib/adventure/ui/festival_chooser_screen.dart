import 'package:flutter/material.dart';

import '../../theme/app_sizes.dart';
import '../../theme/app_theme.dart';
import '../content/festival_skin.dart';
import '../content/festivals.dart';

/// Which festival would you like the adventure to be about?
///
/// Asked before every adventure, and before making a new one. The choice is
/// cultural rather than mechanical: the same village helps with the same kinds
/// of jobs, but at Pongal it is a pot boiling over and a kolam at the door, and
/// at Bihu it is pitha steaming and a japi above the doorway.
///
/// **Only festivals with written content appear.** There is no greyed-out row
/// for Onam or Diwali, because a greyed-out row claims content that does not
/// exist. What is missing is said in words at the bottom instead — the same
/// rule the cultural packs follow.
class FestivalChooserScreen extends StatefulWidget {
  const FestivalChooserScreen({
    super.key,
    required this.title,
    this.selected,
    this.askForMood = false,
  });

  /// "Choose a festival" or "What shall I write about?".
  final String title;

  final FestivalSkin? selected;

  /// Generation only: offers a word to set the mood, which the writer may use.
  final bool askForMood;

  @override
  State<FestivalChooserScreen> createState() => _FestivalChooserScreenState();
}

/// What the chooser returns.
class FestivalChoice {
  const FestivalChoice({required this.festival, this.mood});

  final FestivalSkin festival;

  /// A word the player offered, or null. Never a rule — just a mood.
  final String? mood;
}

class _FestivalChooserScreenState extends State<FestivalChooserScreen> {
  late FestivalSkin _chosen = widget.selected ?? kFestivals.first;
  final TextEditingController _mood = TextEditingController();

  @override
  void dispose() {
    _mood.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSizes.pagePadding),
          children: [
            const Text(
              'The village and the people are made up either way. The festival '
              'is real, and the adventure is built around what actually '
              'happens at it.',
              style: TextStyle(
                fontSize: 18,
                height: 1.4,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSizes.gap),

            for (final festival in kFestivals) ...[
              _FestivalRow(
                festival: festival,
                selected: _chosen.id == festival.id,
                onTap: () => setState(() => _chosen = festival),
              ),
              const SizedBox(height: AppSizes.gap),
            ],

            if (widget.askForMood) ...[
              const SizedBox(height: AppSizes.gapSmall),
              Text(
                'A word to set the mood',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              const Text(
                'Optional. Something like "rainy", "busy" or "the year my '
                'grandson came". It only changes the wording.',
                style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSizes.gapSmall),
              TextField(
                controller: _mood,
                maxLength: 40,
                style: const TextStyle(fontSize: 20),
                decoration: const InputDecoration(
                  hintText: 'Leave it empty if you like',
                  border: OutlineInputBorder(),
                ),
              ),
            ],

            const SizedBox(height: AppSizes.gap),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(
                FestivalChoice(
                  festival: _chosen,
                  mood: _mood.text.trim().isEmpty ? null : _mood.text.trim(),
                ),
              ),
              icon: Icon(
                widget.askForMood
                    ? Icons.auto_awesome_rounded
                    : Icons.play_arrow_rounded,
                size: 28,
              ),
              label: Text(widget.askForMood ? 'Write it' : 'Go on'),
            ),

            const SizedBox(height: AppSizes.gapLarge),
            // What is not here, said plainly rather than shown greyed out.
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 20, color: AppColors.textSecondary),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Only these two are written so far. Every other festival '
                    'needs its own — the objects, the food and the '
                    'customs written with somebody who keeps it. MindPal does '
                    'not guess at them, and does not use one festival to stand '
                    'for another.',
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.35,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.gapLarge),
          ],
        ),
      ),
    );
  }
}

class _FestivalRow extends StatelessWidget {
  const _FestivalRow({
    required this.festival,
    required this.selected,
    required this.onTap,
  });

  final FestivalSkin festival;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '${festival.name}, ${festival.region}. ${festival.blurb} '
          '${selected ? "Chosen" : "Not chosen"}',
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSizes.radius),
          child: Container(
            padding: const EdgeInsets.all(AppSizes.cardPadding),
            decoration: BoxDecoration(
              color: selected ? AppColors.primarySoft : AppColors.surface,
              borderRadius: BorderRadius.circular(AppSizes.radius),
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.border,
                width: selected ? 3 : 1.5,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: festival.colour,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(festival.icon, size: 30, color: Colors.white),
                ),
                const SizedBox(width: AppSizes.gap),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        festival.name,
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        festival.region,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        festival.blurb,
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.3,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 28,
                  color: selected ? AppColors.primary : AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
