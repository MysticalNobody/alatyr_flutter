import 'dart:async';

import 'package:data_local/data_local.dart';
import 'package:data_local/testing.dart';
import 'package:feature_settings/feature_settings.dart';
import 'package:feature_settings_api/feature_settings_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:patrol_finders/patrol_finders.dart';

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
      await db.keyValueDao.write('settings.theme_mode', 'dark');
      expect(await module.api.watchThemeMode().first, ThemeMode.dark);
    },
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
      final stored = await db.keyValueDao.read('settings.theme_mode');
      await _unmount($);

      expect(stored, 'dark');
    },
  );
}
