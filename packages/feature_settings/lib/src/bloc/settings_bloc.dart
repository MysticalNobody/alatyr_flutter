import 'package:app_core/app_core.dart';
import 'package:feature_settings_api/feature_settings_api.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../settings_repository.dart';
import 'settings_event.dart';
import 'settings_state.dart';

/// Persistence is the single source of truth: the bloc mirrors the
/// repository stream and a successful save reaches the UI through that
/// stream, never by echoing the event. Handlers run concurrently (bloc's
/// default transformer), so the long-lived `SettingsStarted` handler does
/// not block saves - but saves themselves are serialized, otherwise a slow
/// earlier save could land after (and overwrite) a later choice.
final class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  SettingsBloc(this._repository) : super(const SettingsState.loading()) {
    on<SettingsStarted>(_onStarted);
    on<SettingsThemeModeChanged>(_onThemeModeChanged, transformer: _sequential);
  }

  /// One event at a time, in order (what `bloc_concurrency`'s `sequential()`
  /// does; inlined to keep the canonical stack minimal).
  static Stream<SettingsThemeModeChanged> _sequential(
    Stream<SettingsThemeModeChanged> events,
    Stream<SettingsThemeModeChanged> Function(SettingsThemeModeChanged) mapper,
  ) => events.asyncExpand(mapper);

  final SettingsRepository _repository;

  Future<void> _onStarted(SettingsStarted event, Emitter<SettingsState> emit) =>
      emit.forEach<ThemeMode>(
        _repository.watchThemeMode(),
        onData: (mode) => SettingsState.ready(themeMode: mode),
        // Without onError a stream error would escape the handler as an
        // uncaught error and silently end the mirror. Keep the last known mode
        // (or system) and surface the failure; the subscription stays alive.
        onError: (error, stackTrace) => SettingsState.ready(
          themeMode: switch (state) {
            SettingsReady(:final themeMode) => themeMode,
            SettingsLoading() => ThemeMode.system,
          },
          lastFailure: AppFailure(
            code: SettingsFailureCodes.load,
            message: 'Could not read the stored settings',
            cause: error,
          ),
        ),
      );

  Future<void> _onThemeModeChanged(
    SettingsThemeModeChanged event,
    Emitter<SettingsState> emit,
  ) async {
    final current = state;
    if (current is! SettingsReady) return;
    final result = await _repository.saveThemeMode(event.themeMode);
    // close() drains the in-flight sequential handler before cancelling
    // its emitter, so without this guard a save finishing during close()
    // would still emit. `isClosed` flips synchronously when close() starts.
    if (isClosed) return;
    result.fold(
      ok: (_) {},
      err: (failure) => emit(current.copyWith(lastFailure: failure)),
    );
  }
}
