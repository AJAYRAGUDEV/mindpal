import 'package:flutter/material.dart';

import '../../theme/app_sizes.dart';
import '../../theme/app_theme.dart';
import '../engine/adventure_engine.dart';
import '../engine/adventure_state.dart';
import '../model/adventure.dart';

/// Market Day: stalls with things on them, and a purse.
///
/// **A shop, not a quiz.** Every stall is laid out with its goods, each with a
/// picture, a name, a description and a price; a row that cannot be bought says
/// why on the row itself rather than vanishing. The shopping list sits at the
/// top so nobody has to hold five things in their head, and the purse is always
/// on screen. There is no "which of these is correct?" anywhere in it.
class MarketView extends StatelessWidget {
  const MarketView({
    super.key,
    required this.adventure,
    required this.engine,
    required this.state,
    required this.onBuy,
    required this.onClose,
    this.showList = true,
  });

  final Adventure adventure;
  final AdventureEngine engine;
  final AdventureState state;
  final void Function(String stallId, String itemId) onBuy;
  final VoidCallback onClose;

  /// Relaxed play keeps the list open; Standard puts it behind a tap. The goods
  /// and the prices are identical either way.
  final bool showList;

  @override
  Widget build(BuildContext context) {
    final statuses = engine.requestStatuses(state);
    final done = engine.shoppingComplete(state);

    return _ActivityScaffold(
      title: 'The market',
      subtitle: 'You have ${state.coins} coins',
      onClose: onClose,
      children: [
        if (showList || done) ...[
          Container(
            padding: const EdgeInsets.all(AppSizes.cardPadding),
            decoration: BoxDecoration(
              color: done ? const Color(0xFFE3F1E4) : AppColors.primarySoft,
              borderRadius: BorderRadius.circular(AppSizes.radius),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  done
                      ? 'That is everything on the list.'
                      : 'Ammal asked for:',
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSizes.gapSmall),
                for (final status in statuses)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          status.isSatisfied
                              ? Icons.check_box_rounded
                              : Icons.check_box_outline_blank_rounded,
                          size: 24,
                          color: status.isSatisfied
                              ? const Color(0xFF1B5E20)
                              : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            status.request.label,
                            style: TextStyle(
                              fontSize: 17,
                              color: status.isSatisfied
                                  ? AppColors.textSecondary
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSizes.gap),
        ],

        for (final stall in adventure.market.stalls) ...[
          _StallCard(
            stall: stall,
            entries: engine.stallEntries(state, stall),
            onBuy: (itemId) => onBuy(stall.id, itemId),
          ),
          const SizedBox(height: AppSizes.gap),
        ],
      ],
    );
  }
}

class _StallCard extends StatelessWidget {
  const _StallCard({
    required this.stall,
    required this.entries,
    required this.onBuy,
  });

  final MarketStall stall;
  final List<StallEntry> entries;
  final void Function(String itemId) onBuy;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radius),
        border: Border.all(color: stall.color, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The awning.
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: stall.color,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
            ),
            child: Row(
              children: [
                Icon(stall.icon, size: 28, color: Colors.white),
                const SizedBox(width: AppSizes.gapSmall),
                Expanded(
                  child: Text(
                    stall.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stall.keeperLine,
                  style: const TextStyle(
                    fontSize: 17,
                    fontStyle: FontStyle.italic,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSizes.gapSmall),
                for (final entry in entries) ...[
                  _GoodsRow(entry: entry, onBuy: () => onBuy(entry.item.id)),
                  const SizedBox(height: AppSizes.gapSmall),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GoodsRow extends StatelessWidget {
  const _GoodsRow({required this.entry, required this.onBuy});

  final StallEntry entry;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final blocked = entry.blockedReason;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: blocked == null ? AppColors.background : const Color(0xFFF2F2F2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      child: Row(
        children: [
          Opacity(
            opacity: blocked == null ? 1 : 0.45,
            child: CircleAvatar(
              radius: 24,
              backgroundColor: entry.item.color,
              child: Icon(entry.item.icon, size: 26, color: Colors.white),
            ),
          ),
          const SizedBox(width: AppSizes.gapSmall),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.item.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  entry.item.description,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSizes.gapSmall),
          if (blocked != null)
            // Says why, on the row. A control that has quietly disappeared
            // teaches nothing.
            SizedBox(
              width: 96,
              child: Text(
                blocked,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
            )
          else
            SizedBox(
              width: 96,
              child: FilledButton(
                onPressed: onBuy,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 52),
                  padding: EdgeInsets.zero,
                ),
                child: Text(
                  '${entry.item.price} coins',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The Village Mystery: name a place, and say which clues point at it.
///
/// Two taps of thinking rather than one of guessing. Getting it wrong is a
/// nudge and costs nothing, which is why the button says "Say what you think"
/// rather than anything that sounds final.
class MysteryView extends StatefulWidget {
  const MysteryView({
    super.key,
    required this.adventure,
    required this.engine,
    required this.state,
    required this.onAccuse,
    required this.onClose,
    this.feedback,
  });

  final Adventure adventure;
  final AdventureEngine engine;
  final AdventureState state;
  final void Function(String locationId, Set<String> clueIds) onAccuse;
  final VoidCallback onClose;

  /// What the last wrong attempt said, if there was one.
  final String? feedback;

  @override
  State<MysteryView> createState() => _MysteryViewState();
}

class _MysteryViewState extends State<MysteryView> {
  String? _place;
  final Set<String> _chosenClues = {};

  @override
  Widget build(BuildContext context) {
    final found = widget.engine.foundClues(widget.state);
    final canAnswer = _place != null && _chosenClues.isNotEmpty;

    return _ActivityScaffold(
      title: widget.adventure.mystery.question,
      subtitle: 'Choose a place, then the reasons.',
      onClose: widget.onClose,
      children: [
        if (widget.feedback != null) ...[
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
                const Icon(Icons.lightbulb_outline_rounded,
                    size: 26, color: AppColors.reminder),
                const SizedBox(width: AppSizes.gapSmall),
                Expanded(
                  child: Text(
                    widget.feedback!,
                    style: const TextStyle(
                      fontSize: 18,
                      height: 1.35,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSizes.gap),
        ],

        const Text(
          'Where do you think it is?',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSizes.gapSmall),
        for (final id in widget.adventure.mystery.candidateLocationIds)
          if (widget.adventure.location(id) != null) ...[
            _PickRow(
              label: widget.adventure.location(id)!.name,
              detail: widget.adventure.location(id)!.description,
              icon: Icons.place_rounded,
              selected: _place == id,
              onTap: () => setState(() => _place = id),
            ),
            const SizedBox(height: AppSizes.gapSmall),
          ],

        const SizedBox(height: AppSizes.gap),
        const Text(
          'Why do you think so?',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSizes.gapSmall),
        if (found.isEmpty)
          const Text(
            'You have not noticed anything yet. Talk to people and look '
            'around.',
            style: TextStyle(fontSize: 17, color: AppColors.textSecondary),
          )
        else
          for (final clue in found) ...[
            _PickRow(
              label: clue.text,
              detail: clue.source,
              icon: clue.icon,
              selected: _chosenClues.contains(clue.id),
              onTap: () => setState(() {
                if (!_chosenClues.remove(clue.id)) _chosenClues.add(clue.id);
              }),
            ),
            const SizedBox(height: AppSizes.gapSmall),
          ],

        const SizedBox(height: AppSizes.gap),
        FilledButton.icon(
          onPressed: canAnswer
              ? () => widget.onAccuse(_place!, {..._chosenClues})
              : null,
          icon: const Icon(Icons.record_voice_over_rounded, size: 26),
          label: const Text('Say what you think'),
        ),
        const SizedBox(height: AppSizes.gapSmall),
        const Text(
          'If you are wrong, nothing is lost. You can try again.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

/// Getting the courtyard ready: tap a thing, tap where it goes.
///
/// **No dragging anywhere.** Two taps, each with a big target, and anything
/// placed can be taken out again. The arrangement at the bottom is a matter of
/// taste and is never marked wrong.
class PrepareView extends StatefulWidget {
  const PrepareView({
    super.key,
    required this.adventure,
    required this.engine,
    required this.state,
    required this.onPlace,
    required this.onUnplace,
    required this.onStyle,
    required this.onFinish,
    required this.onClose,
  });

  final Adventure adventure;
  final AdventureEngine engine;
  final AdventureState state;
  final void Function(String slotId, String itemId) onPlace;
  final void Function(String slotId) onUnplace;
  final void Function(String styleId) onStyle;
  final VoidCallback onFinish;
  final VoidCallback onClose;

  @override
  State<PrepareView> createState() => _PrepareViewState();
}

class _PrepareViewState extends State<PrepareView> {
  /// The thing the player has picked up but not yet put down.
  String? _holding;

  @override
  Widget build(BuildContext context) {
    final preparation = widget.adventure.preparation;
    final ready = widget.engine.courtyardReady(widget.state);
    final carried = [
      for (final id in widget.state.ownedItemIds)
        if (widget.adventure.item(id) != null &&
            !widget.state.placed.containsValue(id))
          widget.adventure.item(id)!,
    ];

    return _ActivityScaffold(
      title: 'Get the courtyard ready',
      subtitle: _holding == null
          ? 'Tap something you are carrying, then tap where it goes.'
          : 'Now tap where it should go.',
      onClose: widget.onClose,
      children: [
        // What is in hand.
        if (carried.isEmpty && !ready)
          const Text(
            'You are not carrying anything to put out yet.',
            style: TextStyle(fontSize: 18, color: AppColors.textSecondary),
          )
        else
          Wrap(
            spacing: AppSizes.gapSmall,
            runSpacing: AppSizes.gapSmall,
            children: [
              for (final item in carried)
                _CarriedChip(
                  item: item,
                  selected: _holding == item.id,
                  onTap: () => setState(
                    () => _holding = _holding == item.id ? null : item.id,
                  ),
                ),
            ],
          ),

        const SizedBox(height: AppSizes.gap),
        for (final slot in preparation.slots) ...[
          _SlotCard(
            slot: slot,
            placed: widget.state.placed[slot.id] == null
                ? null
                : widget.adventure.item(widget.state.placed[slot.id]!),
            holding: _holding,
            onTap: () {
              final holding = _holding;
              if (holding == null) return;
              widget.onPlace(slot.id, holding);
              setState(() => _holding = null);
            },
            onRemove: () => widget.onUnplace(slot.id),
          ),
          const SizedBox(height: AppSizes.gapSmall),
        ],

        if (ready) ...[
          const SizedBox(height: AppSizes.gap),
          const Text(
            'How should it look?',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Whichever you like best. There is no wrong answer here.',
            style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSizes.gapSmall),
          for (final style in preparation.styles) ...[
            _PickRow(
              label: style.name,
              detail: style.description,
              icon: style.icon,
              selected: widget.state.styleId == style.id,
              onTap: () => widget.onStyle(style.id),
            ),
            const SizedBox(height: AppSizes.gapSmall),
          ],
          const SizedBox(height: AppSizes.gap),
          FilledButton.icon(
            onPressed:
                widget.state.styleId == null ? null : widget.onFinish,
            icon: const Icon(Icons.celebration_rounded, size: 28),
            label: const Text('Begin the celebration'),
          ),
        ],
      ],
    );
  }
}

class _CarriedChip extends StatelessWidget {
  const _CarriedChip({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final AdventureItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '${item.name}. ${selected ? "In your hand" : "Tap to pick up"}',
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            constraints: const BoxConstraints(minHeight: 64),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? AppColors.primarySoft : AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.border,
                width: selected ? 3 : 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: item.color,
                  child: Icon(item.icon, size: 22, color: Colors.white),
                ),
                const SizedBox(width: AppSizes.gapSmall),
                Text(
                  item.name,
                  style: const TextStyle(
                    fontSize: 17,
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

class _SlotCard extends StatelessWidget {
  const _SlotCard({
    required this.slot,
    required this.placed,
    required this.holding,
    required this.onTap,
    required this.onRemove,
  });

  final PreparationSlot slot;
  final AdventureItem? placed;
  final String? holding;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final isFilled = placed != null;
    final waiting = holding != null && !isFilled;

    return Semantics(
      button: true,
      label: isFilled
          ? '${slot.label}: ${placed!.name}'
          : '${slot.label}: empty',
      excludeSemantics: true,
      onTap: isFilled ? null : onTap,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isFilled ? null : onTap,
          borderRadius: BorderRadius.circular(AppSizes.radius),
          child: Container(
            constraints: const BoxConstraints(minHeight: 84),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isFilled ? const Color(0xFFE3F1E4) : AppColors.surface,
              borderRadius: BorderRadius.circular(AppSizes.radius),
              border: Border.all(
                color: isFilled
                    ? const Color(0xFF1B5E20)
                    : (waiting ? AppColors.primary : AppColors.border),
                width: isFilled || waiting ? 3 : 1.5,
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: isFilled
                      ? placed!.color
                      : AppColors.background,
                  child: Icon(
                    isFilled ? placed!.icon : Icons.add_rounded,
                    size: 26,
                    color: isFilled ? Colors.white : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: AppSizes.gap),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        slot.label,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        isFilled
                            ? placed!.name
                            : (waiting ? 'Tap to put it here' : 'Empty'),
                        style: const TextStyle(
                          fontSize: 16,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isFilled)
                  TextButton(
                    onPressed: onRemove,
                    child: const Text(
                      'Take out',
                      style: TextStyle(fontSize: 16),
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

/// A big, obvious, selectable row. Used for places, clues and arrangements —
/// everything the player picks from a list.
class _PickRow extends StatelessWidget {
  const _PickRow({
    required this.label,
    required this.detail,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String detail;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$label. ${selected ? "Chosen" : "Not chosen"}',
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSizes.radius),
          child: Container(
            constraints: const BoxConstraints(
              minHeight: AppSizes.minTouchTarget,
            ),
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
                Icon(icon, size: 26, color: AppColors.textSecondary),
                const SizedBox(width: AppSizes.gapSmall),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 18,
                          height: 1.3,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (detail.isNotEmpty)
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The frame the three activities share.
class _ActivityScaffold extends StatelessWidget {
  const _ActivityScaffold({
    required this.title,
    required this.subtitle,
    required this.onClose,
    required this.children,
  });

  final String title;
  final String subtitle;
  final VoidCallback onClose;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, controller) => Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.pagePadding,
                AppSizes.gap,
                AppSizes.gapSmall,
                AppSizes.gapSmall,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 16,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: onClose,
                    tooltip: 'Close',
                    icon: const Icon(Icons.close_rounded, size: 28),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(
                  AppSizes.pagePadding,
                  0,
                  AppSizes.pagePadding,
                  AppSizes.gapLarge,
                ),
                children: children,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
