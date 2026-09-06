import 'package:flutter/material.dart';

/// A heading like "Today's Overview".
///
/// Wrapped in Semantics(header: true) so screen readers (TalkBack) announce it
/// as a heading and let the user jump between sections.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(text, style: Theme.of(context).textTheme.titleLarge),
    );
  }
}
