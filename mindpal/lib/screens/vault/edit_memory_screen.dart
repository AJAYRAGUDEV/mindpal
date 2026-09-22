import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/vault_memory.dart';
import '../../services/memory_vault_service.dart';
import '../../storage/media/media_store.dart';
import '../../theme/app_sizes.dart';
import '../../theme/app_theme.dart';
import '../../utils/date_formats.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/entry_list_scaffold.dart';
import '../../widgets/field_label.dart';
import '../../widgets/memory_media.dart';
import '../memory/entry_edit_result.dart';

/// Add or edit a memory. Pass [existing] to edit; leave it null to add.
///
/// Like every form in this app it saves nothing itself. It pops an
/// `EntryEditResult<MemoryDraft>` and the vault screen commits it, so a photo
/// chosen and then cancelled never touches storage.
///
/// PICKING MEDIA. image_picker opens the system's own chooser: the Android
/// photo picker (Android 13+) or the gallery/document chooser on older
/// versions, and a file dialog in the browser. The app receives only the file
/// the user chose. That is why no storage, camera or microphone permission is
/// declared — the app never reads the gallery itself and never records.
class EditMemoryScreen extends StatefulWidget {
  const EditMemoryScreen({super.key, this.existing, this.loadPhoto});

  final VaultMemory? existing;

  /// How to load the existing photo for the preview. Only needed when editing
  /// a memory that already has one.
  final Future<Uint8List?> Function()? loadPhoto;

  bool get isEditing => existing != null;

  @override
  State<EditMemoryScreen> createState() => _EditMemoryScreenState();
}

class _EditMemoryScreenState extends State<EditMemoryScreen> {
  static const int _maxVideoBytes = 60 * 1024 * 1024;

  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();

  late final TextEditingController _title;
  late final TextEditingController _story;
  late final TextEditingController _person;
  late final TextEditingController _relationship;

  DateTime? _date;
  late MemoryCategory _category;

  // Media state. "Keep what is there" is the default; the two flags below
  // record an explicit removal, and a new pick replaces either.
  PendingMedia? _newPhoto;
  bool _removePhoto = false;
  PendingMedia? _newVideo;
  bool _removeVideo = false;

  bool _picking = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _title = TextEditingController(text: existing?.title ?? '');
    _story = TextEditingController(text: existing?.story ?? '');
    _person = TextEditingController(text: existing?.personName ?? '');
    _relationship = TextEditingController(text: existing?.relationship ?? '');
    _date = existing?.date;
    _category = existing?.category ?? MemoryCategory.family;
  }

  @override
  void dispose() {
    _title.dispose();
    _story.dispose();
    _person.dispose();
    _relationship.dispose();
    super.dispose();
  }

  bool get _hasPhoto =>
      _newPhoto != null || (widget.existing?.hasPhoto == true && !_removePhoto);

  bool get _hasVideo =>
      _newVideo != null || (widget.existing?.hasVideo == true && !_removeVideo);

  // ----------------------------------------------------------------- media

  Future<void> _pickPhoto() async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      // Resized on the way in. A phone photo is 3-4 MB and 4000px wide; a
      // card needs a tenth of that. Smaller files mean a faster vault and
      // far less storage, with no visible loss on a phone screen.
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (file == null) return; // user backed out of the chooser

      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _newPhoto = PendingMedia(
          bytes: bytes,
          extension: extensionOf(file.name, fallback: 'jpg'),
        );
        _removePhoto = false;
      });
    } catch (error) {
      debugPrint('Photo pick failed: ${error.runtimeType}');
      _toast('Could not open that photo. Please try another.');
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _pickVideo() async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final file = await _picker.pickVideo(source: ImageSource.gallery);
      if (file == null) return;

      final bytes = await file.readAsBytes();
      if (!mounted) return;

      if (bytes.length > _maxVideoBytes) {
        _toast('That video is too large. Please choose one under 60 MB.');
        return;
      }

      setState(() {
        _newVideo = PendingMedia(
          bytes: bytes,
          extension: extensionOf(file.name, fallback: 'mp4'),
        );
        _removeVideo = false;
      });
    } catch (error) {
      debugPrint('Video pick failed: ${error.runtimeType}');
      _toast('Could not open that video. Please try another.');
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  void _clearPhoto() => setState(() {
    _newPhoto = null;
    _removePhoto = widget.existing?.hasPhoto == true;
  });

  void _clearVideo() => setState(() {
    _newVideo = null;
    _removeVideo = widget.existing?.hasVideo == true;
  });

  // ------------------------------------------------------------------ date

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: DateTime(1920),
      lastDate: now,
      helpText: 'When did this happen?',
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  // ------------------------------------------------------------------ save

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();

    final existing = widget.existing;
    final memory = VaultMemory(
      id: existing?.id ?? 0, // 0: the store assigns a real id
      title: _title.text.trim(),
      story: _story.text.trim(),
      date: _date,
      personName: _person.text.trim(),
      relationship: _relationship.text.trim(),
      category: _category,
      photoRef: existing?.photoRef,
      videoRef: existing?.videoRef,
      isDemo: existing?.isDemo ?? false,
      createdAt: existing?.createdAt ?? DateTime.now(),
    );

    Navigator.of(context).pop(
      EntryEditResult<MemoryDraft>.save(
        MemoryDraft(
          memory: memory,
          newPhoto: _newPhoto,
          removePhoto: _removePhoto,
          newVideo: _newVideo,
          removeVideo: _removeVideo,
        ),
      ),
    );
  }

  Future<void> _delete() async {
    final confirmed = await confirmDestructiveAction(
      context,
      title: 'Delete this memory?',
      message: '"${widget.existing!.title}" and its photo or video will be '
          'removed. This cannot be undone.',
    );
    if (!confirmed || !mounted) return;
    Navigator.of(context).pop(const EntryEditResult<MemoryDraft>.delete());
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message, style: const TextStyle(fontSize: 18))),
      );
  }

  // ----------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Memory' : 'Add Memory'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSizes.pagePadding),
            children: [
              const FieldLabel('Title'),
              TextFormField(
                controller: _title,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                style: const TextStyle(fontSize: 20),
                decoration: const InputDecoration(
                  hintText: "For example: Ajay's birthday",
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Please give this memory a title'
                    : null,
              ),
              const SizedBox(height: AppSizes.gapLarge),

              const FieldLabel('Photo'),
              _PhotoField(
                hasPhoto: _hasPhoto,
                busy: _picking,
                preview: _newPhoto != null
                    ? MemoryPhoto(load: () async => _newPhoto!.bytes, height: 220)
                    : (_hasPhoto && widget.loadPhoto != null)
                    ? MemoryPhoto(load: widget.loadPhoto!, height: 220)
                    : null,
                onPick: _pickPhoto,
                onClear: _clearPhoto,
              ),
              const SizedBox(height: AppSizes.gapLarge),

              const FieldLabel('Video (optional)'),
              _VideoField(
                hasVideo: _hasVideo,
                isNew: _newVideo != null,
                sizeLabel: _newVideo == null
                    ? null
                    : _formatSize(_newVideo!.sizeInBytes),
                busy: _picking,
                onPick: _pickVideo,
                onClear: _clearVideo,
              ),
              const SizedBox(height: AppSizes.gapLarge),

              const FieldLabel('What happened?'),
              TextFormField(
                controller: _story,
                maxLines: 4,
                minLines: 3,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(fontSize: 20),
                decoration: const InputDecoration(
                  hintText: 'A few words about this moment',
                ),
              ),
              const SizedBox(height: AppSizes.gapLarge),

              const FieldLabel('When (optional)'),
              _DateField(date: _date, onPick: _pickDate, onClear: () => setState(() => _date = null)),
              const SizedBox(height: AppSizes.gapLarge),

              const FieldLabel('Who is this about? (optional)'),
              TextFormField(
                controller: _person,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                style: const TextStyle(fontSize: 20),
                decoration: const InputDecoration(hintText: 'For example: Ajay'),
              ),
              const SizedBox(height: AppSizes.gap),
              TextFormField(
                controller: _relationship,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                style: const TextStyle(fontSize: 20),
                decoration: const InputDecoration(
                  hintText: 'Relationship, for example: Son',
                ),
              ),
              const SizedBox(height: AppSizes.gapLarge),

              const FieldLabel('Category'),
              Wrap(
                spacing: AppSizes.gapSmall,
                runSpacing: AppSizes.gapSmall,
                children: [
                  for (final category in MemoryCategory.values)
                    ChoiceChip(
                      label: Text(category.label),
                      avatar: Icon(
                        category.icon,
                        size: 22,
                        color: _category == category ? Colors.white : category.color,
                      ),
                      selected: _category == category,
                      selectedColor: category.color,
                      labelStyle: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: _category == category ? Colors.white : AppColors.textPrimary,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _category = category),
                    ),
                ],
              ),
              const SizedBox(height: AppSizes.gapLarge),

              FilledButton.icon(
                onPressed: _picking ? null : _save,
                icon: const Icon(Icons.check_rounded, size: AppSizes.iconMedium),
                label: Text(widget.isEditing ? 'Save changes' : 'Save memory'),
              ),
              const SizedBox(height: AppSizes.gap),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),

              if (widget.isEditing) ...[
                const SizedBox(height: AppSizes.gapLarge),
                DeleteEntryButton(label: 'Delete memory', onPressed: _delete),
              ],
              const SizedBox(height: AppSizes.gapLarge),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatSize(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class _PhotoField extends StatelessWidget {
  const _PhotoField({
    required this.hasPhoto,
    required this.busy,
    required this.preview,
    required this.onPick,
    required this.onClear,
  });

  final bool hasPhoto;
  final bool busy;
  final Widget? preview;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (preview != null) ...[preview!, const SizedBox(height: AppSizes.gapSmall)],
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: busy ? null : onPick,
                icon: const Icon(Icons.photo_library_rounded, size: AppSizes.iconMedium),
                label: Text(hasPhoto ? 'Change photo' : 'Choose a photo'),
              ),
            ),
            if (hasPhoto) ...[
              const SizedBox(width: AppSizes.gapSmall),
              SizedBox(
                width: AppSizes.minTouchTarget,
                height: AppSizes.buttonHeight,
                child: IconButton.outlined(
                  onPressed: busy ? null : onClear,
                  tooltip: 'Remove photo',
                  icon: const Icon(Icons.close_rounded, size: AppSizes.iconMedium),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _VideoField extends StatelessWidget {
  const _VideoField({
    required this.hasVideo,
    required this.isNew,
    required this.sizeLabel,
    required this.busy,
    required this.onPick,
    required this.onClear,
  });

  final bool hasVideo;
  final bool isNew;
  final String? sizeLabel;
  final bool busy;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasVideo) ...[
          Container(
            padding: const EdgeInsets.all(AppSizes.gap),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(AppSizes.radius),
            ),
            child: Row(
              children: [
                const Icon(Icons.videocam_rounded, size: AppSizes.iconMedium, color: AppColors.primary),
                const SizedBox(width: AppSizes.gapSmall),
                Expanded(
                  child: Text(
                    isNew ? 'New video chosen${sizeLabel == null ? '' : ' ($sizeLabel)'}' : 'Video attached',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSizes.gapSmall),
        ],
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: busy ? null : onPick,
                icon: const Icon(Icons.video_library_rounded, size: AppSizes.iconMedium),
                label: Text(hasVideo ? 'Change video' : 'Choose a video'),
              ),
            ),
            if (hasVideo) ...[
              const SizedBox(width: AppSizes.gapSmall),
              SizedBox(
                width: AppSizes.minTouchTarget,
                height: AppSizes.buttonHeight,
                child: IconButton.outlined(
                  onPressed: busy ? null : onClear,
                  tooltip: 'Remove video',
                  icon: const Icon(Icons.close_rounded, size: AppSizes.iconMedium),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({required this.date, required this.onPick, required this.onClear});

  final DateTime? date;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onPick,
            icon: const Icon(Icons.calendar_month_rounded, size: AppSizes.iconMedium),
            label: Text(date == null ? 'Choose a date' : formatFullDate(date!)),
          ),
        ),
        if (date != null) ...[
          const SizedBox(width: AppSizes.gapSmall),
          SizedBox(
            width: AppSizes.minTouchTarget,
            height: AppSizes.buttonHeight,
            child: IconButton.outlined(
              onPressed: onClear,
              tooltip: 'Remove date',
              icon: const Icon(Icons.close_rounded, size: AppSizes.iconMedium),
            ),
          ),
        ],
      ],
    );
  }
}
