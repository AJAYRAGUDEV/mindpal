import 'package:flutter/material.dart';

import '../../models/person.dart';
import '../../storage/json_list_store.dart';
import '../../theme/app_theme.dart';
import '../../utils/guarded_action.dart';
import '../../widgets/entry_card.dart';
import '../../widgets/entry_list_scaffold.dart';
import 'edit_person_screen.dart';
import 'entry_edit_result.dart';

/// The list of saved people.
///
/// This screen owns its own list and talks to the store directly, rather than
/// receiving data from MainShell. That is a deliberate difference from the
/// Reminders screen:
///
///   * Reminders live in MainShell because Home also needs them.
///   * Nothing outside this screen needs the people list, so it keeps it
///     itself. Pushing it up to MainShell would add plumbing for no benefit.
///
/// The Memory hub reloads its own copy when you come back, so search stays
/// up to date.
class PeopleScreen extends StatefulWidget {
  const PeopleScreen({super.key, required this.store});

  final JsonListStore<Person> store;

  @override
  State<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends State<PeopleScreen> {
  List<Person> _people = const [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final people = await widget.store.loadAll();
    if (!mounted) return;
    setState(() {
      _people = _sorted(people);
      _isLoading = false;
    });
  }

  List<Person> _sorted(List<Person> people) {
    final copy = [...people];
    // Alphabetical: the order a person would expect when looking someone up.
    copy.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return copy;
  }

  /// Opens the form, then applies whatever it decided.
  Future<void> _openEditor([Person? existing]) async {
    final result = await Navigator.of(context).push<EntryEditResult<Person>>(
      MaterialPageRoute(builder: (_) => EditPersonScreen(existing: existing)),
    );
    if (!mounted || result == null) return; // user backed out

    if (result.deleted) {
      final updated = await runGuarded(
        context,
        () => widget.store.remove(_people, existing!.id),
        successMessage: 'Person deleted.',
      );
      if (updated != null && mounted) setState(() => _people = _sorted(updated));
      return;
    }

    final person = result.item!;
    final updated = existing == null
        // New: the store hands out the id, so we rebuild the person with it.
        ? await runGuarded(
            context,
            () => widget.store.add(
              _people,
              (id) => Person(
                id: id,
                name: person.name,
                relationship: person.relationship,
                phone: person.phone,
                imagePath: person.imagePath,
                createdAt: person.createdAt,
              ),
            ),
            successMessage: 'Person saved.',
          )
        : await runGuarded(
            context,
            () => widget.store.update(_people, person),
            successMessage: 'Changes saved.',
          );

    if (updated != null && mounted) setState(() => _people = _sorted(updated));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('People')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return EntryListScaffold(
      title: 'People',
      addLabel: 'Add Person',
      onAdd: _openEditor,
      accentColor: AppColors.activity,
      emptyIcon: Icons.people_alt_rounded,
      emptyTitle: 'No people saved yet',
      emptyMessage:
          'Add the people who matter to you — family, friends, your doctor.',
      items: [
        for (final person in _people)
          EntryCard(
            key: ValueKey(person.id),
            initial: person.initial,
            accentColor: AppColors.activity,
            title: person.name,
            subtitle: person.relationship,
            trailingLine: person.phone.isEmpty ? null : person.phone,
            onTap: () => _openEditor(person),
          ),
      ],
    );
  }
}
