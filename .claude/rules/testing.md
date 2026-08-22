---
paths:
  - "**/test/**"
  - "**/integration_test/**"
---

# Testing conventions

- Widget and integration tests use patrol finders: `patrolWidgetTest`,
  `$(#feature.screen.element)` / `$(SettingsKeys.x)`, `.tap()`, `.exists`.
  `$.tester.widget<T>(finder)` is the only raw-tester use — reading a widget
  property. No `find.byKey`/`find.byType` in new tests.
- Test names are the test cases (`'given stored theme is corrupted,
  settings falls back to system'`); the case catalog is generated from
  code, never hand-maintained.
- Deliberately uncovered scenarios become stubs:
  `test('…', () {}, skip: 'deliberate: <reason>')`.
- FakeAsync rules (the exemplars in `packages/feature_settings/test/` and
  `app/test/` embody them): the widget tree owns blocs
  (`BlocProvider(create:)`); never `await`, in the body or a
  `tearDown`/`addTearDown`, a `Bloc.close()`, `StreamController.close()`,
  or drift `close()` created inside a `testWidgets` body — use
  `unawaited(...)`; never `await` a drift-backed stream (`.first`,
  `await for`) inside the body — assert through `read()`; drift schedules a
  zero-duration timer when a watch subscription is cancelled, so
  drift-backed widget tests end with an explicit unmount
  (`pumpWidget(SizedBox.shrink())` + `pump(Duration.zero)`).
- A progress indicator animates forever: use plain pumps, not
  `pumpWidgetAndSettle`, while one is on screen.
- Per-test `GoRouter` → `dispose()` it; `BlocProvider(create:)` is lazy;
  adapter methods over plugins are `async` so sync throws become rejected
  futures; `$(#a.b.c)` matches `ValueKey<String>('a.b.c')` only.
- Run tests with `fvm flutter test --no-pub` (Flutter members) or `fvm dart
  test` (pure packages, root); the full gate is `tool/checks.sh`.
