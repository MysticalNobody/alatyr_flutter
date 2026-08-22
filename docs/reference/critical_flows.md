# Critical flows registry

The e2e test plan: every row names a critical user flow and the patrol
test that proves it. From M5 on, `tool/checks.sh` gate-checks this table —
every `Test` path must exist on disk — so a new critical flow without a
registered test fails the gate the same way a stale generated file does;
today (M4) the table format ships without that gate stage.

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

## The registry (empty — M5 adds the first row)

| Flow | Test |
|---|---|
<!-- first row lands in M5 with app/integration_test/settings_theme_test.dart -->

## The restart convention

"Restart" has two meanings in this repo, and only one of them is what
patrol e2e (M5) exercises:

- **In-process restart** (the widget-level twin, exercised today): a
  second widget tree and DI graph constructed over the *same live*
  storage connection, inside one test process — see
  `app/test/app_test.dart`'s `"a fresh app over the same database restores
  the persisted theme"`. This proves the app's own state (bloc, stream
  subscriptions, router) rebuilds correctly from persisted data; it does
  not prove anything about OS process lifecycle.
- **OS-level process death** (out of scope by design, deferred to the
  patrol e2e flow this registry will hold from M5): killing and
  relaunching the actual process, reopening a file-backed database from
  disk. This is what a real device restart means to a user, and it is
  what the eventual patrol row in this table proves; the in-process test
  above is not a substitute for it, only its cheaper, always-on twin.
