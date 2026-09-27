import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../models/reminder.dart';
import '../../storage/local_storage.dart';
import '../reminder_service.dart';
import 'care_client.dart';

/// What one sync did, for the UI to report.
class SyncReport {
  const SyncReport({
    this.added = 0,
    this.updated = 0,
    this.removed = 0,
    this.skipped = false,
    this.error,
  });

  final int added;
  final int updated;
  final int removed;

  /// True when there was nothing to do — not paired, or no backend.
  final bool skipped;

  final String? error;

  bool get changedAnything => added > 0 || updated > 0 || removed > 0;
  int get total => added + updated + removed;
}

/// Pulls caregiver reminders onto this device and schedules them.
///
/// PULL, NOT PUSH. The phone asks when it has a connection rather than the
/// server pushing. That needs no Firebase, no token registration and no
/// notification permission beyond the one reminders already use — and a
/// phone that has been off for a week catches up in a single request,
/// because the cursor is a revision number and not "what did I miss".
///
/// THE DUPLICATE PROBLEM, AND HOW IT IS SOLVED. Local reminders and remote
/// ones both need ids, and the local id doubles as the Android notification
/// id. If a remote reminder were given a fresh local id on every sync, each
/// sync would schedule another alarm and the user would be told to take
/// their medicine four times.
///
/// So this class keeps a map from remote id to local id, saved on the
/// device. A remote reminder that is already known UPDATES the local one it
/// maps to — same id, so [ReminderService.update] cancels the old alarm and
/// schedules the new one — and only a genuinely new remote reminder gets a
/// new local id. Syncing twice with no server changes does nothing at all.
///
/// Reminders the patient made themselves are untouched. They are simply not
/// in the map, and nothing here deletes a reminder that is not.
class CareSyncService {
  /// Positional, like ReminderService and ProfileService: a named parameter
  /// may not start with an underscore, so a private field can only be an
  /// initializing formal when the parameter is positional.
  CareSyncService(this._storage, this._reminders, {CareClient? client})
    : _client = client ?? CareClient();

  final LocalStorage _storage;
  final ReminderService _reminders;
  final CareClient _client;

  static const String _deviceKeyKey = 'care_device_key_v1';
  static const String _revKey = 'care_last_rev_v1';
  static const String _mapKey = 'care_remote_map_v1';

  /// Never sync more often than this, however many times resume fires.
  /// Returning to the app repeatedly should not hammer a free-tier server.
  static const Duration _minimumGap = Duration(minutes: 2);

  DateTime? _lastSyncAt;
  bool _inFlight = false;

  // ------------------------------------------------------------- pairing

  String? get deviceKey => _storage.readString(_deviceKeyKey);
  bool get isPaired => (deviceKey ?? '').isNotEmpty;
  bool get isConfigured => _client.isConfigured;

  /// Claims a device identity from the server and stores it.
  ///
  /// Idempotent: if this device already has a key it is kept, so pairing
  /// with a second caregiver does not orphan the first.
  Future<String> ensureDevice(String displayName) async {
    final existing = deviceKey;
    if (existing != null && existing.isNotEmpty) return existing;

    final key = await _client.registerDevice(
      displayName.trim().isEmpty ? 'MindPal user' : displayName,
    );
    await _storage.writeString(_deviceKeyKey, key);
    return key;
  }

  /// A short code for the patient to read to their caregiver.
  Future<({String code, DateTime expiresAt})> requestLinkCode(
    String displayName,
  ) async {
    final key = await ensureDevice(displayName);
    return _client.requestLinkCode(key);
  }

  /// Who is linked to this patient, and what each may do.
  ///
  /// Read live from the server every time rather than cached: permissions
  /// are the thing a user is most likely to change and most needs to see
  /// the truth about.
  Future<List<CareLink>> listLinks() async {
    final key = deviceKey;
    if (key == null || key.isEmpty) return const [];
    return _client.listLinks(key);
  }

  /// Grants or withdraws one caregiver's permissions.
  Future<void> setPermissions({
    required int caregiverId,
    required Map<String, bool> permissions,
  }) async {
    final key = deviceKey;
    if (key == null || key.isEmpty) {
      throw const CareException('This phone is not sharing with anyone.');
    }
    await _client.setPermissions(
      deviceKey: key,
      caregiverId: caregiverId,
      permissions: permissions,
    );
  }

  /// Ends one caregiver's access, leaving any others in place.
  Future<void> revokeCaregiver(int caregiverId) async {
    final key = deviceKey;
    if (key == null || key.isEmpty) return;
    await _client.revokeLink(deviceKey: key, caregiverId: caregiverId);
  }

  /// Forgets the pairing and everything that came with it.
  ///
  /// The reminders a caregiver added are removed too, with their alarms
  /// cancelled: keeping them would leave the patient with reminders nobody
  /// can change any more.
  Future<List<Reminder>> unpair(List<Reminder> current) async {
    var list = current;
    for (final localId in _readMap().values) {
      list = await _reminders.remove(list, localId);
    }
    await _storage.remove(_deviceKeyKey);
    await _storage.remove(_revKey);
    await _storage.remove(_mapKey);
    return list;
  }

  // ---------------------------------------------------------------- sync

  /// Pulls changes and applies them. Never throws.
  ///
  /// [force] skips the rate limit, for a button the user pressed.
  Future<SyncReport> sync(
    List<Reminder> current, {
    bool force = false,
    required void Function(List<Reminder> updated) onChanged,
  }) async {
    if (!_client.isConfigured || !isPaired) {
      return const SyncReport(skipped: true);
    }
    if (_inFlight) return const SyncReport(skipped: true);

    final last = _lastSyncAt;
    if (!force && last != null && DateTime.now().difference(last) < _minimumGap) {
      return const SyncReport(skipped: true);
    }

    _inFlight = true;
    try {
      final result = await _client.sync(
        deviceKey: deviceKey!,
        sinceRev: _readRev(),
      );

      if (result.reminders.isEmpty) {
        // Still record the time, so an offline-then-empty sync does not
        // retry every two minutes forever.
        _lastSyncAt = DateTime.now();
        return const SyncReport();
      }

      final report = await _apply(result.reminders, current, onChanged);
      await _storage.writeString(_revKey, result.highestRev.toString());
      _lastSyncAt = DateTime.now();
      return report;
    } on CareException catch (error) {
      // Offline is ordinary. The local reminders and their alarms are
      // untouched, which is the whole point of doing this offline-first.
      debugPrint('CARE: sync skipped (${error.message})');
      return SyncReport(error: error.message);
    } catch (error) {
      debugPrint('CARE: sync failed (${error.runtimeType})');
      return const SyncReport(error: 'Sync failed.');
    } finally {
      _inFlight = false;
    }
  }

  Future<SyncReport> _apply(
    List<RemoteReminder> remote,
    List<Reminder> current,
    void Function(List<Reminder>) onChanged,
  ) async {
    final map = _readMap();
    var list = current;
    var added = 0;
    var updated = 0;
    var removed = 0;

    for (final item in remote) {
      final localId = map[item.id.toString()];

      if (item.deleted) {
        if (localId != null) {
          // remove() cancels the alarm, which is the reason this goes
          // through ReminderService rather than touching storage directly.
          list = await _reminders.remove(list, localId);
          map.remove(item.id.toString());
          removed += 1;
        }
        continue;
      }

      if (localId != null) {
        final existing = list.where((r) => r.id == localId).firstOrNull;
        if (existing != null) {
          // update() cancels the old alarm before scheduling the new one, so
          // a changed time does not ring twice.
          list = await _reminders.update(list, _merge(existing, item));
          updated += 1;
          continue;
        }
        // Mapped but gone — the patient deleted it locally. Treat as new.
        map.remove(item.id.toString());
      }

      final before = list.map((r) => r.id).toSet();
      list = await _reminders.add(list, _toReminder(item));
      final newId = list
          .map((r) => r.id)
          .firstWhere((id) => !before.contains(id), orElse: () => -1);
      if (newId != -1) map[item.id.toString()] = newId;
      added += 1;
    }

    await _storage.writeString(_mapKey, jsonEncode(map));
    onChanged(list);

    debugPrint('CARE: +$added ~$updated -$removed from the caregiver site');
    return SyncReport(added: added, updated: updated, removed: removed);
  }

  /// A remote reminder as a local draft. id 0: the store assigns the real one.
  Reminder _toReminder(RemoteReminder item) => Reminder(
    id: 0,
    title: item.title,
    category: ReminderCategory.fromName(item.category),
    hour: item.hour,
    minute: item.minute,
    repeat: ReminderRepeat.fromName(item.repeat),
    notes: item.notes,
    createdAt: DateTime.now(),
  );

  /// Server fields win; the local completion state is kept.
  ///
  /// Completion belongs to the patient — ticking off this morning's medicine
  /// is a fact about their day, and a caregiver editing the wording at noon
  /// must not un-tick it.
  Reminder _merge(Reminder existing, RemoteReminder item) => existing.copyWith(
    title: item.title,
    category: ReminderCategory.fromName(item.category),
    hour: item.hour,
    minute: item.minute,
    repeat: ReminderRepeat.fromName(item.repeat),
    notes: item.notes,
  );

  // ------------------------------------------------------------- storage

  int _readRev() => int.tryParse(_storage.readString(_revKey) ?? '') ?? 0;

  Map<String, int> _readMap() {
    final raw = _storage.readString(_mapKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return {
        for (final entry in decoded.entries)
          entry.key: (entry.value as num).toInt(),
      };
    } catch (error) {
      // A corrupt map would make every sync re-add everything. Starting over
      // is bad (duplicates once) but recoverable; looping forever is not.
      debugPrint('CARE: remote id map unreadable, starting over: $error');
      return {};
    }
  }

  /// How many of the local reminders came from a caregiver.
  int get managedCount => _readMap().length;

  /// True when this local reminder is one a caregiver controls.
  bool isManaged(int localId) => _readMap().values.contains(localId);

  void dispose() => _client.dispose();
}
