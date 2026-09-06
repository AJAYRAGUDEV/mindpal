import 'package:flutter/material.dart';

import '../../models/person.dart';
import '../../theme/app_sizes.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/entry_list_scaffold.dart';
import '../../widgets/field_label.dart';
import 'entry_edit_result.dart';

/// Add or edit a person.
///
/// One screen for both jobs: pass [existing] to edit, leave it null to add.
/// The screen saves nothing itself — it pops an [EntryEditResult] and lets
/// PeopleScreen do the storing. Same shape as the reminder form on Day 3 and
/// the game screens on Day 2: a screen collects, its caller commits.
class EditPersonScreen extends StatefulWidget {
  const EditPersonScreen({super.key, this.existing});

  final Person? existing;

  bool get isEditing => existing != null;

  @override
  State<EditPersonScreen> createState() => _EditPersonScreenState();
}

class _EditPersonScreenState extends State<EditPersonScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _relationshipController;
  late final TextEditingController _phoneController;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _relationshipController = TextEditingController(
      text: existing?.relationship ?? '',
    );
    _phoneController = TextEditingController(text: existing?.phone ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _relationshipController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();

    final existing = widget.existing;
    final person = Person(
      // id 0 for a new person — JsonListStore assigns the real one.
      id: existing?.id ?? 0,
      name: _nameController.text.trim(),
      relationship: _relationshipController.text.trim(),
      phone: _phoneController.text.trim(),
      imagePath: existing?.imagePath,
      createdAt: existing?.createdAt ?? DateTime.now(),
    );

    Navigator.of(context).pop(EntryEditResult<Person>.save(person));
  }

  Future<void> _delete() async {
    final confirmed = await confirmDestructiveAction(
      context,
      title: 'Delete this person?',
      message:
          '${widget.existing!.name} will be removed from your saved people. '
          'This cannot be undone.',
    );
    if (!confirmed || !mounted) return;
    Navigator.of(context).pop(const EntryEditResult<Person>.delete());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Person' : 'Add Person'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSizes.pagePadding),
            children: [
              const FieldLabel('Name'),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                style: const TextStyle(fontSize: 20),
                decoration: const InputDecoration(hintText: 'For example: Ravi'),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Please enter a name'
                    : null,
              ),
              const SizedBox(height: AppSizes.gapLarge),

              const FieldLabel('Relationship'),
              TextFormField(
                controller: _relationshipController,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                style: const TextStyle(fontSize: 20),
                // Free text, not a dropdown: family words differ between
                // languages, and a fixed list would exclude people.
                decoration: const InputDecoration(
                  hintText: 'For example: Son, Daughter, Doctor',
                ),
              ),
              const SizedBox(height: AppSizes.gapLarge),

              const FieldLabel('Phone number (optional)'),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                style: const TextStyle(fontSize: 20),
                decoration: const InputDecoration(hintText: 'For example: 98765 43210'),
              ),
              const SizedBox(height: AppSizes.gapLarge),

              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check_rounded, size: AppSizes.iconMedium),
                label: Text(widget.isEditing ? 'Save changes' : 'Save person'),
              ),
              const SizedBox(height: AppSizes.gap),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),

              if (widget.isEditing) ...[
                const SizedBox(height: AppSizes.gapLarge),
                DeleteEntryButton(label: 'Delete person', onPressed: _delete),
              ],
              const SizedBox(height: AppSizes.gapLarge),
            ],
          ),
        ),
      ),
    );
  }
}
