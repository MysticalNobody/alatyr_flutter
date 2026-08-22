import 'package:app_core/app_core.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:freezed_annotation/freezed_annotation.dart';

part 'settings_state.freezed.dart';

@freezed
sealed class SettingsState with _$SettingsState {
  const factory SettingsState.loading() = SettingsLoading;

  /// [lastFailure] is set when the most recent save failed; the shown
  /// [themeMode] is still the persisted one.
  const factory SettingsState.ready({
    required ThemeMode themeMode,
    AppFailure? lastFailure,
  }) = SettingsReady;
}
