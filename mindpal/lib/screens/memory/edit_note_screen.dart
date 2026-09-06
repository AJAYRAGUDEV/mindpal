import 'package:flutter/material.dart';

import '../../models/memory_note.dart';
import '../../theme/app_sizes.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/entry_list_scaffold.dart';
import '../../widgets/field_label.dart';
import 'entry_edit_result.dart';

/// Add or edit a note.
class EditNoteScreen extends StatefulWidget {
  const EditNoteScreen({super.key, this.existing});

  final MemoryNote? existing;

  bool get isEditing => existing != null;

  @override
  State<EditNoteScreen> createState() => _EditNoteScreenState();
}

class _EditNoteScreenState extends State<EditNoteScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _titleController = TextEditingController(text: existing?.title ?? '');
    _contentController = TextEditingController(text: existing?.content ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();

    final existing = widget.existing;
    final now = DateTime.now();
    final note = MemoryNote(
      id: existing?.id ?? 0,
      title: _titleController.text.trim(),
      content: _contentController.text.trim(),
      createdAt: existing?.createdAt ?? now,
      // Every save stamps updatedAt, which is what orders the notes list.
      updatedAt: now,
    );

    Navigator.of(context).pop(EntryEditResult<MemoryNote>.save(note));
  }

  Future<void> _delete() async {
    final confirmed = await confirmDestructiveAction(
      context,
      title: 'Delete this note?',
      message:
          '"${widget.existing!.title}" will be removed. This cannot be undone.',
    );
    if (!confirmed || !mounted) return;
    Navigator.of(context).pop(const EntryEditResult<MemoryNote>.delete());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.isEditing ? 'Edit Note' : 'Add Note')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSizes.pagePadding),
            children: [
              const FieldLabel('Title'),
              TextFormField(
                controller: _titleController,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                style: const TextStyle(fontSize: 20),
                decoration: const InputDecoration(
                  hintText: 'For example: Bank details',
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Please enter a title'
                    : null,
              ),
              const SizedBox(height: AppSizes.gapLarge),

              const FieldLabel('What do you want to remember?'),
              TextFormField(
                controller: _contentController,
                textCapitalization: TextCapitalization.sentences,
                // A generous box so the user can see what they have written
                // without scrolling inside a two-line field.
                maxLines: 7,
                minLines: 5,
                style: const TextStyle(fontSize: 20),
                decoration: const InputDecoration(
                  hintText: 'Write it here in your own words',
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Please write something to remember'
                    : null,
              ),
              const SizedBox(height: AppSizes.gapLarge),

              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check_rounded, size: AppSizes.iconMedium),
                label: Text(widget.isEditing ? 'Save changes' : 'Save note'),
              ),
              const SizedBox(height: AppSizes.gap),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),

              if (widget.isEditing) ...[
                const SizedBox(height: AppSizes.gapLarge),
                DeleteEntryButton(label: 'Delete note', onPressed: _delete),
              ],
              const SizedBox(height: AppSizes.gapLarge),
            ],
          ),
        ),
      ),
    );
  }
}
