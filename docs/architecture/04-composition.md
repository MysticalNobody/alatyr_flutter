# 04 — Composition and bootstrap

There is no service locator. Every implementation is named exactly once, by
hand, in one file, and handed down through constructors.

## The composition root

`app/lib/bootstrap/app_dependencies.dart` is the **only** place in the
repository that names a concrete implementation of a base-layer port —
`ConsoleLogger`, `AppDatabase.open(...)`, `FlutterSecureStore.platform()`.
Everything downstream of it, including every feature module, receives its
dependencies through a constructor and never constructs its own:

```dart
final class AppDependencies {
  AppDependencies({
    required this.config,
    required this.logger,
    required this.database,
    required this.secureStore,
  }) : settings = createSettingsModule(
         keyValueDao: database.keyValueDao,
         logger: logger,
       );

  factory AppDependencies.production() => AppDependencies(
    config: AppConfig.fromEnvironment(),
    logger: const ConsoleLogger(),
    database: AppDatabase.open(name: 'alatyr_starter'),
    secureStore: const FlutterSecureStore.platform(),
  );
  // ...
}
```

Tests construct `AppDependencies` directly with in-memory/fake
implementations (an in-memory drift database, `InMemorySecureStore`,
`NoopLogger`) — the same class, a different call site, no container to
configure.

## The `bootstrap` seam

```dart
Future<void> bootstrap({
  AppDependencies Function() createDependencies = AppDependencies.production,
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(App(dependencies: createDependencies()));
}
```

`main()` calls `bootstrap()` with no arguments (production wiring); the app
bootstrap smoke test calls it with a `createDependencies` that returns an
in-memory `AppDependencies` — same code path, same `App` widget, different
dependency graph.

## Router assembly

`AppDependencies.buildRouter()` assembles one `GoRouter` from every
feature module's contributed routes:

```dart
GoRouter buildRouter() => GoRouter(
  initialLocation: SettingsRoutes.path,
  routes: [...settings.routes],
);
```

Today `settings.routes` is the only contributor and `SettingsRoutes.path`
is the initial location; a second feature module adds its routes to the
same spread, unconditionally.

## Driving `MaterialApp.themeMode`

`App` subscribes to `dependencies.settings.api.watchThemeMode()` exactly
once, in a `late final` field — not inside `build`, where a fresh
subscription on every rebuild would resubscribe and replay the current
value each time — and feeds the emitted `ThemeMode` straight into
`MaterialApp.router(themeMode: ...)`. This is the same stream
[03](03-feature-contract.md) describes: the app shell and the settings
bloc read one source of truth, never two.

## Why no get_it or injectable

Manual constructor injection keeps every dependency edge visible as a type
signature the analyzer already checks — no reflection, no runtime lookup
that only fails when the missing registration is reached. See
[ADR-0002](../adr/0002-manual-di.md) for the full reasoning and the
alternatives considered.
