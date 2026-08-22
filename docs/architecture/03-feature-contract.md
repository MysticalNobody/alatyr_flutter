# 03 — The feature contract

Every feature splits into two packages with one rule: `*_api` is contracts,
`*_impl` is everything else, and cross-feature code may only ever depend on
the `*_api` half.

## `feature_x_api` — contracts only

`feature_settings_api` exports ports, models, the route spec, the key
namespace, and failure-code constants — no implementation. It is a Flutter
package on purpose: navigation and UI contracts (routes, `ThemeMode`) would
otherwise force a kind migration the moment a feature needs them.

```dart
abstract interface class SettingsApi {
  Stream<ThemeMode> watchThemeMode();
}
```

## `feature_x` — exactly one public factory

`feature_settings` exports a single factory. Everything else — the bloc,
the screen, the repository, the drift-backed implementation — lives under
`src/` and is never exported from the package's top-level library file.

```dart
SettingsModule createSettingsModule({
  required KeyValueDao keyValueDao,
  AppLogger logger = const NoopLogger(),
})
```

returning:

```dart
final class SettingsModule {
  const SettingsModule({required this.routes, required this.api});
  final List<RouteBase> routes;
  final SettingsApi api;
}
```

Only `app/` calls `createSettingsModule` (from its composition root, see
[04](04-composition.md)); every other consumer sees `SettingsApi` alone.

## Cross-feature consumption goes through `*_api` only

A second feature that needs the current theme mode depends on
`feature_settings_api`, never on `feature_settings`. This is what the
`feature_api` / `feature_impl` package kinds encode in the graph
([02](02-package-graph.md)) and what `verify_imports`/`alatyr_lints` enforce
on every import.

## The key namespace rule

Every interactive widget carries a `ValueKey` from its feature's namespace,
`<feature>.<screen>.<element>`, so patrol finders and the optional
marionette driver can address it. `SettingsKeys` is the worked example:

```dart
abstract final class SettingsKeys {
  static const Key screen = ValueKey<String>('settings.screen');
  static const Key failureBanner = ValueKey<String>('settings.failure');
  static Key themeModeTile(ThemeMode mode) =>
      ValueKey<String>('settings.theme_mode.${mode.name}');
}
```

## Single source of truth: persistence, not the event

`SettingsBloc` mirrors `SettingsRepository.watchThemeMode()`: on
`SettingsStarted` it forwards that stream into its state, one-for-one. A
successful save (`SettingsThemeModeChanged`) emits **nothing** itself — the
new state reaches the UI only because the same stream reports the change
the save just made. The app's own read of the theme mode
(`App` in [04](04-composition.md)) subscribes to that identical stream
through `SettingsApi.watchThemeMode()`, so the bloc and the app shell never
hold two independent opinions about the current mode.
