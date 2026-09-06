import 'package:flutter/material.dart';

import '../l10n/language_scope.dart';
import '../models/user_profile.dart';
import '../theme/app_sizes.dart';
import '../theme/app_theme.dart';
import '../utils/app_exception.dart';
import 'settings/language_setting_row.dart';

/// The only screen on Day 1 that writes data.
///
/// It is a StatefulWidget because it owns *form* state (what is currently
/// typed in the boxes). It does NOT own the saved profile — that belongs to
/// MainShell. When the user presses Save we hand the new profile upward via
/// [onSave] and let MainShell decide what to do with it.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.profile,
    required this.onSave,
  });

  final UserProfile profile;

  /// May throw an [AppException] if saving fails.
  final Future<void> Function(UserProfile profile) onSave;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _caregiverController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile.name);
    _caregiverController = TextEditingController(
      text: widget.profile.caregiverName,
    );
  }

  @override
  void dispose() {
    // Controllers hold native resources; not disposing them leaks memory.
    _nameController.dispose();
    _caregiverController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    // Close the keyboard so the confirmation message is visible.
    FocusScope.of(context).unfocus();
    setState(() => _isSaving = true);

    final updated = widget.profile.copyWith(
      name: _nameController.text.trim(),
      // The app language is now owned by LanguageService, not by the
      // profile. We keep writing it here so the saved profile still records
      // which language the person uses, but the picker below is the one
      // source of truth.
      preferredLanguage: LanguageScope.of(context).language.englishName,
      caregiverName: _caregiverController.text.trim(),
    );

    try {
      await widget.onSave(updated);
      if (!mounted) return;
      _showMessage('Saved on this device.');
    } on AppException catch (error) {
      if (!mounted) return;
      _showMessage(error.message, isError: true);
    } catch (_) {
      if (!mounted) return;
      _showMessage('Something went wrong while saving.', isError: true);
    } finally {
      // `mounted` guards against the user leaving the screen mid-save.
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showMessage(String text, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: isError ? AppColors.error : AppColors.primaryDark,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(AppSizes.pagePadding),
        children: [
          const _FieldLabel('Your name'),
          TextFormField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            style: const TextStyle(fontSize: 20),
            decoration: const InputDecoration(hintText: 'e.g. Lakshmi'),
            validator: (value) => (value == null || value.trim().isEmpty)
                ? 'Please enter your name'
                : null,
          ),
          const SizedBox(height: AppSizes.gapLarge),

          _FieldLabel(LanguageScope.of(context).appLanguage),
          const LanguageSettingRow(),
          const SizedBox(height: AppSizes.gapLarge),

          const _FieldLabel('Caregiver name'),
          TextFormField(
            controller: _caregiverController,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            style: const TextStyle(fontSize: 20),
            decoration: const InputDecoration(
              hintText: 'Family member or helper (optional)',
            ),
            onFieldSubmitted: (_) => _handleSave(),
          ),
          const SizedBox(height: AppSizes.gapLarge),

          FilledButton.icon(
            onPressed: _isSaving ? null : _handleSave,
            icon: _isSaving
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check, size: AppSizes.iconMedium),
            label: Text(_isSaving ? 'Saving...' : 'Save my details'),
          ),
          const SizedBox(height: AppSizes.gap),

          const _PrivacyNote(),
          const SizedBox(height: AppSizes.gapLarge),
        ],
      ),
    );
  }
}

/// A large label above each field.
///
/// Placed above rather than as a floating `labelText` because a label that
/// shrinks and moves when tapped is hard to read for our users.
class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.gapSmall),
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.lock_outline, color: AppColors.primary),
        const SizedBox(width: AppSizes.gapSmall),
        Expanded(
          child: Text(
            'Your details stay on this phone. Nothing is sent to the internet.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}
