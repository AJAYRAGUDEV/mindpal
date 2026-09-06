import 'package:flutter/material.dart';

import '../../models/reminder.dart';
import '../../theme/app_sizes.dart';
import '../../theme/app_theme.dart';

/// The form for creating a reminder — and, from the next step, for editing
/// one too.
///
/// Pass [existing] to edit; leave it null to create. Building one screen for
/// both is worth it here: the fields, the validation and the layout would
/// otherwise be duplicated and would drift apart.
///
/// The screen does not save anything. It pops with a Reminder, and the caller
/// decides what to do with it — the same pattern the games use to return a
/// GameResult.
class AddReminderScreen extends StatefulWidget {
  const AddReminderScreen({super.key, this.existing});

  final Reminder? existing;

  bool get isEditing => existing != null;

  @override
  State<AddReminderScreen> createState() => _AddReminderScreenState();
}

class _AddReminderScreenState extends State<AddReminderScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _notesController;

  late ReminderCategory _category;
  late TimeOfDay _time;
  late ReminderRepeat _repeat;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;

    _titleController = TextEditingController(text: existing?.title ?? '');
    _notesController = TextEditingController(text: existing?.notes ?? '');
    _category = existing?.category ?? ReminderCategory.dailyActivity;
    _repeat = existing?.repeat ?? ReminderRepeat.daily;
    // A sensible default beats an empty field: 9:00 AM is a time most people
    // are awake, and it is one tap to change.
    _time = existing?.timeOfDay ?? const TimeOfDay(hour: 9, minute: 0);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
      helpText: 'What time?',
      confirmText: 'Set time',
    );
    if (picked != null && mounted) setState(() => _time = picked);
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();

    final existing = widget.existing;

    // For a new reminder the id is 0 — ReminderService assigns the real one.
    // For an edit we keep the id, which is also its notification id.
    final reminder = Reminder(
      id: existing?.id ?? 0,
      title: _titleController.text.trim(),
      category: _category,
      hour: _time.hour,
      minute: _time.minute,
      repeat: _repeat,
      notes: _notesController.text.trim(),
      completedOn: existing?.completedOn,
      createdAt: existing?.createdAt ?? DateTime.now(),
    );

    Navigator.of(context).pop<Reminder>(reminder);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Reminder' : 'Add Reminder'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSizes.pagePadding),
            children: [
              const _FieldLabel('What is the reminder?'),
              TextFormField(
                controller: _titleController,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                style: const TextStyle(fontSize: 20),
                decoration: const InputDecoration(
                  hintText: 'For example: Drink water',
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Please enter a reminder'
                    : null,
              ),
              const SizedBox(height: AppSizes.gapLarge),

              const _FieldLabel('What kind of reminder?'),
              _CategoryGrid(
                selected: _category,
                onChanged: (category) => setState(() => _category = category),
              ),
              const SizedBox(height: AppSizes.gapLarge),

              const _FieldLabel('At what time?'),
              _TimeButton(time: _time, onTap: _pickTime),
              const SizedBox(height: AppSizes.gapLarge),

              const _FieldLabel('How often?'),
              _RepeatSelector(
                selected: _repeat,
                onChanged: (repeat) => setState(() => _repeat = repeat),
              ),
              const SizedBox(height: AppSizes.gapLarge),

              const _FieldLabel('Notes (optional)'),
              TextFormField(
                controller: _notesController,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 2,
                style: const TextStyle(fontSize: 20),
                decoration: const InputDecoration(
                  hintText: 'For example: Take after breakfast',
                ),
              ),
              const SizedBox(height: AppSizes.gapLarge),

              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check_rounded, size: AppSizes.iconMedium),
                label: Text(
                  widget.isEditing ? 'Save changes' : 'Save reminder',
                ),
              ),
              const SizedBox(height: AppSizes.gap),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              const SizedBox(height: AppSizes.gapLarge),
            ],
          ),
        ),
      ),
    );
  }
}

/// Big label above each field. Same reasoning as the profile form on Day 1:
/// a floating label that shrinks when tapped is hard to read.
class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.gapSmall),
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

/// The time as one very large button. Tapping it opens the standard Android
/// clock picker, which is already large and accessible — no reason to build
/// our own.
class _TimeButton extends StatelessWidget {
  const _TimeButton({required this.time, required this.onTap});

  final TimeOfDay time;
  final VoidCallback onTap;

  String get _formatted {
    final period = time.hour < 12 ? 'AM' : 'PM';
    final twelveHour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    return '$twelveHour:${time.minute.toString().padLeft(2, '0')} $period';
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Time, $_formatted. Tap to change.',
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            height: 84,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border, width: 2),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.access_time_rounded,
                  size: 34,
                  color: AppColors.primary,
                ),
                const SizedBox(width: AppSizes.gap),
                Expanded(
                  child: Text(
                    _formatted,
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const Text(
                  'Change',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryDark,
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

class _RepeatSelector extends StatelessWidget {
  const _RepeatSelector({required this.selected, required this.onChanged});

  final ReminderRepeat selected;
  final ValueChanged<ReminderRepeat> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final repeat in ReminderRepeat.values) ...[
          Expanded(
            child: _ChoiceTile(
              label: repeat.label,
              // "Once" needs explaining; "Daily" does not.
              subtitle: repeat == ReminderRepeat.once
                  ? 'Just one time'
                  : 'Every day',
              icon: repeat == ReminderRepeat.once
                  ? Icons.looks_one_rounded
                  : Icons.repeat_rounded,
              isSelected: repeat == selected,
              onTap: () => onChanged(repeat),
            ),
          ),
          if (repeat != ReminderRepeat.values.last)
            const SizedBox(width: AppSizes.gapSmall),
        ],
      ],
    );
  }
}

class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({required this.selected, required this.onChanged});

  final ReminderCategory selected;
  final ValueChanged<ReminderCategory> onChanged;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      // The grid lives inside a ListView, so it must not scroll on its own
      // and must size itself to its contents.
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 2.0,
      mainAxisSpacing: AppSizes.gapSmall,
      crossAxisSpacing: AppSizes.gapSmall,
      children: [
        for (final category in ReminderCategory.values)
          _ChoiceTile(
            label: category.label,
            icon: category.icon,
            accent: category.color,
            isSelected: category == selected,
            onTap: () => onChanged(category),
          ),
      ],
    );
  }
}

/// A large selectable tile, used for both categories and repeat options.
class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    this.subtitle,
    this.accent,
  });

  final String label;
  final String? subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final highlight = accent ?? AppColors.primary;

    return Semantics(
      button: true,
      selected: isSelected,
      label: subtitle == null ? label : '$label, $subtitle',
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: isSelected ? AppColors.primarySoft : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            constraints: const BoxConstraints(minHeight: 72),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? highlight : AppColors.border,
                width: isSelected ? 3 : 1.5,
              ),
            ),
            child: Row(
              children: [
                Icon(icon, size: 30, color: highlight),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: const TextStyle(
                            fontSize: 14,
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
