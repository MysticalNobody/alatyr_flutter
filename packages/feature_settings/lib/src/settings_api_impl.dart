import 'package:feature_settings_api/feature_settings_api.dart';
import 'package:flutter/material.dart' show ThemeMode;

import 'settings_repository.dart';

/// [SettingsApi] over the feature's repository. Package-internal: reachable
/// only through `createSettingsModule`.
final class RepositorySettingsApi implements SettingsApi {
  const RepositorySettingsApi(this._repository);

  final SettingsRepository _repository;

  @override
  Stream<ThemeMode> watchThemeMode() => _repository.watchThemeMode();
}
