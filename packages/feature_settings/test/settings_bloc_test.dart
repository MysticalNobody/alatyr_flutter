import 'dart:async';

import 'package:app_core/app_core.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:feature_settings/src/bloc/settings_bloc.dart';
import 'package:feature_settings/src/bloc/settings_event.dart';
import 'package:feature_settings/src/bloc/settings_state.dart';
import 'package:feature_settings/src/settings_repository.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepository extends Mock implements SettingsRepository {}

void main() {
  late _MockRepository repository;
  late StreamController<ThemeMode> modes;
  late List<ThemeMode> completedSaves;
  late Completer<Result<void>> pendingSave;

  setUpAll(() => registerFallbackValue(ThemeMode.system));

  setUp(() {
    repository = _MockRepository();
    // Single-subscription on purpose: events added before the bloc
    // subscribes are buffered (a broadcast controller would drop them).
    modes = StreamController<ThemeMode>();
    when(repository.watchThemeMode).thenAnswer((_) => modes.stream);
  });
  // NOT awaited: the done future of a never-listened single-subscription
  // controller never completes, so `tearDown(() => modes.close())` would
  // time out every test that does not subscribe.
  tearDown(() => unawaited(modes.close()));

  test('initial state is loading', () async {
    final bloc = SettingsBloc(repository);
    addTearDown(bloc.close);
    expect(bloc.state, const SettingsState.loading());
  });

  blocTest<SettingsBloc, SettingsState>(
    'SettingsStarted mirrors every repository emission into ready',
    build: () => SettingsBloc(repository),
    act: (bloc) {
      bloc.add(const SettingsStarted());
      modes
        ..add(ThemeMode.system)
        ..add(ThemeMode.dark);
    },
    expect: () => const [
      SettingsState.ready(themeMode: ThemeMode.system),
      SettingsState.ready(themeMode: ThemeMode.dark),
    ],
  );

  blocTest<SettingsBloc, SettingsState>(
    'SettingsThemeModeChanged saves; the new mode arrives through the stream, not the event',
    setUp: () {
      when(
        () => repository.saveThemeMode(any()),
      ).thenAnswer((_) async => const Ok(null));
    },
    build: () => SettingsBloc(repository),
    seed: () => const SettingsState.ready(themeMode: ThemeMode.system),
    act: (bloc) => bloc.add(const SettingsThemeModeChanged(ThemeMode.dark)),
    expect: () => const <SettingsState>[],
    verify: (_) =>
        verify(() => repository.saveThemeMode(ThemeMode.dark)).called(1),
  );

  blocTest<SettingsBloc, SettingsState>(
    'a failed save keeps the current mode and exposes the failure',
    setUp: () {
      when(() => repository.saveThemeMode(any())).thenAnswer(
        (_) async => const Err(
          AppFailure(code: 'settings.save-failed', message: 'nope'),
        ),
      );
    },
    build: () => SettingsBloc(repository),
    seed: () => const SettingsState.ready(themeMode: ThemeMode.light),
    act: (bloc) => bloc.add(const SettingsThemeModeChanged(ThemeMode.dark)),
    expect: () => const [
      SettingsState.ready(
        themeMode: ThemeMode.light,
        lastFailure: AppFailure(code: 'settings.save-failed', message: 'nope'),
      ),
    ],
  );

  blocTest<SettingsBloc, SettingsState>(
    'the next stream emission clears a previous failure',
    setUp: () {
      when(() => repository.saveThemeMode(any())).thenAnswer(
        (_) async => const Err(
          AppFailure(code: 'settings.save-failed', message: 'nope'),
        ),
      );
    },
    build: () => SettingsBloc(repository),
    act: (bloc) async {
      bloc.add(const SettingsStarted());
      modes.add(ThemeMode.light);
      await Future<void>.delayed(Duration.zero);
      bloc.add(const SettingsThemeModeChanged(ThemeMode.dark));
      await Future<void>.delayed(Duration.zero);
      modes.add(ThemeMode.light);
    },
    expect: () => const [
      SettingsState.ready(themeMode: ThemeMode.light),
      SettingsState.ready(
        themeMode: ThemeMode.light,
        lastFailure: AppFailure(code: 'settings.save-failed', message: 'nope'),
      ),
      SettingsState.ready(themeMode: ThemeMode.light),
    ],
  );

  blocTest<SettingsBloc, SettingsState>(
    'SettingsThemeModeChanged while still loading is ignored',
    build: () => SettingsBloc(repository),
    act: (bloc) => bloc.add(const SettingsThemeModeChanged(ThemeMode.dark)),
    expect: () => const <SettingsState>[],
    verify: (_) => verifyNever(() => repository.saveThemeMode(any())),
  );

  blocTest<SettingsBloc, SettingsState>(
    'two quick changes (double tap) both reach the repository; the state keeps mirroring the stream',
    setUp: () {
      when(
        () => repository.saveThemeMode(any()),
      ).thenAnswer((_) async => const Ok(null));
    },
    build: () => SettingsBloc(repository),
    seed: () => const SettingsState.ready(themeMode: ThemeMode.system),
    act: (bloc) => bloc
      ..add(const SettingsThemeModeChanged(ThemeMode.dark))
      ..add(const SettingsThemeModeChanged(ThemeMode.dark)),
    expect: () => const <SettingsState>[],
    verify: (_) =>
        verify(() => repository.saveThemeMode(ThemeMode.dark)).called(2),
  );

  blocTest<SettingsBloc, SettingsState>(
    'a slower earlier save completes before a later one starts, so the latest choice wins',
    setUp: () {
      completedSaves = [];
      when(() => repository.saveThemeMode(ThemeMode.dark)).thenAnswer((
        _,
      ) async {
        await Future<void>.delayed(const Duration(milliseconds: 30));
        completedSaves.add(ThemeMode.dark);
        return const Ok(null);
      });
      when(() => repository.saveThemeMode(ThemeMode.light)).thenAnswer((
        _,
      ) async {
        completedSaves.add(ThemeMode.light);
        return const Ok(null);
      });
    },
    build: () => SettingsBloc(repository),
    seed: () => const SettingsState.ready(themeMode: ThemeMode.system),
    act: (bloc) => bloc
      ..add(const SettingsThemeModeChanged(ThemeMode.dark))
      ..add(const SettingsThemeModeChanged(ThemeMode.light)),
    wait: const Duration(milliseconds: 80),
    expect: () => const <SettingsState>[],
    // Without serialization the fast `light` save would complete first and
    // the slow `dark` one would overwrite it.
    verify: (_) => expect(completedSaves, [ThemeMode.dark, ThemeMode.light]),
  );

  blocTest<SettingsBloc, SettingsState>(
    'a mode that arrives while a save is pending is kept when that save fails',
    setUp: () {
      pendingSave = Completer<Result<void>>();
      when(
        () => repository.saveThemeMode(ThemeMode.light),
      ).thenAnswer((_) => pendingSave.future);
    },
    build: () => SettingsBloc(repository),
    // Ordering is driven by the completer, never by wall-clock delays: the
    // `dark` emission lands while the `light` save is still in flight.
    act: (bloc) async {
      bloc.add(const SettingsStarted());
      modes.add(ThemeMode.system);
      await Future<void>.delayed(Duration.zero);
      bloc.add(const SettingsThemeModeChanged(ThemeMode.light));
      await Future<void>.delayed(Duration.zero);
      modes.add(ThemeMode.dark);
      await Future<void>.delayed(Duration.zero);
      pendingSave.complete(
        const Err(AppFailure(code: 'settings.save-failed', message: 'nope')),
      );
      await Future<void>.delayed(Duration.zero);
    },
    expect: () => const [
      SettingsState.ready(themeMode: ThemeMode.system),
      SettingsState.ready(themeMode: ThemeMode.dark),
      SettingsState.ready(
        themeMode: ThemeMode.dark,
        lastFailure: AppFailure(code: 'settings.save-failed', message: 'nope'),
      ),
    ],
  );

  blocTest<SettingsBloc, SettingsState>(
    'a save that completes after close() neither throws nor emits',
    setUp: () {
      when(() => repository.saveThemeMode(any())).thenAnswer(
        (_) => Future<Result<void>>.delayed(
          const Duration(milliseconds: 20),
          () => const Err(
            AppFailure(code: 'settings.save-failed', message: 'late'),
          ),
        ),
      );
    },
    build: () => SettingsBloc(repository),
    seed: () => const SettingsState.ready(themeMode: ThemeMode.system),
    act: (bloc) async {
      bloc.add(const SettingsThemeModeChanged(ThemeMode.dark));
      await Future<void>.delayed(Duration.zero);
      await bloc.close();
      await Future<void>.delayed(const Duration(milliseconds: 40));
    },
    expect: () => const <SettingsState>[],
    errors: () => isEmpty,
  );

  blocTest<SettingsBloc, SettingsState>(
    'a repository stream error surfaces as settings.load-failed and keeps the last mode',
    build: () => SettingsBloc(repository),
    act: (bloc) async {
      bloc.add(const SettingsStarted());
      modes.add(ThemeMode.dark);
      await Future<void>.delayed(Duration.zero);
      modes.addError(StateError('database gone'));
      await Future<void>.delayed(Duration.zero);
      // The third state proves the subscription outlived the error.
      modes.add(ThemeMode.light);
    },
    expect: () => [
      const SettingsState.ready(themeMode: ThemeMode.dark),
      isA<SettingsReady>()
          .having((s) => s.themeMode, 'themeMode', ThemeMode.dark)
          .having(
            (s) => s.lastFailure?.code,
            'lastFailure.code',
            'settings.load-failed',
          ),
      const SettingsState.ready(themeMode: ThemeMode.light),
    ],
    errors: () => isEmpty,
  );
}
