import 'package:flutter/material.dart';

import '../tokens/app_radii.dart';

/// The app's light and dark [ThemeData], derived from one seed colour so
/// both modes stay consistent.
abstract final class AppTheme {
  static const Color _seed = Color(0xFF3F51B5);

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: _seed, brightness: brightness),
    listTileTheme: const ListTileThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(AppRadii.md),
      ),
    ),
  );
}
