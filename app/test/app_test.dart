import 'dart:async';

import 'package:alatyr_starter/app.dart';
import 'package:alatyr_starter/bootstrap/app_dependencies.dart';
import 'package:alatyr_starter/bootstrap/bootstrap.dart';
import 'package:app_config/app_config.dart';
import 'package:app_core/app_core.dart';
import 'package:data_local/testing.dart';
import 'package:data_secure/data_secure.dart';
import 'package:feature_settings_api/feature_settings_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol_finders/patrol_finders.dart';

AppDependencies _testDependencies() => AppDependencies(
  config: AppConfig(
    env: AppEnv.dev,
    apiBaseUrl: Uri.parse('https://example.invalid'),
  ),
  logger: const NoopLogger(),
  database: inMemoryAppDatabase(),
  secureStore: InMemorySecureStore(),
);

// `$.tester.widget<T>` is the only way to read a widget property; the
// lookup itself stays a patrol finder.
ThemeMode? _themeMode(PatrolTester $) =>
    $.tester.widget<MaterialApp>($(MaterialApp)).themeMode;

bool _isSelected(PatrolTester $, ThemeMode mode) => $.tester
    .widget<ListTile>($(SettingsKeys.themeModeTile(mode)).$(ListTile))
    .selected;

/// See feature_settings/test/settings_module_test.dart: drift's zero-timer
/// on stream cancel must fire before the body returns.
Future<void> _unmount(PatrolTester $) async {
  await $.pumpWidget(const SizedBox.shrink());
  await $.pump(Duration.zero);
}

void main() {
  late AppDependencies deps;

  setUp(() => deps = _testDependencies());
  // Fire-and-forget (see settings_module_test.dart).
  tearDown(() => unawaited(deps.dispose()));

  patrolWidgetTest(
    'bootstrap() boots into the settings screen with the persisted (system) mode selected',
    ($) async {
      // The real entry path (binding + runApp), with the test seam supplying
      // in-memory dependencies; the test binding is the WidgetsBinding
      // bootstrap() initializes, so runApp lands in this tester's tree.
      await bootstrap(createDependencies: () => deps);
      await $.pumpAndSettle();
      expect($(SettingsKeys.screen), findsOneWidget);
      // Selected tile, not MaterialApp.themeMode: the latter is satisfied by
      // StreamBuilder.initialData even if the port never emitted.
      expect(_isSelected($, ThemeMode.system), isTrue);
      await _unmount($);
    },
  );

  patrolWidgetTest(
    'choosing dark drives MaterialApp.themeMode through the SettingsApi port',
    ($) async {
      await $.pumpWidgetAndSettle(App(dependencies: deps));
      await $(#settings.theme_mode.dark).tap();
      final mode = _themeMode($);
      await _unmount($);
      expect(mode, ThemeMode.dark);
    },
  );

  patrolWidgetTest(
    'a fresh app over the same database restores the persisted theme',
    ($) async {
      await $.pumpWidgetAndSettle(App(dependencies: deps));
      await $(#settings.theme_mode.dark).tap();

      // "Restart" = a NEW widget tree and DI graph over the same storage (the
      // convention spec section 8 records for critical flows). Unmount first:
      // pumping a second `App` straight over the first would update the
      // existing element and keep `_AppState`'s router and stream bound to
      // the old dependencies - the test would pass without proving anything.
      await _unmount($);
      final restarted = AppDependencies(
        config: deps.config,
        logger: deps.logger,
        database: deps.database,
        secureStore: deps.secureStore,
      );
      await $.pumpWidgetAndSettle(App(dependencies: restarted));
      final mode = _themeMode($);
      await _unmount($);
      expect(mode, ThemeMode.dark);
    },
  );
}
