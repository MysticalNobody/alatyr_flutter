import 'package:flutter/material.dart' show Key, ThemeMode, ValueKey;

/// ValueKey namespace of the settings feature (`settings.*`). Patrol finders
/// address these as `$(#settings.theme_mode.dark)` or
/// `$(SettingsKeys.themeModeTile(ThemeMode.dark))`.
abstract final class SettingsKeys {
  static const String _ns = 'settings';

  static const Key screen = ValueKey<String>('$_ns.screen');
  static const Key failureBanner = ValueKey<String>('$_ns.failure');

  static Key themeModeTile(ThemeMode mode) =>
      ValueKey<String>('$_ns.theme_mode.${mode.name}');
}
