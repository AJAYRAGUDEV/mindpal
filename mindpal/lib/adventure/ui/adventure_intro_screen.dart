import 'package:flutter/material.dart';

import '../../theme/app_sizes.dart';
import '../../theme/app_theme.dart';
import '../model/adventure.dart';
import 'adventure_screen.dart' show AdventurePace;

/// What the player sees before an adventure starts.
///
/// Three things, in this order: what the story is, **that it is fiction**, and
/// how much help they would like. The fiction label is not a footnote and not a
/// settings screen — it is on the way in, before anybody has read a word of the
/// story, because a made-up tale about a real festival must never be mistaken
/// for the festival itself.
class AdventureIntroScreen extends StatefulWidget {
  const AdventureIntroScreen({
    super.key,
    required this.adventure,
    required this.pace,
  });

  final Adventure adventure;

  /// The pace last chosen, offered again.
  final AdventurePace pace;

  @override
  State<AdventureIntroScreen> createState() => _AdventureIntroScreenState();
}

class _AdventureIntroScreenState extends State<AdventureIntroScreen> {
  late AdventurePace _pace = widget.pace;

  @override
  Widget build(BuildContext context) {
    final note = widget.adventure.culturalNote;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Festival Quest')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSizes.pagePadding),
          children: [
            Text(
              widget.adventure.title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text(
              '${note.festival} — ${note.region}',
              style: const TextStyle(
                fontSize: 18,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSizes.gap),

            // Said plainly, and first.
            Container(
              padding: const EdgeInsets.all(AppSizes.cardPadding),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(AppSizes.radius),
                border: Border.all(color: AppColors.reminder, width: 2),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.auto_stories_rounded,
                      size: 26, color: AppColors.reminder),
                  const SizedBox(width: AppSizes.gapSmall),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'This story is made up',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'The village and everybody in it are invented. '
                          '${note.festival} is real, and what the story says '
                          'about it comes from the note below. It is not a '
                          'traditional tale, and MindPal does not call it one.',
                          style: const TextStyle(
                            fontSize: 17,
                            height: 1.35,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSizes.gap),
            Text(
              widget.adventure.intro,
              style: const TextStyle(
                fontSize: 20,
                height: 1.5,
                color: AppColors.textPrimary,
              ),
            ),

            const SizedBox(height: AppSizes.gapLarge),
            Text(
              'About ${note.festival}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSizes.gapSmall),
            Text(
              note.summary,
              style: const TextStyle(
                fontSize: 18,
                height: 1.45,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSizes.gapSmall),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  note.reviewed
                      ? Icons.verified_rounded
                      : Icons.hourglass_bottom_rounded,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    note.reviewed
                        ? 'Checked by a reviewer.'
                        : 'This note has not been checked by a reviewer yet.',
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSizes.gapLarge),
            Text(
              'How much help would you like?',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            const Text(
              'This changes the help only. The story, the prices and the '
              'puzzles are the same either way.',
              style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSizes.gapSmall),
            for (final pace in AdventurePace.values) ...[
              _PaceRow(
                pace: pace,
                selected: _pace == pace,
                onTap: () => setState(() => _pace = pace),
              ),
              const SizedBox(height: AppSizes.gapSmall),
            ],

            const SizedBox(height: AppSizes.gap),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(_pace),
              icon: const Icon(Icons.play_arrow_rounded, size: 28),
              label: const Text('Begin the adventure'),
            ),
            const SizedBox(height: AppSizes.gapSmall),
            const Text(
              'It takes about five to seven minutes. You can stop at any '
              'time and carry on later.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSizes.gapLarge),
          ],
        ),
      ),
    );
  }
}

class _PaceRow extends StatelessWidget {
  const _PaceRow({
    required this.pace,
    required this.selected,
    required this.onTap,
  });

  final AdventurePace pace;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '${pace.label}. ${pace.detail}',
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
                        pace.label,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        pace.detail,
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.3,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
