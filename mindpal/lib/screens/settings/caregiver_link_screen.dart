import 'package:flutter/material.dart';

import '../../services/care/care_sync_service.dart';
import '../../theme/app_sizes.dart';
import '../../theme/app_theme.dart';
import '../../widgets/confirm_dialog.dart';

/// "People who help me" — where the patient shares with a caregiver.
///
/// The consent screen. Everything a caregiver can ever do starts with the
/// code shown here, and the patient is the one who reads it out, so the
/// wording avoids anything that sounds like a setting being switched on
/// behind them. Nothing is shared until they choose to speak the code.
class CaregiverLinkScreen extends StatefulWidget {
  const CaregiverLinkScreen({
    super.key,
    required this.sync,
    required this.patientName,
    required this.onUnpaired,
  });

  final CareSyncService sync;
  final String patientName;

  /// Called after unpairing, so the shell can refresh its reminder list.
  final Future<void> Function() onUnpaired;

  @override
  State<CaregiverLinkScreen> createState() => _CaregiverLinkScreenState();
}

class _CaregiverLinkScreenState extends State<CaregiverLinkScreen> {
  String? _code;
  DateTime? _expiresAt;
  bool _busy = false;

  Future<void> _getCode() async {
    setState(() => _busy = true);
    try {
      final result = await widget.sync.requestLinkCode(widget.patientName);
      if (!mounted) return;
      setState(() {
        _code = result.code;
        _expiresAt = result.expiresAt;
      });
    } catch (error) {
      if (mounted) _say('$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _unpair() async {
    final confirmed = await confirmDestructiveAction(
      context,
      title: 'Stop sharing?',
      message: 'Your helpers will no longer see anything, and the reminders '
          'they set will be removed from this phone. You can share again '
          'later with a new code.',
      confirmLabel: 'Stop sharing',
    );
    if (!confirmed || !mounted) return;

    setState(() => _busy = true);
    await widget.onUnpaired();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _code = null;
    });
    _say('Sharing stopped.');
  }

  void _say(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message, style: const TextStyle(fontSize: 18))),
      );
  }

  @override
  Widget build(BuildContext context) {
    final paired = widget.sync.isPaired;

    return Scaffold(
      appBar: AppBar(title: const Text('People who help me')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSizes.pagePadding),
          children: [
            if (!widget.sync.isConfigured)
              const _Note(
                icon: Icons.cloud_off_rounded,
                text: 'Sharing is not set up in this version of the app.',
              )
            else ...[
              Text(
                'Share with someone who helps you',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSizes.gapSmall),
              const Text(
                'A family member can set reminders for you from their own '
                'computer. They will only see what you allow.',
                style: TextStyle(fontSize: 19),
              ),
              const SizedBox(height: AppSizes.gapLarge),

              if (_code != null) _CodeCard(code: _code!, expiresAt: _expiresAt),

              FilledButton.icon(
                onPressed: _busy ? null : _getCode,
                icon: const Icon(Icons.qr_code_2_rounded, size: AppSizes.iconMedium),
                label: Text(_code == null ? 'Get a code' : 'Get a new code'),
              ),
              const SizedBox(height: AppSizes.gapSmall),
              const Text(
                'Read the code to them. It stops working after 15 minutes.',
                style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
              ),

              const SizedBox(height: AppSizes.gapLarge),
              const _Note(
                icon: Icons.lock_outline_rounded,
                text: 'Your photos, memories and answers stay on this phone. '
                    'A helper sees only what you allow, and you can stop '
                    'sharing at any time.',
              ),

              if (paired) ...[
                const SizedBox(height: AppSizes.gapLarge),
                Text(
                  'Reminders from your helpers',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  widget.sync.managedCount == 0
                      ? 'None yet.'
                      : '${widget.sync.managedCount} on this phone.',
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(height: AppSizes.gapLarge),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _unpair,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error, width: 2),
                  ),
                  icon: const Icon(Icons.link_off_rounded, size: AppSizes.iconMedium),
                  label: const Text('Stop sharing'),
                ),
              ],
            ],
            const SizedBox(height: AppSizes.gapLarge),
          ],
        ),
      ),
    );
  }
}

class _CodeCard extends StatelessWidget {
  const _CodeCard({required this.code, required this.expiresAt});

  final String code;
  final DateTime? expiresAt;

  @override
  Widget build(BuildContext context) {
    final minutes = expiresAt?.difference(DateTime.now()).inMinutes;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSizes.gapLarge),
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(AppSizes.radius),
        border: Border.all(color: AppColors.primary, width: 2),
      ),
      child: Column(
        children: [
          const Text(
            'Read this to your helper',
            style: TextStyle(fontSize: 17, color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSizes.gapSmall),
          Text(
            // Spaced out: six characters read aloud one at a time are far
            // easier to get right than a run of six.
            code.split('').join(' '),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 42,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
              color: AppColors.primaryDark,
            ),
          ),
          if (minutes != null && minutes > 0) ...[
            const SizedBox(height: AppSizes.gapSmall),
            Text(
              'Works for about $minutes more minutes.',
              style: const TextStyle(fontSize: 16, color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
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
          Icon(icon, size: 26, color: AppColors.primary),
          const SizedBox(width: AppSizes.gapSmall),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 17)),
          ),
        ],
      ),
    );
  }
}
