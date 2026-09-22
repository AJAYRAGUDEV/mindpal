import 'package:flutter/material.dart';

import '../../models/vault_memory.dart';
import '../../services/memory_aid_service.dart';
import '../../services/memory_vault_service.dart';
import '../../theme/app_sizes.dart';
import '../../theme/app_theme.dart';
import '../../widgets/overview_card.dart';
import '../../widgets/section_title.dart';
import 'notes_screen.dart';
import 'people_screen.dart';
import 'places_screen.dart';
import '../vault/memory_vault_screen.dart';

/// The Memory Aid hub — the Memory tab's front page.
///
/// It owns the counts and the search index for the whole section. Each list
/// screen keeps its own working copy while open; when it closes we reload
/// here, so counts and search never go stale.
class MemoryHubScreen extends StatefulWidget {
  const MemoryHubScreen({
    super.key,
    required this.service,
    required this.vault,
  });

  final MemoryAidService service;
  final MemoryVaultService vault;

  @override
  State<MemoryHubScreen> createState() => _MemoryHubScreenState();
}

class _MemoryHubScreenState extends State<MemoryHubScreen> {
  final _searchController = TextEditingController();

  MemoryAidData _data = const MemoryAidData();
  List<VaultMemory> _memories = const [];
  String _query = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final data = await widget.service.loadAll();
    final memories = await widget.vault.loadAll();
    if (!mounted) return;
    setState(() {
      _data = data;
      _memories = memories;
      _isLoading = false;
    });
  }

  /// Opens a section, then refreshes when it closes.
  ///
  /// `await Navigator.push(...)` finishes when the pushed screen pops, so the
  /// line after it is "the user has come back" — the natural place to reload.
  Future<void> _openSection(Widget screen) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => screen));
    if (!mounted) return;
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final results = widget.service.search(_data, _query);
    final isSearching = _query.trim().isNotEmpty;

    return ListView(
      padding: const EdgeInsets.all(AppSizes.pagePadding),
      children: [
        Text(
          'Keep important information easy to remember.',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: AppSizes.gapLarge),

        _SearchField(
          controller: _searchController,
          onChanged: (value) => setState(() => _query = value),
          onClear: () {
            _searchController.clear();
            setState(() => _query = '');
          },
        ),
        const SizedBox(height: AppSizes.gapLarge),

        // While searching, the four section cards are replaced by results.
        // Showing both at once would double the length of the page.
        if (isSearching)
          _SearchResults(results: results, query: _query)
        else ...[
          const SectionTitle('Sections'),
          const SizedBox(height: AppSizes.gap),
          OverviewCard(
            icon: Icons.people_alt_rounded,
            accentColor: AppColors.activity,
            title: 'People',
            message: _countLabel(
              _data.people.length,
              'person',
              'people',
              'People important to you',
            ),
            onTap: () =>
                _openSection(PeopleScreen(store: widget.service.people)),
          ),
          const SizedBox(height: AppSizes.gap),
          OverviewCard(
            icon: Icons.place_rounded,
            accentColor: AppColors.primary,
            title: 'Places',
            message: _countLabel(
              _data.places.length,
              'place',
              'places',
              'Familiar places',
            ),
            onTap: () =>
                _openSection(PlacesScreen(store: widget.service.places)),
          ),
          const SizedBox(height: AppSizes.gap),
          OverviewCard(
            icon: Icons.sticky_note_2_rounded,
            accentColor: AppColors.memory,
            title: 'Notes',
            message: _countLabel(
              _data.notes.length,
              'note',
              'notes',
              'Important things to remember',
            ),
            onTap: () => _openSection(NotesScreen(store: widget.service.notes)),
          ),
          const SizedBox(height: AppSizes.gap),
          OverviewCard(
            icon: Icons.photo_album_rounded,
            accentColor: AppColors.reminder,
            title: 'Memory Vault',
            message: _countLabel(
              _memories.length,
              'memory',
              'memories',
              'Photos, videos and moments to revisit',
            ),
            onTap: () =>
                _openSection(MemoryVaultScreen(service: widget.vault)),
          ),
        ],
        const SizedBox(height: AppSizes.gapLarge),
      ],
    );
  }

  /// "3 people saved" / "1 person saved" / the description when empty.
  String _countLabel(int count, String singular, String plural, String empty) {
    if (count == 0) return empty;
    return '$count ${count == 1 ? singular : plural} saved';
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 20),
      decoration: InputDecoration(
        hintText: 'Search people, places and notes',
        prefixIcon: const Icon(
          Icons.search_rounded,
          size: 30,
          color: AppColors.textSecondary,
        ),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close_rounded, size: 28),
                tooltip: 'Clear search',
                onPressed: onClear,
              ),
      ),
    );
  }
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({required this.results, required this.query});

  final List<SearchResult> results;
  final String query;

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('No matches'),
          const SizedBox(height: AppSizes.gapSmall),
          Text(
            'Nothing saved matches "${query.trim()}".',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          '${results.length} ${results.length == 1 ? "match" : "matches"}',
        ),
        const SizedBox(height: AppSizes.gap),
        for (final result in results) ...[
          _ResultTile(result: result),
          const SizedBox(height: AppSizes.gap),
        ],
      ],
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.result});

  final SearchResult result;

  (IconData, Color, String) get _style => switch (result.kind) {
    SearchResultKind.person => (
      Icons.people_alt_rounded,
      AppColors.activity,
      'Person',
    ),
    SearchResultKind.place => (Icons.place_rounded, AppColors.primary, 'Place'),
    SearchResultKind.note => (
      Icons.sticky_note_2_rounded,
      AppColors.memory,
      'Note',
    ),
  };

  @override
  Widget build(BuildContext context) {
    final (icon, color, kindLabel) = _style;

    return Container(
      padding: const EdgeInsets.all(AppSizes.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radius),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, size: 28, color: Colors.white),
          ),
          const SizedBox(width: AppSizes.gap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  kindLabel,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                Text(
                  result.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (result.subtitle.trim().isNotEmpty)
                  Text(
                    result.subtitle,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
