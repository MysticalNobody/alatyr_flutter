# 02 — The package graph and its enforcers

`docs/reference/package_graph.yaml` is the single machine-readable source
of truth for the architecture. Three independent tools parse this exact
file; nothing else hardcodes a boundary, a purity rule, or a banned
package.

## Semantics, stated precisely

- `allowed_dependencies` lists **workspace-member edges only**. It says
  nothing about third-party packages.
- Third-party (pub-hosted) dependencies are governed **solely** by
  `banned_packages` below: anything not on that list is allowed.
- SDK dependencies (`flutter`, `flutter_test`) are forbidden — at both the
  pubspec and the import level — in every package listed under
  `pure_dart_packages`.
- Graph keys are **package names**, not directory paths; package-name →
  directory resolution comes from the workspace list.
- Completeness is checked both ways: every workspace member must appear in
  the graph, and every graph entry must exist on disk.

## The three consumers

1. **`tool/verify_dependencies.dart`** — pubspec level only: every declared
   dependency of every workspace member is allowed by the graph, and
   workspace membership is complete in both directions.
2. **`tool/verify_imports.dart`** — the sole import scanner: a hand-written
   lexer (comment- and string-literal-aware, follows conditional URIs)
   scanning `lib/`, `bin/`, `example/`, `integration_test/`, and `test/` of
   every member. The banned-package rule applies in **all** of those
   scopes — a banned import in a test or a CLI entrypoint is still a
   banned dependency. Boundary, purity, and the `data_local` secret-shaped-
   identifier scan apply to `lib/` only, since those rules govern a
   package's public/production surface. No analyzer runtime; runs in
   under a second with `file:line:col` output.
3. **`alatyr_lints`** — the first-party analyzer plugin, six rules, all
   `WARNING` severity: the same boundary/banned/pure-core rules as above,
   plus three style rules (one-widget-per-file, no-widget-returning-
   function, no-nested-ternary). The two widget rules are exempt in test
   directories; the nested-ternary rule is not. Loaded by `dart analyze`
   — both the root gate stage and each per-member stage — but **never** by
   a one-shot `flutter analyze`, which does not load a plugin host
   (`dart-lang/sdk#63787`).

## Banned means direct, not transitive

`banned_packages` governs **direct declarations and imports only**.
Transitive presence through a canonical package is allowed by design: for
example `provider` sits in `pubspec.lock` as a dependency of
`flutter_bloc` and that is not a violation — nothing in this repo declares
or imports `provider` directly.

## The banned list (with reasons)

| Package | Reason |
|---|---|
| `get_it` | manual constructor DI (spec section 5) |
| `injectable` | manual constructor DI (spec section 5) |
| `riverpod` | bloc is the canonical state management |
| `flutter_riverpod` | bloc is the canonical state management |
| `provider` | bloc is the canonical state management |
| `get` | bloc is the canonical state management |
| `mobx` | bloc is the canonical state management |
| `auto_route` | go_router is the canonical navigation |
| `hive` | drift is the canonical local database |
| `isar` | drift is the canonical local database |
| `built_value` | freezed is the canonical codegen model library |
| `mockito` | mocktail is the canonical test-double library (no codegen mocks) |

See [01](01-overview.md) for where these packages sit, [03](03-feature-contract.md)
for the contract the graph's `feature_api`/`feature_impl` kinds encode.
