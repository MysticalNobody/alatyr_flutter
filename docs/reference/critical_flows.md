# Critical flows registry

The e2e test plan: every row names a critical user flow and the patrol
test that proves it. `tool/checks.sh` gate-checks this table — its
`verify_critical_flows` stage resolves every `Test` path and fails when one
does not exist — so a new critical flow without a registered test fails the
gate the same way a stale generated file does.

## Format

```
| Flow | Test |
|---|---|
```

One row per critical flow, in the order flows were added: a short human
name in the `Flow` cell ("settings: choose theme, restart, theme
persisted"), and a repo-relative path to the patrol test that proves it in
the `Test` cell. `Flow` names the behavior, not the test — the `Test`
cell's path is the source of truth for which test proves it, and multiple
flows may point at different test functions inside the same file.

## The registry

| Flow | Test |
|---|---|
| settings: choose dark, restart the app (fresh DI graph over the same on-disk database), dark is restored | `app/integration_test/settings_theme_test.dart` |

## The restart convention

"Restart" has two meanings in this repo, and the registered flow above uses
the first one:

- **In-process restart** (spec section 8's convention, what the registered
  flow proves): the app entrypoint is re-invoked *within one test* — a
  fresh widget tree and a fresh DI graph. On device that is more than the
  widget-level twin in `app/test/app_test.dart`'s `"a fresh app over the
  same database restores the persisted theme"`: production dependencies
  mean the previous graph's `dispose()` closes the file-backed database and
  the new graph reopens it from disk, where the twin runs against an
  in-memory drift instance over a live connection. It proves the app's own
  state (bloc, stream subscriptions, router) rebuilds correctly from data
  that survived on storage; it does not prove anything about OS process
  lifecycle.
- **OS-level process death** (a bonus, not the registered flow):
  `app/integration_test/settings_theme_test.dart` carries a second,
  clearly labelled test that starts in a brand-new OS process, because
  patrol runs every Dart test in its own process — on Android through the
  test orchestrator (`ANDROIDX_TEST_ORCHESTRATOR`, with `clearPackageData`
  deliberately **off** so app data survives between the tests), on iOS
  through `XCUIApplication.launch` per test. That is what a real device
  restart means to a user, so it is worth having, but it is
  order-dependent by construction — it reads state the previous test left
  behind and fails loudly when run alone — which is why the registry
  points at the self-contained flow instead. Order-dependence also costs
  care in naming: Android keeps declaration order, XCTest sorts the
  generated selectors alphabetically, so the two test names in that file
  are written to make both orders agree.
