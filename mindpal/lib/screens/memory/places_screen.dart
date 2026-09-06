import 'package:flutter/material.dart';

import '../../models/place.dart';
import '../../storage/json_list_store.dart';
import '../../theme/app_theme.dart';
import '../../utils/guarded_action.dart';
import '../../widgets/entry_card.dart';
import '../../widgets/entry_list_scaffold.dart';
import 'edit_place_screen.dart';
import 'entry_edit_result.dart';

/// The list of saved places. Same structure as PeopleScreen.
class PlacesScreen extends StatefulWidget {
  const PlacesScreen({super.key, required this.store});

  final JsonListStore<Place> store;

  @override
  State<PlacesScreen> createState() => _PlacesScreenState();
}

class _PlacesScreenState extends State<PlacesScreen> {
  List<Place> _places = const [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final places = await widget.store.loadAll();
    if (!mounted) return;
    setState(() {
      _places = _sorted(places);
      _isLoading = false;
    });
  }

  List<Place> _sorted(List<Place> places) {
    final copy = [...places];
    copy.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return copy;
  }

  Future<void> _openEditor([Place? existing]) async {
    final result = await Navigator.of(context).push<EntryEditResult<Place>>(
      MaterialPageRoute(builder: (_) => EditPlaceScreen(existing: existing)),
    );
    if (!mounted || result == null) return;

    if (result.deleted) {
      final updated = await runGuarded(
        context,
        () => widget.store.remove(_places, existing!.id),
        successMessage: 'Place deleted.',
      );
      if (updated != null && mounted) setState(() => _places = _sorted(updated));
      return;
    }

    final place = result.item!;
    final updated = existing == null
        ? await runGuarded(
            context,
            () => widget.store.add(
              _places,
              (id) => Place(
                id: id,
                name: place.name,
                description: place.description,
                address: place.address,
                createdAt: place.createdAt,
              ),
            ),
            successMessage: 'Place saved.',
          )
        : await runGuarded(
            context,
            () => widget.store.update(_places, place),
            successMessage: 'Changes saved.',
          );

    if (updated != null && mounted) setState(() => _places = _sorted(updated));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Places')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return EntryListScaffold(
      title: 'Places',
      addLabel: 'Add Place',
      onAdd: _openEditor,
      accentColor: AppColors.primary,
      emptyIcon: Icons.place_rounded,
      emptyTitle: 'No places saved yet',
      emptyMessage:
          'Add the places you want to remember — home, the hospital, '
          'the temple.',
      items: [
        for (final place in _places)
          EntryCard(
            key: ValueKey(place.id),
            icon: Icons.place_rounded,
            accentColor: AppColors.primary,
            title: place.name,
            subtitle: place.description,
            trailingLine: place.address.isEmpty ? null : place.address,
            onTap: () => _openEditor(place),
          ),
      ],
    );
  }
}
