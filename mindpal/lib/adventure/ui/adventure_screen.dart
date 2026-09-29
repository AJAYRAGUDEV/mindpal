import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/language_scope.dart';
import '../../services/voice/voice_controller.dart';
import '../../theme/app_sizes.dart';
import '../../theme/app_theme.dart';
import '../engine/adventure_engine.dart';
import '../engine/adventure_state.dart';
import '../model/adventure.dart';
import '../storage/adventure_store.dart';
import 'adventure_activities.dart';
import 'adventure_ending_screen.dart';
import 'adventure_panels.dart';
import 'adventure_scene.dart';

/// How much help the player is given. **Guidance only** — the story, the rules,
/// the prices and the cultural content are identical in both.
enum AdventurePace {
  relaxed(
    'Relaxed',
    'The list stays on show, things you can tap are ringed, and hints are '
        'direct.',
  ),
  standard(
    'Standard',
    'Fewer rings, the list waits in your journal, and hints point you at what '
        'to think about.',
  );

  const AdventurePace(this.label, this.detail);

  final String label;
  final String detail;

  static AdventurePace fromName(String? name) => AdventurePace.values
      .firstWhere((value) => value.name == name, orElse: () => relaxed);
}

/// Festival Quest: the playing screen.
///
/// The scene fills the screen. Everything else — talking, the market, the
/// mystery, the courtyard, the journal — arrives as a panel over it and goes
/// away again, so the player is always looking at the place they are in.
///
/// It owns the [AdventureState] and writes it to storage after every action
/// that changes anything, because an app for people with memory difficulty must
/// never punish somebody for closing it at the wrong moment.
class AdventureScreen extends StatefulWidget {
  const AdventureScreen({
    super.key,
    required this.adventure,
    required this.store,
    this.resumeFrom,
    this.pace = AdventurePace.relaxed,
    this.voice,
    this.reducedMotion = false,
  });

  final Adventure adventure;
  final AdventureStore store;

  /// Where to pick up from. Null starts a new playthrough.
  final AdventureState? resumeFrom;

  final AdventurePace pace;
  final VoiceController? voice;
  final bool reducedMotion;

  @override
  State<AdventureScreen> createState() => _AdventureScreenState();
}

class _AdventureScreenState extends State<AdventureScreen> {
  late final AdventureEngine _engine = AdventureEngine(widget.adventure);
  late AdventureState _state;

  /// The conversation on screen, if any.
  AdventureCharacter? _speaker;
  DialogueNode? _node;
  int _line = 0;

  /// What the last wrong guess at the mystery said.
  String? _mysteryFeedback;

  /// A short message about what just happened, shown over the scene.
  String? _flash;
  Timer? _flashTimer;

  @override
  void initState() {
    super.initState();
    _state = widget.resumeFrom ?? _engine.newGame();
    // A resumed game is saved again immediately, so "Continue" points at this
    // adventure even if the player closes it without doing anything.
    unawaited(widget.store.saveProgress(_state));
  }

  @override
  void dispose() {
    _flashTimer?.cancel();
    widget.voice?.stopSpeaking();
    super.dispose();
  }

  bool get _relaxed => widget.pace == AdventurePace.relaxed;

  AdventureLocation get _place =>
      widget.adventure.location(_state.locationId) ??
      widget.adventure.locations.first;

  // ------------------------------------------------------------- plumbing

  /// The one place state changes and is saved. Everything goes through here so
  /// there is no path that changes the game without writing it down.
  Future<void> _applyResult(ActionResult result) async {
    final gained = [
      for (final id in result.gainedItemIds)
        widget.adventure.item(id)?.name ?? id,
      for (final id in result.gainedClueIds)
        if (widget.adventure.clue(id) != null) 'a new clue',
    ];

    setState(() {
      _state = result.state;
      final parts = [
        if (result.message != null) result.message!,
        if (gained.isNotEmpty) 'You have ${_list(gained)}.',
      ];
      if (parts.isNotEmpty) _showFlash(parts.join(' '));
    });

    await widget.store.saveProgress(_state);

    if (_state.isFinished && mounted) await _showEnding();
  }

  String _list(List<String> values) {
    if (values.length == 1) return values.single;
    return '${values.take(values.length - 1).join(', ')} and ${values.last}';
  }

  void _showFlash(String message) {
    _flashTimer?.cancel();
    _flash = message;
    _flashTimer = Timer(const Duration(seconds: 6), () {
      if (mounted) setState(() => _flash = null);
    });
  }

  void _speak(String text) {
    final voice = widget.voice;
    if (voice == null || !voice.speakerAvailable) return;
    voice.speak(text, LanguageScope.of(context).language);
  }

  bool get _canSpeak => widget.voice?.speakerAvailable ?? false;

  // ---------------------------------------------------------------- scene

  Future<void> _tapHotspot(Hotspot spot) async {
    switch (spot.kind) {
      case HotspotKind.exit:
        setState(() {
          _state = _engine.moveTo(_state, spot.targetId ?? '');
          _flash = null;
        });
        await widget.store.saveProgress(_state);

      case HotspotKind.character:
        _openConversation(spot.targetId ?? '');

      case HotspotKind.object:
        await _applyResult(_engine.inspect(_state, spot.id));

      case HotspotKind.market:
        await _openMarket();

      case HotspotKind.accuse:
        await _openMystery();

      case HotspotKind.prepare:
        await _openPrepare();
    }
  }

  // --------------------------------------------------------- conversation

  void _openConversation(String characterId) {
    final person = widget.adventure.character(characterId);
    final node = _engine.openingNode(_state, characterId);
    if (person == null || node == null) return;

    // Entering a line can itself reveal something.
    final entered = _engine.enterNode(_state, node);
    setState(() {
      _speaker = person;
      _node = node;
      _line = 0;
      _state = entered.state;
    });
    unawaited(widget.store.saveProgress(_state));
    if (entered.gainedClueIds.isNotEmpty) {
      _showFlash('You have noticed something. It is in your journal.');
    }
    _speak(node.lines.first);
  }

  void _nextLine() {
    final node = _node;
    if (node == null) return;
    setState(() => _line = (_line + 1).clamp(0, node.lines.length - 1));
    _speak(node.lines[_line]);
  }

  Future<void> _chooseReply(DialogueChoice choice) async {
    final characterId = _speaker?.id;
    final result = _engine.choose(_state, choice);

    // The reply is shown as the next thing said, then the conversation either
    // continues at another line or closes.
    final next = choice.goTo == null || characterId == null
        ? null
        : _engine.node(characterId, choice.goTo!);

    await _applyResult(result);
    if (!mounted) return;

    if (next == null) {
      if (choice.reply != null) _speak(choice.reply!);
      setState(() {
        _speaker = null;
        _node = null;
      });
      return;
    }

    final entered = _engine.enterNode(_state, next);
    setState(() {
      _state = entered.state;
      _node = next;
      _line = 0;
    });
    await widget.store.saveProgress(_state);
    _speak(next.lines.first);
  }

  void _closeConversation() {
    widget.voice?.stopSpeaking();
    setState(() {
      _speaker = null;
      _node = null;
    });
  }

  // ------------------------------------------------------------ the parts

  Future<void> _openMarket() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => MarketView(
          adventure: widget.adventure,
          engine: _engine,
          state: _state,
          showList: _relaxed,
          onClose: () => Navigator.of(sheetContext).pop(),
          onBuy: (stallId, itemId) async {
            final result = _engine.buy(_state, stallId, itemId);
            await _applyResult(result);
            setSheetState(() {});
            if (!result.ok && result.message != null && sheetContext.mounted) {
              ScaffoldMessenger.of(sheetContext).showSnackBar(
                SnackBar(
                  content: Text(
                    result.message!,
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              );
            }
          },
        ),
      ),
    );
  }

  Future<void> _openMystery() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => MysteryView(
          adventure: widget.adventure,
          engine: _engine,
          state: _state,
          feedback: _mysteryFeedback,
          onClose: () => Navigator.of(sheetContext).pop(),
          onAccuse: (locationId, clueIds) async {
            final result = _engine.accuse(_state, locationId, clueIds);
            await _applyResult(result);
            if (result.ok) {
              _mysteryFeedback = null;
              if (sheetContext.mounted) Navigator.of(sheetContext).pop();
            } else {
              _mysteryFeedback = result.message;
              setSheetState(() {});
            }
          },
        ),
      ),
    );
  }

  Future<void> _openPrepare() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => PrepareView(
          adventure: widget.adventure,
          engine: _engine,
          state: _state,
          onClose: () => Navigator.of(sheetContext).pop(),
          onPlace: (slotId, itemId) async {
            final result = _engine.place(_state, slotId, itemId);
            await _applyResult(result);
            setSheetState(() {});
            if (!result.ok && result.message != null && sheetContext.mounted) {
              ScaffoldMessenger.of(sheetContext).showSnackBar(
                SnackBar(
                  content: Text(
                    result.message!,
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              );
            }
          },
          onUnplace: (slotId) async {
            setState(() => _state = _engine.unplace(_state, slotId));
            await widget.store.saveProgress(_state);
            setSheetState(() {});
          },
          onStyle: (styleId) async {
            setState(() => _state = _engine.chooseStyle(_state, styleId));
            await widget.store.saveProgress(_state);
            setSheetState(() {});
          },
          onFinish: () async {
            if (sheetContext.mounted) Navigator.of(sheetContext).pop();
            await _applyResult(_engine.finish(_state));
          },
        ),
      ),
    );
  }

  Future<void> _openInventory() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) =>
        InventorySheet(adventure: widget.adventure, state: _state),
  );

  Future<void> _openJournal() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => JournalSheet(
      adventure: widget.adventure,
      engine: _engine,
      state: _state,
      showRequests: _relaxed,
      onHint: () {
        Navigator.of(sheetContext).pop();
        _giveHint();
      },
    ),
  );

  /// Hints are free and always available. The count exists only so the summary
  /// at the end can mention it; nothing reads it to make anything harder.
  void _giveHint() {
    final hint = _engine.currentHint(_state);
    setState(() {
      _state = _state.copyWith(hintsUsed: _state.hintsUsed + 1);
      _showFlash(hint ?? 'There is nothing left to do but begin.');
    });
    unawaited(widget.store.saveProgress(_state));
    if (hint != null) _speak(hint);
  }

  Future<void> _showEnding() async {
    await widget.store.recordRun(widget.adventure, _state);
    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdventureEndingScreen(
          adventure: widget.adventure,
          state: _state,
          voice: widget.voice,
        ),
      ),
    );
    if (mounted) Navigator.of(context).pop();
  }

  // ----------------------------------------------------------------- view

  @override
  Widget build(BuildContext context) {
    final visible = _engine.visibleHotspots(_state);
    final step = _engine.currentStep(_state);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_place.name),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF9A6700),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.monetization_on_rounded,
                        size: 20, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      '${_state.coins}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.gap),
          child: Column(
            children: [
              // What to do now, in one line, always on screen.
              if (step != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSizes.gapSmall),
                  child: Row(
                    children: [
                      const Icon(Icons.flag_rounded,
                          size: 22, color: AppColors.primaryDark),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          step.title,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // The scene takes everything that is left.
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: AdventureScene(
                        location: _place,
                        hotspots: visible,
                        highlight: _relaxed,
                        reducedMotion: widget.reducedMotion,
                        onTap: _tapHotspot,
                      ),
                    ),
                    if (_flash != null)
                      Positioned(
                        left: 12,
                        right: 12,
                        top: 12,
                        child: _FlashCard(
                          message: _flash!,
                          reducedMotion: widget.reducedMotion,
                          onDismiss: () => setState(() => _flash = null),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: AppSizes.gapSmall),
              _BottomBar(
                onInventory: _openInventory,
                onJournal: _openJournal,
                onHint: _giveHint,
                carrying: _state.ownedItemIds.length,
              ),
            ],
          ),
        ),
      ),
      bottomSheet: _speaker == null || _node == null
          ? null
          : DialoguePanel(
              speaker: _speaker!,
              line: _node!.lines[_line],
              lineIndex: _line,
              lineCount: _node!.lines.length,
              choices: _line >= _node!.lines.length - 1
                  ? _engine.choicesFor(_state, _node!)
                  : const [],
              onNextLine: _nextLine,
              onChoice: _chooseReply,
              onClose: _closeConversation,
              onListen: _canSpeak ? () => _speak(_node!.lines[_line]) : null,
            ),
    );
  }
}

/// The message that appears over the scene when something happens.
class _FlashCard extends StatelessWidget {
  const _FlashCard({
    required this.message,
    required this.reducedMotion,
    required this.onDismiss,
  });

  final String message;
  final bool reducedMotion;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: 1,
      duration: Duration(milliseconds: reducedMotion ? 0 : 250),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onDismiss,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.primary, width: 2),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.auto_awesome_rounded,
                    size: 24, color: AppColors.primary),
                const SizedBox(width: AppSizes.gapSmall),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(
                      fontSize: 17,
                      height: 1.3,
                      color: AppColors.textPrimary,
                    ),
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

/// The three compact controls: what you carry, what you were doing, and help.
class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.onInventory,
    required this.onJournal,
    required this.onHint,
    required this.carrying,
  });

  final VoidCallback onInventory;
  final VoidCallback onJournal;
  final VoidCallback onHint;
  final int carrying;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _BarButton(
            icon: Icons.shopping_basket_rounded,
            label: carrying == 0 ? 'Carrying' : 'Carrying ($carrying)',
            onTap: onInventory,
          ),
        ),
        const SizedBox(width: AppSizes.gapSmall),
        Expanded(
          child: _BarButton(
            icon: Icons.menu_book_rounded,
            label: 'Journal',
            onTap: onJournal,
          ),
        ),
        const SizedBox(width: AppSizes.gapSmall),
        Expanded(
          child: _BarButton(
            icon: Icons.lightbulb_outline_rounded,
            label: 'Hint',
            onTap: onHint,
          ),
        ),
      ],
    );
  }
}

class _BarButton extends StatelessWidget {
  const _BarButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            height: AppSizes.minTouchTarget,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border, width: 1.5),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 24, color: AppColors.primaryDark),
                // A word under every symbol, as everywhere else in this app.
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
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
