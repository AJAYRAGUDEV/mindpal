import 'package:flutter/material.dart';

import '../../services/notification_service.dart';
import '../../theme/app_sizes.dart';
import '../../theme/app_theme.dart';

/// "Why aren't my reminders ringing?", answered on the phone itself.
///
/// Everything here is read live from the OS, never remembered, because the
/// user can change any of it in Settings while the app is open.
///
/// The button matters more than the list. A test notification proves the
/// permission, the channel, the icon and the sound in one tap, with no alarm
/// involved — so it splits the problem cleanly:
///
///   * test rings, reminders do not  -> scheduling or timing (often a time
///     already past today, which is scheduled for tomorrow)
///   * test does not ring either     -> permission, or the channel is muted
///     in Android Settings
///
/// Without this, both cases look identical: nothing happens.
class NotificationCheckScreen extends StatefulWidget {
  const NotificationCheckScreen({super.key, required this.notifications});

  final NotificationService notifications;

  @override
  State<NotificationCheckScreen> createState() =>
      _NotificationCheckScreenState();
}

class _NotificationCheckScreenState extends State<NotificationCheckScreen> {
  bool _loading = true;
  bool _supported = false;
  bool _permitted = false;
  bool _exact = false;
  int _pending = 0;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    setState(() => _loading = true);
    final notifications = widget.notifications;

    final supported = notifications.isSupported;
    final permitted = supported && await notifications.hasPermission();
    final exact = supported && await notifications.canScheduleExactly();
    final pending = supported ? await notifications.pendingCount() : 0;

    if (!mounted) return;
    setState(() {
      _supported = supported;
      _permitted = permitted;
      _exact = exact;
      _pending = pending;
      _loading = false;
    });
  }

  Future<void> _sendTest() async {
    try {
      await widget.notifications.showTestNotification();
      if (!mounted) return;
      _say(
        'Test sent. If nothing appeared, notifications are blocked in your '
        'phone Settings.',
      );
    } catch (error) {
      if (!mounted) return;
      // The real reason, not a shrug. This is the one screen where a
      // technical detail is worth more than a soothing sentence.
      _say('Could not send it: ${error.runtimeType}', isError: true);
    }
    await _check();
  }

  Future<void> _askPermission() async {
    await widget.notifications.requestPermission();
    await _check();
  }

  void _say(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message, style: const TextStyle(fontSize: 18)),
          backgroundColor: isError ? AppColors.error : null,
          duration: const Duration(seconds: 6),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Check reminders')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(AppSizes.pagePadding),
                children: [
                  Text(
                    'Are reminders working?',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppSizes.gapSmall),
                  const Text(
                    'Tap the button below. A notification should appear '
                    'straight away, with a sound.',
                    style: TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: AppSizes.gapLarge),

                  FilledButton.icon(
                    onPressed: _supported ? _sendTest : null,
                    icon: const Icon(
                      Icons.notifications_active_rounded,
                      size: AppSizes.iconMedium,
                    ),
                    label: const Text('Send a test notification'),
                  ),
                  const SizedBox(height: AppSizes.gapLarge),

                  _CheckRow(
                    ok: _supported,
                    label: 'Notifications available on this device',
                    detail: _supported
                        ? null
                        : 'This is the web version, or notifications failed '
                              'to start. The Android app supports them.',
                  ),
                  _CheckRow(
                    ok: _permitted,
                    label: 'Permission granted',
                    detail: _permitted
                        ? null
                        : 'Turn this on, or allow notifications under '
                              'Settings > Apps > MindPal.',
                  ),
                  _CheckRow(
                    ok: _exact,
                    label: 'Allowed to ring at the exact minute',
                    // Not a failure: inexact still rings, just later.
                    isWarningWhenOff: true,
                    detail: _exact
                        ? null
                        : 'Reminders will still ring, but your phone may '
                              'delay them by a few minutes.',
                  ),
                  _CheckRow(
                    ok: _pending > 0,
                    label: _pending == 1
                        ? '1 reminder is armed'
                        : '$_pending reminders are armed',
                    isWarningWhenOff: true,
                    detail: _pending > 0
                        ? null
                        : 'No alarms are set. Add a reminder, or check that '
                              'its time has not already passed today.',
                  ),
                  const SizedBox(height: AppSizes.gapLarge),

                  if (_supported && !_permitted)
                    FilledButton.icon(
                      onPressed: _askPermission,
                      icon: const Icon(
                        Icons.lock_open_rounded,
                        size: AppSizes.iconMedium,
                      ),
                      label: const Text('Allow notifications'),
                    ),
                  const SizedBox(height: AppSizes.gap),
                  OutlinedButton.icon(
                    onPressed: _check,
                    icon: const Icon(
                      Icons.refresh_rounded,
                      size: AppSizes.iconMedium,
                    ),
                    label: const Text('Check again'),
                  ),
                  const SizedBox(height: AppSizes.gapLarge),

                  const _BatteryNote(),
                  const SizedBox(height: AppSizes.gapLarge),
                ],
              ),
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({
    required this.ok,
    required this.label,
    this.detail,
    this.isWarningWhenOff = false,
  });

  final bool ok;
  final String label;
  final String? detail;

  /// Off is "worth knowing" rather than "broken" — shown amber, not red.
  final bool isWarningWhenOff;

  @override
  Widget build(BuildContext context) {
    final color = ok
        ? const Color(0xFF1B5E20)
        : (isWarningWhenOff ? AppColors.reminder : AppColors.error);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.gap),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            ok
                ? Icons.check_circle_rounded
                : (isWarningWhenOff
                      ? Icons.info_outline_rounded
                      : Icons.cancel_rounded),
            size: 28,
            color: color,
          ),
          const SizedBox(width: AppSizes.gapSmall),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (detail != null)
                  Text(
                    detail!,
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The cause that no code can detect or fix from inside the app.
class _BatteryNote extends StatelessWidget {
  const _BatteryNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radius),
        border: Border.all(color: AppColors.reminder, width: 2),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'If everything above is ticked and it still does not ring',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: AppSizes.gapSmall),
          Text(
            'Many phones stop apps from running in the background to save '
            'battery, and that stops reminders too. Xiaomi, Redmi, Poco, '
            'Oppo, Realme, Vivo and OnePlus do this by default.\n\n'
            'Open Settings > Apps > MindPal > Battery and choose '
            '"Unrestricted" or "No restrictions". On Xiaomi and Redmi, also '
            'turn on Autostart for MindPal.',
            style: TextStyle(fontSize: 17, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
