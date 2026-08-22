import 'package:flutter/material.dart';

/// One option in a single-choice list. The [key] is REQUIRED (not optional
/// as on most widgets): every interactive widget carries a ValueKey from its
/// feature's key namespace, and making it a constructor requirement is the
/// cheapest way to never forget it.
final class AppChoiceTile extends StatelessWidget {
  const AppChoiceTile({
    required Key super.key,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subtitle = this.subtitle;
    return ListTile(
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle),
      selected: selected,
      trailing: selected ? const Icon(Icons.check) : null,
      onTap: onTap,
    );
  }
}
