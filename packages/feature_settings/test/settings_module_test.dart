import 'dart:async';

import 'package:app_core/app_core.dart';
import 'package:data_local/data_local.dart';
import 'package:data_local/testing.dart';
import 'package:feature_settings/feature_settings.dart';
import 'package:feature_settings/src/drift_settings_repository.dart';
import 'package:feature_settings_api/feature_settings_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:patrol_finders/patrol_finders.dart';

/// Records what the repository logs, so `createSettingsModule(logger:)` is
/// asserted to actually wire the seam end-to-end, not merely accept it.
final class _RecordingLogger extends AppLogger {
  final List<({LogLevel level, String message})> records = [];

  @override
  void log(
    LogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) => records.add((level: level, message: message));
}

/// Drift schedules a zero-duration timer when the bloc's watch subscription
/// is cancelled (BlocProvider closes the bloc at tree disposal), and
/// flutter_test asserts that no timer is pending after the body. So every
/// drift-backed widget test unmounts explicitly and gives that timer one
/// pump before returning.
Future<void> _unmount(PatrolTester $) async {
  await $.pumpWidget(const SizedBox.shrink());
  await $.pump(Duration.zero);
}

void main() {
  late AppDatabase db;
  late SettingsModule module;

  setUp(() {
    db = inMemoryAppDatabase();
    module = createSettingsModule(keyValueDao: db.keyValueDao);
  });
  // Fire-and-forget: after a testWidgets body, an awaited db.close() hangs
  // (its completion lives in the finished FakeAsync zone).
  tearDown(() => unawaited(db.close()));

  test('contributes exactly one route at the documented path and name', () {
    expect(module.routes, hasLength(1));
    final route = module.routes.single as GoRoute;
    expect(route.path, SettingsRoutes.path);
    expect(route.name, SettingsRoutes.name);
  });

  test(
    'api reports system until something is stored, then the stored mode',
    () async {
      expect(await module.api.watchThemeMode().first, ThemeMode.system);
      await db.keyValueDao.write(DriftSettingsRepository.themeModeKey, 'dark');
      expect(await module.api.watchThemeMode().first, ThemeMode.dark);
    },
  );

  test('createSettingsModule(logger:) wires the logger through to the '
      'repository, warning once on a corrupted stored value', () async {
    final recorder = _RecordingLogger();
    final logged = createSettingsModule(
      keyValueDao: db.keyValueDao,
      logger: recorder,
    );
    await db.keyValueDao.write(DriftSettingsRepository.themeModeKey, 'purple');
    expect(await logged.api.watchThemeMode().first, ThemeMode.system);
    expect(recorder.records, hasLength(1));
    expect(recorder.records.single.level, LogLevel.warn);
  });

  test(
    'OS-level process death (fresh AppDatabase reopened from disk) '
    'restores the persisted theme',
    () {},
    skip:
        'deliberate: OS-level death is a patrol e2e concern over a '
        'file-backed AppDatabase closed and reopened from disk - proved by '
        'the fresh-process bonus test in '
        'app/integration_test/settings_theme_test.dart, alongside the '
        'registered flow in docs/reference/critical_flows.md. The '
        'in-process restart proof (a second widget tree + DI graph over '
        'the same live connection) is app/test/app_test.dart: "a fresh '
        'app over the same database restores the persisted theme".',
  );

  patrolWidgetTest(
    'the route renders the settings screen wired to real persistence',
    ($) async {
      final router = GoRouter(
        initialLocation: SettingsRoutes.path,
        routes: module.routes,
      );
      addTearDown(router.dispose);
      await $.pumpWidgetAndSettle(MaterialApp.router(routerConfig: router));

      expect($(SettingsKeys.screen), findsOneWidget);
      await $(#settings.theme_mode.dark).tap();
      // Assert through read(), never by awaiting the drift-backed STREAM
      // (`.first`) inside the body: that await resumes outside the FakeAsync
      // zone and strands every later pump (verified hang). The api stream is
      // covered by the plain test above.
      final stored = await db.keyValueDao.read(
        DriftSettingsRepository.themeModeKey,
      );
      await _unmount($);

      expect(stored, 'dark');
    },
  );
}
