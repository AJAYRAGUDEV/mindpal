import 'package:flutter/material.dart';

import '../theme/app_sizes.dart';

/// A large label above a form field.
///
/// Placed above the box rather than using Flutter's floating `labelText`,
/// which shrinks and slides up when the field is tapped — hard to read for an
/// eye that struggles with small moving text.
///
/// The profile and reminder forms each grew their own private copy of this on
/// Days 1 and 3. Now that a third and fourth form need it, it earns its own
/// file. (Those two older forms are left alone — they work.)
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.gapSmall),
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}
