import 'package:flutter/material.dart';

import '../../models/place.dart';
import '../../theme/app_sizes.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/entry_list_scaffold.dart';
import '../../widgets/field_label.dart';
import 'entry_edit_result.dart';

/// Add or edit a place. Same shape as EditPersonScreen.
class EditPlaceScreen extends StatefulWidget {
  const EditPlaceScreen({super.key, this.existing});

  final Place? existing;

  bool get isEditing => existing != null;

  @override
  State<EditPlaceScreen> createState() => _EditPlaceScreenState();
}

class _EditPlaceScreenState extends State<EditPlaceScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _addressController;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _descriptionController = TextEditingController(
      text: existing?.description ?? '',
    );
    _addressController = TextEditingController(text: existing?.address ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();

    final existing = widget.existing;
    final place = Place(
      id: existing?.id ?? 0,
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      address: _addressController.text.trim(),
      createdAt: existing?.createdAt ?? DateTime.now(),
    );

    Navigator.of(context).pop(EntryEditResult<Place>.save(place));
  }

  Future<void> _delete() async {
    final confirmed = await confirmDestructiveAction(
      context,
      title: 'Delete this place?',
      message:
          '${widget.existing!.name} will be removed from your saved places. '
          'This cannot be undone.',
    );
    if (!confirmed || !mounted) return;
    Navigator.of(context).pop(const EntryEditResult<Place>.delete());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Place' : 'Add Place'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSizes.pagePadding),
            children: [
              const FieldLabel('Name of the place'),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                style: const TextStyle(fontSize: 20),
                decoration: const InputDecoration(
                  hintText: 'For example: Home, Hospital, Temple',
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Please enter a name'
                    : null,
              ),
              const SizedBox(height: AppSizes.gapLarge),

              const FieldLabel('What is this place?'),
              TextFormField(
                controller: _descriptionController,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 2,
                style: const TextStyle(fontSize: 20),
                decoration: const InputDecoration(
                  hintText: 'For example: Where I live with Meena',
                ),
              ),
              const SizedBox(height: AppSizes.gapLarge),

              const FieldLabel('Address (optional)'),
              TextFormField(
                controller: _addressController,
                textCapitalization: TextCapitalization.words,
                maxLines: 2,
                style: const TextStyle(fontSize: 20),
                decoration: const InputDecoration(
                  hintText: 'Street, area, landmark',
                ),
              ),
              const SizedBox(height: AppSizes.gapLarge),

              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check_rounded, size: AppSizes.iconMedium),
                label: Text(widget.isEditing ? 'Save changes' : 'Save place'),
              ),
              const SizedBox(height: AppSizes.gap),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),

              if (widget.isEditing) ...[
                const SizedBox(height: AppSizes.gapLarge),
                DeleteEntryButton(label: 'Delete place', onPressed: _delete),
              ],
              const SizedBox(height: AppSizes.gapLarge),
            ],
          ),
        ),
      ),
    );
  }
}
