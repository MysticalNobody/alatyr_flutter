# Feature package skeletons

The file trees the graph-first ritual (`docs/workflow/feature-workflow.md`)
produces for a new feature named `x` (replace `x`/`X` with the real
feature name throughout — `theme`, `Theme`, or whatever it is). Mirrors
`feature_settings_api`/`feature_settings`, the one feature this template
ships end to end.

## `packages/feature_x_api/` — contracts only

```
packages/feature_x_api/
├── pubspec.yaml
├── lib/
│   ├── feature_x_api.dart        # exports src/* — the public contract surface
│   └── src/
│       ├── x_api.dart            # abstract port(s): the contract app/ and
│       │                         # other features consume
│       ├── x_keys.dart           # ValueKey namespace: 'x.<screen>.<element>'
│       ├── x_routes.dart         # route path/name constants
│       └── x_failure_codes.dart  # 'x.<reason>' string constants
└── test/
    └── x_keys_test.dart          # the one thing worth unit-testing here:
                                   # key values are exactly what callers expect
```

`pubspec.yaml` depends on the Flutter SDK only (route/key types reference
`Key`/route classes) plus whatever `base` packages the contract's types
need (typically `app_core`, for `Result`/`AppFailure`) — never a
`feature_impl` package, never another feature's api package unless the
feature genuinely composes another's contract.

## `packages/feature_x/` — the one implementation

```
packages/feature_x/
├── pubspec.yaml
├── lib/
│   ├── feature_x.dart             # `export 'src/x_module.dart' show XModule, createXModule;`
│   │                              # — the single public export; everything
│   │                              # else in src/ is package-private
│   └── src/
│       ├── x_repository.dart      # abstract port the bloc depends on
│       ├── drift_x_repository.dart# the concrete implementation (naming:
│       │                          # `<impl>_x_repository.dart`, e.g. drift-,
│       │                          # in-memory-, whatever backs it)
│       ├── x_api_impl.dart        # implements feature_x_api's XApi by
│       │                          # delegating to the repository
│       ├── x_module.dart          # `XModule { routes, api }` +
│       │                          # `createXModule({...})` — the factory
│       ├── bloc/
│       │   ├── x_event.dart
│       │   ├── x_state.dart       # `@freezed` — sealed states (loading/
│       │   │                      # ready/etc.), never a boolean-flag state
│       │   └── x_bloc.dart
│       └── ui/
│           └── x_screen.dart      # keyed with XKeys from feature_x_api;
│                                  # BlocProvider(create:) here, not in app/
└── test/
    ├── x_bloc_test.dart           # bloc_test + mocktail, mirrors
    │                              # settings_bloc_test.dart
    ├── drift_x_repository_test.dart # in-memory drift, mirrors
    │                                # drift_settings_repository_test.dart
    ├── x_screen_test.dart         # patrol widget test, mirrors
    │                              # settings_screen_test.dart
    └── x_module_test.dart         # module assembly test, mirrors
                                    # settings_module_test.dart
```

`pubspec.yaml` dependencies (see `packages/feature_settings/pubspec.yaml`
for the exact shape): `flutter` (SDK), `app_core`, `design_system`,
`data_local` (or whatever `base` packages the repository/UI need),
`feature_x_api`, `flutter_bloc`, `freezed_annotation`, `go_router` as
runtime deps; `flutter_test` (SDK), `bloc_test`, `build_runner`,
`freezed`, `mocktail`, `patrol_finders` as dev deps. Never a dependency on
another feature's impl package (hard invariant 1).

## `docs/reference/package_graph.yaml` entries to add

```yaml
packages:
  # ... existing entries ...
  feature_x_api: { kind: feature_api, allowed_dependencies: [app_core] }
  feature_x:
    kind: feature_impl
    allowed_dependencies:
      [feature_x_api, app_core, design_system, data_local]
```

This is the edit step 1 of the ritual asks for, submitted for human
approval (step 3) before any implementation code exists.

## `app/lib/bootstrap/app_dependencies.dart` wiring

Following the pattern `AppDependencies` already uses for
`createSettingsModule` (see `app/lib/bootstrap/app_dependencies.dart`):

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
       ),
       x = createXModule(
         keyValueDao: database.keyValueDao, // or whatever the module needs
         logger: logger,
       );

  // ... existing fields ...
  final SettingsModule settings;
  final XModule x;

  GoRouter buildRouter() => GoRouter(
    initialLocation: SettingsRoutes.path,
    routes: [...settings.routes, ...x.routes],
  );
}
```

Only `app/` constructs `createXModule(...)` — no other package may import
`feature_x` (only `feature_x_api`), and `app/` is the only place a route
list is assembled into a live `GoRouter`.
