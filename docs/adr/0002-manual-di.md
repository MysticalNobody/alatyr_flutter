# ADR-0002: Manual dependency injection

**Status:** accepted
**Date:** 2026-08-13

## Context

Every feature module needs its dependencies (a DAO, a logger, a config)
handed to it from somewhere. A service-locator library is the common
default in Flutter apps of this shape.

## Decision

Dependencies are wired by hand, by name, in one place:
`app/lib/bootstrap/app_dependencies.dart`. `AppDependencies`'s constructor
takes every base-layer dependency and passes exactly what each feature
module declares into its factory (`createSettingsModule(...)`). No
service locator, no runtime registration step, no `get_it`/`injectable`.

## Consequences

Every dependency edge is a constructor parameter the analyzer already
checks — a missing wiring is a compile error, not a runtime "type not
registered" exception discovered when the code path finally runs. Tests
construct `AppDependencies` directly with fakes/in-memory implementations,
using the same class production code uses, so there is no second
container configuration to keep in sync. The cost is that
`app_dependencies.dart` grows with every new base-layer dependency and
every feature module — an accepted, visible cost, not a hidden one.

## Alternatives considered

- **`get_it`** — rejected; a global registry hides the dependency graph
  behind runtime lookups and defers "is this wired?" from compile time to
  whenever the lookup executes. Listed in `banned_packages`.
- **`injectable`** — rejected for the same reason; codegen over a locator
  still leaves the locator's runtime-lookup failure mode. Listed in
  `banned_packages`.
- **Riverpod's provider graph as a DI mechanism** — out of scope here:
  riverpod is banned as the state-management choice (bloc is canonical),
  and using it only for DI would still add the dependency.
