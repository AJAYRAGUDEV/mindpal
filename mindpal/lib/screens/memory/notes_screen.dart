import 'package:flutter/material.dart';

import '../../models/memory_note.dart';
import '../../storage/json_list_store.dart';
import '../../theme/app_theme.dart';
import '../../utils/date_formats.dart';
import '../../utils/guarded_action.dart';
import '../../widgets/entry_card.dart';
import '../../widgets/entry_list_scaffold.dart';
import 'edit_note_screen.dart';
import 'entry_edit_result.dart';

/// The list of saved notes. Same structure as PeopleScreen and PlacesScreen.
class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key, required this.store});

  final JsonListStore<MemoryNote> store;

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  List<MemoryNote> _notes = const [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final notes = await widget.store.loadAll();
    if (!mounted) return;
    setState(() {
      _notes = _sorted(notes);
      _isLoading = false;
    });
  }

  List<MemoryNote> _sorted(List<MemoryNote> notes) {
    final copy = [...notes];
    // Most recently changed first — unlike people and places, which are
    // alphabetical. You look a person up by name, but you look for the note
    // you were just working on.
    copy.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return copy;
  }

  Future<void> _openEditor([MemoryNote? existing]) async {
    final result = await Navigator.of(context).push<EntryEditResult<MemoryNote>>(
      MaterialPageRoute(builder: (_) => EditNoteScreen(existing: existing)),
    );
    if (!mounted || result == null) return;

    if (result.deleted) {
      final updated = await runGuarded(
        context,
        () => widget.store.remove(_notes, existing!.id),
        successMessage: 'Note deleted.',
      );
      if (updated != null && mounted) setState(() => _notes = _sorted(updated));
      return;
    }

    final note = result.item!;
    final updated = existing == null
        ? await runGuarded(
            context,
            () => widget.store.add(
              _notes,
              (id) => MemoryNote(
                id: id,
                title: note.title,
                content: note.content,
                createdAt: note.createdAt,
                updatedAt: note.updatedAt,
              ),
            ),
            successMessage: 'Note saved.',
          )
        : await runGuarded(
            context,
            () => widget.store.update(_notes, note),
            successMessage: 'Changes saved.',
          );

    if (updated != null && mounted) setState(() => _notes = _sorted(updated));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Notes')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return EntryListScaffold(
      title: 'Notes',
      addLabel: 'Add Note',
      onAdd: _openEditor,
      accentColor: AppColors.memory,
      emptyIcon: Icons.sticky_note_2_rounded,
      emptyTitle: 'No notes yet',
      emptyMessage:
          'Write down anything you want to keep — instructions, '
          'important details, things to remember.',
      items: [
        for (final note in _notes)
          EntryCard(
            key: ValueKey(note.id),
            icon: Icons.sticky_note_2_rounded,
            accentColor: AppColors.memory,
            title: note.title,
            subtitle: note.preview,
            trailingLine: formatFullDate(note.updatedAt),
            onTap: () => _openEditor(note),
          ),
      ],
    );
  }
}
