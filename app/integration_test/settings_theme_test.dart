// Critical flow (docs/reference/critical_flows.md):
//   launch -> settings -> choose dark -> restart -> dark persisted.
//
// Patrol runs every Dart test in its own OS process: on Android the test
// orchestrator starts a new instrumentation (= app) process per test, on iOS
// the runner calls `XCUIApplication.launch` before each test, which
// terminates any running instance. That process boundary between the two
// tests below is a real process death - the file-backed database is reopened
// from disk - which no single-test API can produce (patrol has no "relaunch
// app" call; `pressHome` + `openApp` only backgrounds and foregrounds the
// same process). The registered flow restarts in-process instead (the
// convention in docs/reference/critical_flows.md); the second test is the bonus
// that spends this process boundary.
//
// Consequences, both deliberate:
// - The second test depends on the first having run, and the two platforms
//   order tests differently: Android's parameterized runner keeps the order
//   of `listDartTests()` (declaration order), while XCTest runs the
//   selectors patrol generates from that same list in alphabetical order.
//   The two names below are therefore written so that declaration order and
//   alphabetical order agree on the registered flow going first ("choose"
//   before "the"); the second test fails loudly - not silently - if that
//   ever stops holding.
// - `clearPackageData` must NOT be set in the Android instrumentation
//   arguments: the orchestrator would `pm clear` the app between the tests
//   and wipe the very state the second test asserts on.
import 'package:alatyr_starter/app.dart';
import 'package:alatyr_starter/bootstrap/app_dependencies.dart';
import 'package:feature_settings_api/feature_settings_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

ThemeMode? _themeMode(PatrolIntegrationTester $) =>
    $.tester.widget<MaterialApp>($(MaterialApp)).themeMode;

bool _isSelected(PatrolIntegrationTester $, ThemeMode mode) => $.tester
    .widget<ListTile>($(SettingsKeys.themeModeTile(mode)).$(ListTile))
    .selected;

/// The production composition root, pumped the way patrol prescribes: no
/// `ensureInitialized`, no `runApp` (patrol owns the binding).
Future<AppDependencies> _launch(PatrolIntegrationTester $) async {
  final deps = AppDependencies.production();
  await $.pumpWidgetAndSettle(App(dependencies: deps));
  expect($(SettingsKeys.screen), findsOneWidget);
  return deps;
}

void main() {
  // THE registered critical flow (docs/reference/critical_flows.md). Its
  // "restart" follows docs/reference/critical_flows.md: the app entrypoint
  // is re-invoked within the test - a fresh widget tree and DI graph - and
  // with production dependencies that means the on-disk database is closed
  // and reopened from the file. Self-contained: it passes alone.
  patrolTest('settings: choose dark, restart the app, dark is restored', (
    $,
  ) async {
    var first = await _launch($);

    // Light first, and it must survive a restart. Without this leg the flow
    // can false-pass on a device an interrupted run left holding `dark`: a
    // save path regressed to a no-op would still satisfy every assertion
    // below, using the stale value. Proving persistence for a value that is
    // NOT the one under test is what makes the dark leg mean something.
    await $(SettingsKeys.themeModeTile(ThemeMode.light)).tap();
    expect(_isSelected($, ThemeMode.light), isTrue);
    await $.pumpWidget(const SizedBox.shrink());
    await first.dispose();
    first = await _launch($);
    expect(_isSelected($, ThemeMode.light), isTrue);
    expect(_themeMode($), ThemeMode.light);

    await $(SettingsKeys.themeModeTile(ThemeMode.dark)).tap();
    expect(_themeMode($), ThemeMode.dark);
    expect(_isSelected($, ThemeMode.dark), isTrue);

    // Background and foreground (same process) first...
    await $.platform.mobile.pressHome();
    await $.platform.mobile.openApp();
    await $.pumpAndSettle();
    expect(_isSelected($, ThemeMode.dark), isTrue);

    // ...then the restart: tear the whole graph down (closes the database)
    // and build a new one over the same file.
    await $.pumpWidget(const SizedBox.shrink());
    await first.dispose();
    final second = await _launch($);
    expect(_isSelected($, ThemeMode.dark), isTrue);
    expect(_themeMode($), ThemeMode.dark);
    await second.dispose();
  });

  // Bonus, NOT the registered flow: real OS process death. Patrol runs every
  // Dart test in its own process (see the header), so this test starts in a
  // fresh process over the database the previous test left behind. It is
  // order-dependent by construction and fails loudly when run alone.
  patrolTest(
    'settings: the persisted dark theme survives process death (fresh process)',
    ($) async {
      final deps = await _launch($);
      expect(_isSelected($, ThemeMode.dark), isTrue);
      expect(_themeMode($), ThemeMode.dark);

      // Leave the device as we found it so the next run starts from system.
      await $(SettingsKeys.themeModeTile(ThemeMode.system)).tap();
      expect(_isSelected($, ThemeMode.system), isTrue);
      await deps.dispose();
    },
  );
}
