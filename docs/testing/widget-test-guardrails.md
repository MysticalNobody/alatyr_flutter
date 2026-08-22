# Widget-test guardrails

`flutter test` runs widget tests inside a `FakeAsync` zone (`testWidgets`'s
binding). A hang here does not time out under `flutter test --timeout` —
teardown hangs are the one thing that flag does not catch — so these
eleven rules exist to keep the gate's wall-clock timeout (`tool/common.sh`,
`CHECKS_TEST_TIMEOUT`) from ever being the only thing that notices. Every
rule below is demonstrated by a real exemplar in this repo; quote the
comment, not just the rule, when you copy the pattern.

## 1. Never `await` a bloc/controller/drift close created inside the body

**Symptom:** the test hangs after its assertions pass; nothing prints, the
process just sits until the wall-clock timeout fires.
**Cause:** a `Bloc.close()`, `StreamController.close()`, or drift `close()`
whose completion depends on objects built inside the `testWidgets` body
resolves only once the `FakeAsync` zone the body ran in processes more
timers/microtasks — which stops happening the moment the body returns.
**Recipe:** let the widget tree own the resource (`BlocProvider(create:)`
closes its bloc at disposal) and never await the close yourself; when you
do own the resource directly (a drift `AppDatabase` built in `setUp`),
close it fire-and-forget: `tearDown(() => unawaited(db.close()));`
(`packages/feature_settings/test/settings_module_test.dart`: *"Fire-and-
forget: after a testWidgets body, an awaited db.close() hangs (its
completion lives in the finished FakeAsync zone)."*) The same shape covers
app-level dependencies: `app/test/app_test.dart`:
`tearDown(() => unawaited(deps.dispose()));`. And from
`packages/feature_settings/test/settings_screen_test.dart`: *"Nothing here
is closed through an awaited tearDown: a `Bloc.close()` /
`StreamController.close()` whose completion depends on objects created
inside the FakeAsync zone of `testWidgets` never completes once the body
has returned, and the test hangs (verified)."*

## 2. Never `await` a drift-backed stream inside the body

**Symptom:** the first assertion after the `await` never returns; every
later `pump` in the same test also stalls.
**Cause:** awaiting `.first` (or `await for`) on a stream backed by a live
drift connection resumes outside the `FakeAsync` zone that drives pumps,
so the zone can never schedule the rest of the test.
**Recipe:** assert through the synchronous `read()` path instead of
awaiting the stream inside a widget test body — reserve `.first` for plain
`test()` functions (rule 9). From
`packages/feature_settings/test/settings_module_test.dart`: *"Assert
through `read()`, never by awaiting the drift-backed STREAM (`.first`)
inside the body: that await resumes outside the FakeAsync zone and strands
every later pump (verified hang). The api stream is covered by the plain
test above."*

## 3. Drift's zero-duration cancel timer trips the pending-timer assertion

**Symptom:** `flutter_test` fails the test with "A Timer is still
pending" even though every assertion passed.
**Cause:** drift schedules a zero-duration timer when a watch
subscription is cancelled (which happens when `BlocProvider` closes its
bloc at tree disposal), and `flutter_test` asserts no timer is pending
once the body returns.
**Recipe:** every drift-backed widget test ends with an explicit unmount
that gives that timer one pump: `await $.pumpWidget(const
SizedBox.shrink()); await $.pump(Duration.zero);`. From
`packages/feature_settings/test/settings_module_test.dart`: *"Drift
schedules a zero-duration timer when the bloc's watch subscription is
cancelled (BlocProvider closes the bloc at tree disposal), and flutter_test
asserts that no timer is pending after the body. So every drift-backed
widget test unmounts explicitly and gives that timer one pump before
returning."*

## 4. A progress indicator animates forever

**Symptom:** `pumpWidgetAndSettle` times out on a screen that is clearly
idle to the eye.
**Cause:** `pumpAndSettle`-family calls keep pumping frames until nothing
is scheduled to rebuild; an indeterminate `CircularProgressIndicator`
schedules a new frame forever, so "settled" never arrives.
**Recipe:** use plain `pump()`/`pump(duration)` calls while a progress
indicator is on screen, never the settle variants. From
`packages/feature_settings/test/settings_screen_test.dart`: *"Plain pumps:
a progress indicator animates forever, so pumpWidgetAndSettle would time
out here."*

## 5. `BlocProvider(create:)` is lazy

**Symptom:** a bloc built with side effects in its `create:` callback
(e.g. `SettingsBloc(repository)..add(const SettingsStarted())`) appears
never to have run — no state change, no repository call — even though the
provider was pumped.
**Cause:** `BlocProvider.create` is invoked on first read, not at pump
time; if nothing under the provider actually reads the bloc (no
`BlocBuilder`/`context.watch`/`context.read`), `create` never runs.
**Recipe:** always pump a real consumer under the provider (the exemplars
pump the actual screen, e.g. `packages/feature_settings/lib/src/settings_module.dart`'s
`BlocProvider(create: (_) => SettingsBloc(repository)..add(const
SettingsStarted()), child: const SettingsScreen())` — `SettingsScreen`
reads the bloc on its first build, so lazy construction is not something a
test needs to work around, only understand before debugging "nothing
happened").

## 6. Dispose a per-test `GoRouter`

**Symptom:** an "A GoRouter was used after being disposed" failure in a
later test, or a `flutter_test` leaked-object failure.
**Cause:** a `GoRouter` constructed directly inside a test (rather than
received from a module) is not owned by any widget's disposal chain unless
you register one.
**Recipe:** `addTearDown(router.dispose)` right after constructing it, as
in `packages/feature_settings/test/settings_module_test.dart`:
```dart
final router = GoRouter(initialLocation: SettingsRoutes.path, routes: module.routes);
addTearDown(router.dispose);
```

## 7. `$(#a.b.c)` matches `ValueKey<String>('a.b.c')` only

**Symptom:** a finder built from a symbol literal (`$(#settings.theme_mode.dark)`)
comes back empty even though a widget with that string key is on screen.
**Cause:** patrol finders' `#` syntax resolves to a `ValueKey<String>`
whose value is the dotted symbol name — it matches nothing else (not a
plain `Key`, not a different generic parameter), and every segment between
dots must itself be a valid Dart identifier (no hyphens, no leading
digits).
**Recipe:** key every interactive widget with
`ValueKey<String>('<feature>.<screen>.<element>')` from the feature's key
namespace and address it either way — `$(#settings.theme_mode.dark)` or
`$(SettingsKeys.themeModeTile(ThemeMode.dark))` — as documented in
`packages/feature_settings_api/lib/src/settings_keys.dart`.

## 8. Plugin adapters are `async` so a sync throw becomes a rejected future

**Symptom:** a mocked plugin call configured with `thenThrow` inside a
synchronous stub is expected to throw synchronously, but the calling code
never sees a synchronous exception to catch.
**Cause:** every adapter method here is declared `async`; a plugin's
synchronous throw (or a mock's `thenThrow`) is caught by the `async`
function's implicit try and delivered as a rejected `Future`, never a
synchronous exception.
**Recipe:** always `await` adapter calls under a `try`/`on Exception`
(never assume a synchronous throw is reachable) — see
`packages/data_secure/lib/src/flutter_secure_store.dart`: *"Every operation
is `async` and guarded by `on Exception`: the plugin throws
`PlatformException` (codes differ per platform, so the TYPE is what we
map) … a synchronous throw from the plugin thus surfaces as a rejected
future that the guard turns into an `Err`."*

## 9. Plain `test()` has no `FakeAsync` zone — awaited closes are fine there

**Symptom:** none — this is the safe case, called out so rule 1 is not
over-applied.
**Cause:** a bare `test()` (not `testWidgets`/`patrolWidgetTest`) runs
without the widget-test binding's `FakeAsync` zone, so a `close()`'s
completion is not tied to a zone that stops being pumped.
**Recipe:** in a plain `test()`, `await` the close normally. From
`packages/feature_settings/test/drift_settings_repository_test.dart`:
`tearDown(() => db.close()); // plain test(): awaiting close is fine here`.

## 10. Single-subscription buffers pre-listen events; broadcast drops them

**Symptom:** events added to a fake stream before the code under test
subscribes are silently missing from the first assertion.
**Cause:** a broadcast `StreamController` delivers only to listeners
already subscribed at the moment `.add` is called; a single-subscription
controller buffers everything added before the first `listen`.
**Recipe:** use a single-subscription `StreamController` when the test
needs to queue values before the bloc/widget subscribes, and a broadcast
one when late listeners replaying history is the point. From
`packages/feature_settings/test/settings_bloc_test.dart`: *"Single-
subscription on purpose: events added before the bloc subscribes are
buffered (a broadcast controller would drop them)."*

## 11. Element reuse: pump a `SizedBox.shrink()` between two trees of the same widget type

**Symptom:** a "restart" test that pumps a fresh widget tree over an old
one passes even when the new tree's dependencies are wrong — it is
silently asserting against the old state.
**Cause:** Flutter's element tree reuses the existing `State` when the new
widget at the same position has the same runtime type (`App` over `App`),
so router and stream subscriptions from the first tree stay bound instead
of being rebuilt from the new dependencies.
**Recipe:** pump an unrelated widget (`SizedBox.shrink()`) to force a full
unmount before pumping the second tree of the same type. From
`app/test/app_test.dart`: *"'Restart' = a NEW widget tree and DI graph
over the same storage … Unmount first: pumping a second `App` straight
over the first would update the existing element and keep `_AppState`'s
router and stream bound to the old dependencies - the test would pass
without proving anything."*

## Next

`docs/testing/strategy.md` for the pyramid these rules serve; the digest
form of this file lives in `.claude/rules/testing.md` (loaded automatically
for paths under `**/test/**`, `**/integration_test/**`).
