import 'package:flutter/material.dart' show ThemeMode;

/// What other parts of the app may ask the settings feature.
///
/// Only `app/` constructs the implementation (through the module factory);
/// consumers depend on this package alone.
abstract interface class SettingsApi {
  /// Emits the effective theme mode on subscription and then on every
  /// change. A missing or corrupted stored value is reported as
  /// [ThemeMode.system] - the stream never errors because of bad data.
  Stream<ThemeMode> watchThemeMode();
}
