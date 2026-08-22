# 01 — System overview

Eight workspace members, one dependency graph, one gate. This page is the
map; the detail lives in `docs/reference/package_graph.yaml` and in 02–06.

## Workspace members and their layer

The root `pubspec.yaml`'s `workspace:` list is the same eight packages that
`docs/reference/package_graph.yaml` describes — one member per package
kind, plus the worked example feature:

| Layer | Members |
|---|---|
| `base` | `app_core`, `app_config`, `design_system`, `data_local`, `data_secure` |
| `feature_api` | `feature_settings_api` |
| `feature_impl` | `feature_settings` |
| `app_root` | `app/` (Dart package `alatyr_starter`) |

- **`app_core`** — pure Dart: `Result`/`AppFailure`, the `AppLogger` facade.
- **`app_config`** — pure Dart: typed config parsed from dart-defines.
- **`design_system`** — theme, spacing/radii tokens, base widgets.
- **`data_local`** — the drift database and a generic key-value DAO.
- **`data_secure`** — the `SecureStore` port and its implementations.
- **`feature_settings_api`** — contracts only: `SettingsApi`, route spec,
  `SettingsKeys`, failure codes.
- **`feature_settings`** — the implementation: bloc, screen, repository,
  and the module factory. The worked example that crosses every layer.
- **`app/`** — the single app shell: composition root, router, `MaterialApp`.

See [03](03-feature-contract.md) for the `*_api`/impl split and
[04](04-composition.md) for how `app/` wires all of it together.

## Outside the workspace

- **`lints/`** — the first-party analyzer plugin (see [02](02-package-graph.md)).
  Deliberately not a workspace member: its own `analyzer` pin must not
  constrain every package's codegen stack.
- **`tool/`** — the gate (`tool/checks.sh`), the graph/import validators,
  codegen orchestration, and the shared shell helpers they run under.
- **root `test/`** — fixture tests for the toolchain itself (validators,
  the checks-plan builder, this docs set) — not app code.

## The four package kinds

`base`, `feature_api`, `feature_impl`, `app_root` — declared per package in
`docs/reference/package_graph.yaml`. A `base` package carries no feature
knowledge and is reusable by any feature. A `feature_api` package is
contracts only — no implementation. A `feature_impl` package is the one
place a contract is realized. `app_root` is the only kind allowed to depend
on feature implementations: it constructs them, assembles the router from
their routes, and wires ports.

## The repo is the deliverable

Nothing in this tree is a template file rendered by a separate generator:
this is a fully working, buildable, analyzable Flutter project today, at
this commit. `tool/checks.sh` runs the exact analyzer pass, test suite, and
codegen-freshness check on this tree that a consumer will run on their own
copy after cloning it — there is no separate "what CI verifies" tree and
"what ships" tree that could silently drift apart.

## Next

[02](02-package-graph.md) the package graph and its three enforcers ·
[03](03-feature-contract.md) the feature contract · [04](04-composition.md)
composition and bootstrap · [05](05-error-handling.md) error handling ·
[06](06-security.md) security.
