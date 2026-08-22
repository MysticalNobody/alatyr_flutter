import 'package:flutter/material.dart' show ThemeMode;

sealed class SettingsEvent {
  const SettingsEvent();
}

/// Start mirroring the persisted settings.
final class SettingsStarted extends SettingsEvent {
  const SettingsStarted();
}

/// The user picked a theme mode.
final class SettingsThemeModeChanged extends SettingsEvent {
  const SettingsThemeModeChanged(this.themeMode);
  final ThemeMode themeMode;
}
