import 'package:app_core/app_core.dart';
import 'package:data_local/data_local.dart';
import 'package:feature_settings_api/feature_settings_api.dart';
import 'package:flutter/material.dart' show ThemeMode;

import 'settings_repository.dart';

/// [SettingsRepository] over data_local's key-value DAO.
final class DriftSettingsRepository implements SettingsRepository {
  // Private named initializing formal (Dart 3.12): callers still write
  // `logger:`; flutter_lints' prefer_initializing_formals rejects the
  // `: _logger = logger` spelling under --fatal-infos.
  DriftSettingsRepository(this._dao, {this._logger = const NoopLogger()});

  /// Storage key of the theme mode (value: `ThemeMode.name`).
  static const String themeModeKey = 'settings.theme_mode';

  final KeyValueDao _dao;
  final AppLogger _logger;

  @override
  Stream<ThemeMode> watchThemeMode() => _dao.watch(themeModeKey).map(_decode);

  @override
  Future<Result<void>> saveThemeMode(ThemeMode mode) async {
    try {
      await _dao.write(themeModeKey, mode.name);
      return const Ok(null);
    } on Exception catch (e) {
      return Err(
        AppFailure(
          code: SettingsFailureCodes.save,
          message: 'Could not persist the theme mode',
          cause: e,
        ),
      );
    }
  }

  ThemeMode _decode(String? raw) {
    if (raw == null) return ThemeMode.system;
    final mode = ThemeMode.values.where((m) => m.name == raw).firstOrNull;
    if (mode == null) {
      _logger.warn('settings: unknown stored theme mode "$raw", using system');
      return ThemeMode.system;
    }
    return mode;
  }
}
