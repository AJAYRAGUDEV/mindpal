import 'package:flutter/material.dart';

import '../../services/voice/voice_controller.dart';
import '../../theme/app_sizes.dart';
import '../../theme/app_theme.dart';
import '../content/festival_skin.dart';
import '../content/festivals.dart';
import '../engine/adventure_state.dart';
import '../model/adventure.dart';
import '../storage/adventure_store.dart';
import 'adventure_intro_screen.dart';
import 'adventure_library_screens.dart';
import 'adventure_screen.dart';
import 'festival_chooser_screen.dart';

/// The front door of Festival Quest.
///
/// Five things, in the order the brief asks for: Start, Continue, Saved, Quick
/// Games, My Progress. The adventure is the app's main journey now — the older
/// matching and sequencing games are still here, one tap away, under Quick
/// Games, and reminders, the memory vault and the caregiver tools have moved to
/// Extras. None of them is required to play.
class AdventureHomeScreen extends StatefulWidget {
  const AdventureHomeScreen({
    super.key,
    required this.store,
    required this.onOpenQuickGames,
    required this.onOpenProgress,
    this.voice,
    this.reducedMotion = false,
    this.onGenerate,
  });

  final AdventureStore store;

  /// The older games, kept whole.
  final VoidCallback onOpenQuickGames;

  final VoidCallback onOpenProgress;

  final VoiceController? voice;
  final bool reducedMotion;

  /// Makes a new adventure with Gemini. Null when no backend is configured,
  /// in which case the button is absent rather than present and broken.
  final Future<Adventure?> Function(
    BuildContext context,
    FestivalChoice choice,
  )?
  onGenerate;

  @override
  State<AdventureHomeScreen> createState() => _AdventureHomeScreenState();
}

class _AdventureHomeScreenState extends State<AdventureHomeScreen> {
  AdventurePace _pace = AdventurePace.relaxed;

  /// Remembered between adventures, so somebody who always plays Bihu is not
  /// asked to find it again every time.
  FestivalSkin _festival = kFestivals.first;

  /// Asks which festival, and returns null if they backed out.
  Future<FestivalChoice?> _askFestival({
    required String title,
    bool askForMood = false,
  }) async {
    final choice = await Navigator.of(context).push<FestivalChoice>(
      MaterialPageRoute(
        builder: (_) => FestivalChooserScreen(
          title: title,
          selected: _festival,
          askForMood: askForMood,
        ),
      ),
    );
    if (choice != null && mounted) setState(() => _festival = choice.festival);
    return choice;
  }

  ({Adventure adventure, AdventureState state})? get _current =>
      widget.store.current();

  Future<void> _play(Adventure adventure, {AdventureState? resume}) async {
    // A new adventure always shows its introduction, and with it the note that
    // the story is fiction. Resuming does not — the player has read it.
    var pace = _pace;
    if (resume == null) {
      final chosen = await Navigator.of(context).push<AdventurePace>(
        MaterialPageRoute(
          builder: (_) =>
              AdventureIntroScreen(adventure: adventure, pace: _pace),
        ),
      );
      if (chosen == null || !mounted) return;
      pace = chosen;
      setState(() => _pace = chosen);
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdventureScreen(
          adventure: adventure,
          store: widget.store,
          resumeFrom: resume,
          pace: pace,
          voice: widget.voice,
          reducedMotion: widget.reducedMotion,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  /// Choose a festival, then play its adventure from the beginning.
  Future<void> _startChosen() async {
    final choice = await _askFestival(title: 'Choose a festival');
    if (choice == null || !mounted) return;
    await _play(adventureForFestival(choice.festival));
  }

  Future<void> _openSaved() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SavedAdventuresScreen(
          store: widget.store,
          onPlay: (adventure, resume) => _play(adventure, resume: resume),
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _generate() async {
    final make = widget.onGenerate;
    if (make == null) return;

    final choice = await _askFestival(
      title: 'What shall I write about?',
      askForMood: true,
    );
    if (choice == null || !mounted) return;

    final adventure = await make(context, choice);
    if (adventure == null || !mounted) return;

    await widget.store.saveAdventure(adventure);
    if (!mounted) return;
    setState(() {});
    await _play(adventure);
  }

  @override
  Widget build(BuildContext context) {
    final current = _current;
    final library = widget.store.library();

    return ListView(
      padding: const EdgeInsets.all(AppSizes.pagePadding),
      children: [
        Text(
          'Festival Quest',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 4),
        const Text(
          'Explore a village, talk to people, and help get a celebration '
          'ready.',
          style: TextStyle(fontSize: 18, color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSizes.gapLarge),

        if (current != null) ...[
          _BigAction(
            icon: Icons.play_circle_fill_rounded,
            title: 'Continue Adventure',
            detail: '${current.adventure.title} — '
                '${_whereabouts(current.adventure, current.state)}',
            color: AppColors.primary,
            onTap: () => _play(current.adventure, resume: current.state),
          ),
          const SizedBox(height: AppSizes.gap),
        ],

        _BigAction(
          icon: Icons.explore_rounded,
          title: 'Start Adventure',
          detail: 'Choose a festival — '
              '${kFestivals.map((f) => f.name).join(' or ')}',
          color: AppColors.activity,
          onTap: _startChosen,
        ),

        const SizedBox(height: AppSizes.gap),
        _BigAction(
          icon: Icons.library_books_rounded,
          title: 'Saved Adventures',
          detail: library.length == 1
              ? 'One adventure, ready to play offline'
              : '${library.length} adventures, ready to play offline',
          color: AppColors.memory,
          onTap: _openSaved,
        ),

        const SizedBox(height: AppSizes.gap),
        _BigAction(
          icon: Icons.videogame_asset_rounded,
          title: 'Quick Games',
          detail: 'Matching, story order, odd-one-out and family photos',
          color: AppColors.reminder,
          onTap: widget.onOpenQuickGames,
        ),

        const SizedBox(height: AppSizes.gap),
        _BigAction(
          icon: Icons.timeline_rounded,
          title: 'My Progress',
          detail: 'Adventures you have finished, and what you discovered',
          color: AppColors.primaryDark,
          onTap: widget.onOpenProgress,
        ),

        if (widget.onGenerate != null) ...[
          const SizedBox(height: AppSizes.gapLarge),
          OutlinedButton.icon(
            onPressed: _generate,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, AppSizes.buttonHeight),
            ),
            icon: const Icon(Icons.auto_awesome_rounded, size: 26),
            label: const Text('Make me a new adventure'),
          ),
          const SizedBox(height: AppSizes.gapSmall),
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.wifi_rounded, size: 20,
                  color: AppColors.textSecondary),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Making a new adventure needs an internet connection. Once '
                  'it is made it is saved here and plays offline like any '
                  'other.',
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
      ],
    );
  }

  /// "In the market, three things still to do" — enough to recognise where you
  /// left off without re-reading the journal.
  String _whereabouts(Adventure adventure, AdventureState state) {
    final place = adventure.location(state.locationId)?.name ?? 'on your way';
    return 'you are at the ${place.toLowerCase()}';
  }
}

/// One of the five destinations. Large, labelled in words, one purpose each.
class _BigAction extends StatelessWidget {
  const _BigAction({
    required this.icon,
    required this.title,
    required this.detail,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String detail;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$title. $detail',
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSizes.radius),
          child: Container(
            constraints: const BoxConstraints(minHeight: 96),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSizes.radius),
              border: Border.all(color: color, width: 2.5),
            ),
            child: Row(
              children: [
                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, size: 34, color: Colors.white),
                ),
                const SizedBox(width: AppSizes.gap),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        detail,
                        style: const TextStyle(
                          fontSize: 16,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    size: 30, color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
