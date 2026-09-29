import 'package:flutter/material.dart';

import '../../theme/app_sizes.dart';
import '../../theme/app_theme.dart';
import '../engine/adventure_engine.dart';
import '../engine/adventure_state.dart';
import '../model/adventure.dart';

/// The panel somebody speaks from.
///
/// One line at a time with a Next, then the replies. A whole speech at once is
/// a wall of text; a line at a time is a conversation. Nothing here is timed,
/// nothing advances on its own, and the panel can always be closed.
class DialoguePanel extends StatelessWidget {
  const DialoguePanel({
    super.key,
    required this.speaker,
    required this.line,
    required this.lineIndex,
    required this.lineCount,
    required this.choices,
    required this.onNextLine,
    required this.onChoice,
    required this.onClose,
    this.onListen,
  });

  final AdventureCharacter speaker;
  final String line;
  final int lineIndex;
  final int lineCount;

  /// Offered only on the last line, so a reply is never chosen before the
  /// speaker has finished.
  final List<DialogueChoice> choices;

  final VoidCallback onNextLine;
  final void Function(DialogueChoice choice) onChoice;
  final VoidCallback onClose;

  /// Null where the device has no voice. No dead button then.
  final VoidCallback? onListen;

  bool get isLastLine => lineIndex >= lineCount - 1;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: speaker.color, width: 3),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, -4)),
        ],
      ),
      padding: const EdgeInsets.all(AppSizes.cardPadding),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: speaker.color,
                  child: Icon(speaker.icon, size: 26, color: Colors.white),
                ),
                const SizedBox(width: AppSizes.gapSmall),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        speaker.name,
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      // Who somebody is, every time they speak. Nobody has to
                      // remember four names.
                      Text(
                        speaker.role,
                        style: const TextStyle(
                          fontSize: 15,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onListen != null)
                  IconButton(
                    onPressed: onListen,
                    tooltip: 'Read this aloud',
                    icon: const Icon(Icons.volume_up_rounded, size: 28),
                  ),
                IconButton(
                  onPressed: onClose,
                  tooltip: 'Stop talking',
                  icon: const Icon(Icons.close_rounded, size: 28),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.gapSmall),
            Text(
              line,
              style: const TextStyle(
                fontSize: 21,
                height: 1.45,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSizes.gap),

            if (!isLastLine)
              FilledButton.icon(
                onPressed: onNextLine,
                icon: const Icon(Icons.arrow_forward_rounded, size: 26),
                label: const Text('Go on'),
              )
            else if (choices.isEmpty)
              FilledButton.icon(
                onPressed: onClose,
                icon: const Icon(Icons.check_rounded, size: 26),
                label: const Text('Thank you'),
              )
            else
              for (final choice in choices) ...[
                OutlinedButton(
                  onPressed: () => onChoice(choice),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, AppSizes.buttonHeight),
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    side: BorderSide(color: speaker.color, width: 2),
                  ),
                  child: Text(
                    choice.text,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: AppSizes.gapSmall),
              ],
          ],
        ),
      ),
    );
  }
}

/// What the player is carrying, and how much money is left.
class InventorySheet extends StatelessWidget {
  const InventorySheet({
    super.key,
    required this.adventure,
    required this.state,
  });

  final Adventure adventure;
  final AdventureState state;

  @override
  Widget build(BuildContext context) {
    final items = [
      for (final id in state.ownedItemIds)
        if (adventure.item(id) != null) adventure.item(id)!,
    ];

    return _Sheet(
      title: 'What you are carrying',
      trailing: _CoinPill(coins: state.coins),
      child: items.isEmpty
          ? const _Empty(
              icon: Icons.shopping_basket_outlined,
              text: 'Nothing yet. The market is through the village square.',
            )
          : Column(
              children: [
                for (final item in items) ...[
                  _ItemRow(item: item, count: state.countOf(item.id)),
                  const SizedBox(height: AppSizes.gapSmall),
                ],
              ],
            ),
    );
  }
}

/// The quest journal and the clue board, in one place.
///
/// Both answer the same question — "what was I doing?" — and an elderly player
/// should not have to remember which of two buttons holds the answer.
class JournalSheet extends StatelessWidget {
  const JournalSheet({
    super.key,
    required this.adventure,
    required this.engine,
    required this.state,
    required this.onHint,
    this.showRequests = true,
  });

  final Adventure adventure;
  final AdventureEngine engine;
  final AdventureState state;
  final VoidCallback onHint;

  /// Relaxed play keeps the shopping list on show; Standard folds it away
  /// until asked for. Guidance is what changes between the two levels, never
  /// the story or the rules.
  final bool showRequests;

  @override
  Widget build(BuildContext context) {
    final journal = engine.journal(state);
    final clues = engine.foundClues(state);
    final requests = engine.requestStatuses(state);
    final hint = engine.currentHint(state);

    return _Sheet(
      title: 'Your journal',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Heading(adventure.objective, icon: Icons.flag_rounded),
          const SizedBox(height: AppSizes.gap),

          for (final row in journal) ...[
            _QuestRow(step: row.step, status: row.status),
            const SizedBox(height: AppSizes.gapSmall),
          ],

          if (showRequests && state.flags.contains('has_list')) ...[
            const SizedBox(height: AppSizes.gap),
            const _Heading('The shopping list',
                icon: Icons.checklist_rounded),
            const SizedBox(height: AppSizes.gapSmall),
            for (final status in requests) ...[
              _RequestRow(
                status: status,
                itemName: status.satisfiedBy == null
                    ? null
                    : adventure.item(status.satisfiedBy!)?.name,
              ),
              const SizedBox(height: 4),
            ],
          ],

          if (clues.isNotEmpty) ...[
            const SizedBox(height: AppSizes.gap),
            const _Heading('What you have noticed',
                icon: Icons.search_rounded),
            const SizedBox(height: AppSizes.gapSmall),
            for (final clue in clues) ...[
              _ClueCard(clue: clue),
              const SizedBox(height: AppSizes.gapSmall),
            ],
          ],

          if (hint != null) ...[
            const SizedBox(height: AppSizes.gap),
            OutlinedButton.icon(
              onPressed: onHint,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, AppSizes.buttonHeight),
              ),
              icon: const Icon(Icons.lightbulb_outline_rounded, size: 26),
              label: const Text('I am stuck — give me a hint'),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- pieces

class _Sheet extends StatelessWidget {
  const _Sheet({required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
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
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  ?trailing,
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
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
                children: [child],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text, {required this.icon});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 24, color: AppColors.primaryDark),
        const SizedBox(width: AppSizes.gapSmall),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryDark,
            ),
          ),
        ),
      ],
    );
  }
}

class _QuestRow extends StatelessWidget {
  const _QuestRow({required this.step, required this.status});

  final QuestStep step;
  final QuestStatus status;

  @override
  Widget build(BuildContext context) {
    final done = status == QuestStatus.done;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radius),
        border: Border.all(
          color: done ? const Color(0xFF1B5E20) : AppColors.border,
          width: done ? 2 : 1.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            done
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 28,
            color: done ? const Color(0xFF1B5E20) : AppColors.textSecondary,
          ),
          const SizedBox(width: AppSizes.gapSmall),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.title,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    decoration: done ? TextDecoration.lineThrough : null,
                  ),
                ),
                if (!done)
                  Text(
                    step.detail,
                    style: const TextStyle(
                      fontSize: 16,
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

class _RequestRow extends StatelessWidget {
  const _RequestRow({required this.status, required this.itemName});

  final RequestStatus status;
  final String? itemName;

  @override
  Widget build(BuildContext context) {
    final done = status.isSatisfied;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          done ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
          size: 26,
          color: done ? const Color(0xFF1B5E20) : AppColors.textSecondary,
        ),
        const SizedBox(width: AppSizes.gapSmall),
        Expanded(
          child: Text(
            done
                ? '${status.request.label} — ${itemName ?? "done"}'
                : status.request.label,
            style: TextStyle(
              fontSize: 18,
              color: done ? AppColors.textSecondary : AppColors.textPrimary,
              fontWeight: done ? FontWeight.w400 : FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _ClueCard extends StatelessWidget {
  const _ClueCard({required this.clue});

  final Clue clue;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(AppSizes.radius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(clue.icon, size: 26, color: AppColors.primaryDark),
          const SizedBox(width: AppSizes.gapSmall),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  clue.text,
                  style: const TextStyle(
                    fontSize: 18,
                    height: 1.35,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  clue.source,
                  style: const TextStyle(
                    fontSize: 15,
                    fontStyle: FontStyle.italic,
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

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item, required this.count});

  final AdventureItem item;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radius),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: item.color,
            child: Icon(item.icon, size: 28, color: Colors.white),
          ),
          const SizedBox(width: AppSizes.gap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  count > 1 ? '${item.name} × $count' : item.name,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  item.description,
                  style: const TextStyle(
                    fontSize: 16,
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

class _CoinPill extends StatelessWidget {
  const _CoinPill({required this.coins});

  final int coins;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF9A6700),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.monetization_on_rounded, size: 20,
              color: Colors.white),
          const SizedBox(width: 4),
          Text(
            '$coins',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.gapLarge),
      child: Column(
        children: [
          Icon(icon, size: 64, color: AppColors.textSecondary),
          const SizedBox(height: AppSizes.gapSmall),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
