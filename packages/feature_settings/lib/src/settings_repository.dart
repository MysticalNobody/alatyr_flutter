import 'package:app_core/app_core.dart';
import 'package:flutter/material.dart' show ThemeMode;

/// Persistence port of the settings feature (package-internal; the
/// cross-feature contract is `SettingsApi` in feature_settings_api).
abstract interface class SettingsRepository {
  /// Emits the stored mode on subscription, then on every change. Missing
  /// or corrupted values map to [ThemeMode.system].
  Stream<ThemeMode> watchThemeMode();

  Future<Result<void>> saveThemeMode(ThemeMode mode);
}
