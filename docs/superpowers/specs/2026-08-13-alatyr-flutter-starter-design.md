# Alatyr — Flutter Starter for AI-Agent Development: Design

- **Date:** 2026-08-13
- **Status:** approved; implementation in progress (M2 done)
- **Scheme:** Claude Code implements, OpenAI Codex cross-reviews

## 1. Purpose and constraints

Alatyr is a public, MIT-licensed GitHub **template repository**: a Flutter monorepo
starter purpose-built for AI-agent development. Its core value is **hardness**:
every architectural rule is machine-enforced, every correctness claim is backed by
a runnable verification layer, and every source of truth is in-repo, greppable,
and diffable.

Constraints:

- **No credentials or sensitive data** in the repo or its git history. Local env
  files follow a committed `*.example` scheme; only public client values (base
  URLs, publishable keys) may ever be compiled into the app.
- **Product-agnostic.** Nothing ties the template to a specific product.
- **English-only in shipped files.** During template development, Russian doc
  twins (`*.ru.md`) exist locally and are gitignored.
- **Current-generation agent conventions** (August 2026): canonical `AGENTS.md`
  with a `CLAUDE.md` `@AGENTS.md` import bridge, skills instead of legacy
  commands, path-scoped `.claude/rules/`, official Codex hooks and project
  `.codex/config.toml`, native `codex review`.

Consumer story: click "Use this template" → `dart run tool/init.dart --name my_app
--org com.example` → a hardened AI-dev harness with one worked example feature.

## 2. Principles

1. **Single source of truth; everything else derived.** The dependency graph
   lives in one YAML file consumed by three independent enforcers. Package
   discovery derives from the workspace list. Codegen plans derive from
   `build_runner` presence. Prose never restates what a machine-readable file
   already owns.
2. **Tools, not process.** Anything that must always hold is enforced by a hook,
   a validator, or the gate — never by asking the agent nicely.
3. **The repo is the deliverable.** The template is a fully working Flutter
   project (buildable, runnable, analyzable), not a set of template files.
   Drift between "what CI tests" and "what users receive" is impossible by
   construction.
4. **Role separation.** The agent implements; tools verify; an independent AI
   (Codex) reviews; the human decides at exactly two checkpoints — approving
   the dependency-graph diff before code, and behavioral checks of UI changes.
5. **Fail fast and loud.** A hung gate is worse than a red gate: every analyze
   and test invocation runs under a hard OS wall-clock timeout that names the
   offending package.
6. **YAGNI.** Every package kind is demonstrated at least once, and no package
   exists without a demonstrated purpose. New packages are born through the
   graph-first ritual, not pre-created "just in case".

## 3. Repository layout

```
alatyr_flutter/
├── AGENTS.md                  # canonical agent contract (agents.md standard)
├── CLAUDE.md                  # line 1: @AGENTS.md, then Claude-specific notes
├── README.md                  # human-facing: pitch, quick start, maintenance
├── LICENSE                    # MIT
├── pubspec.yaml               # Dart pub workspace root
├── analysis_options.yaml      # root analysis config, wires the lint plugin
├── .fvmrc                     # single Flutter version pin (fvm + CI)
├── .gitignore
├── app/                       # the single app shell (working placeholder)
│   ├── lib/                   #   main.dart, bootstrap/ (composition root)
│   ├── integration_test/      #   patrol e2e tests for critical flows
│   ├── android/ ios/ web/ ... #   native shells, placeholder identity
│   └── pubspec.yaml
├── packages/
│   ├── app_core/              # base, pure Dart: Result, AppFailure, logging facade
│   ├── app_config/            # base, pure Dart: typed config from dart-defines
│   ├── design_system/         # base, Flutter: theme, tokens, base widgets
│   ├── data_local/            # base, Flutter: drift database + KV DAO
│   ├── data_secure/           # base, Flutter: secure storage port + impl
│   ├── feature_settings_api/  # feature_api: contracts only
│   └── feature_settings/      # feature_impl: bloc, screen, repository, module
├── lints/                     # analyzer plugin (NOT a workspace member)
├── tool/                      # gate, validators, init, e2e, hooks
│   ├── checks.sh              #   the canonical quality gate (tiered)
│   ├── common.sh              #   run_guarded timeouts, fvm-first helpers
│   ├── codegen.sh             #   workspace-wide build_runner
│   ├── e2e.sh                 #   patrol runner (find-or-create device)
│   ├── e2e.yaml               #   declarative e2e device profiles (committed)
│   ├── init.dart              #   one-shot template instantiation (self-deleting)
│   ├── verify_dependencies.dart
│   ├── verify_imports.dart
│   ├── checks_workspace.dart  #   derives the per-package analyze/test plan and
│   │                          #   the codegen plan from the root workspace list;
│   │                          #   consumed by checks.sh; unit-tested from test/
│   ├── hooks/guard_generated.sh  # ONE hook script for BOTH agents
│   └── src/                   #   shared tool logic (unit-tested from root test/)
├── test/                      # fixture tests for the toolchain itself
├── docs/                      # see §13
│   └── reference/package_graph.yaml   # THE machine-readable graph
├── .dart-defines/             # local env files; only *.env.example committed
├── .claude/
│   ├── settings.json          # permissions + hooks wiring
│   ├── rules/                 # path-scoped rules (testing, widgets, codegen)
│   ├── skills/
│   │   ├── cross-review/      # Codex review protocol
│   │   └── adversarial-tests/ # test-breaker orchestration
│   └── agents/
│       └── test-breaker.md    # fresh-context adversarial scenario generator
├── .codex/
│   ├── config.toml            # review profile (trust-gated project config)
│   ├── hooks.json             # official Codex hooks schema → shared script
│   └── review-schema.json     # structured findings schema
└── .github/workflows/
    ├── ci.yml                 # CI=1 tool/checks.sh (ubuntu, Flutter from .fvmrc)
    ├── e2e.yml                # tool/e2e.sh android (same committed device spec)
    └── template-smoke.yml     # init fixture → full gate (deleted by init)
```

## 4. Instruction layer

**`AGENTS.md`** is the single canonical contract (< 8 KB; Codex reads AGENTS.md
natively with a 32 KiB default cap, Claude Code imports it). Sections:

1. **Instruction priority:** user > AGENTS.md > docs/architecture > ADRs >
   docs/reference > README. The ladder governs **prose** instructions only:
   machine-readable reference files (`package_graph.yaml`,
   `critical_flows.md`) outrank any prose that restates them — on conflict,
   the machine file wins and the prose is the bug.
2. **Canonical stack and banned alternatives** (see §5).
3. **Package kinds and boundaries** — brief prose; the machine truth is
   `docs/reference/package_graph.yaml`, and prose defers to it.
4. **Hard invariants** (numbered):
   1. Cross-feature dependencies go only through `*_api` packages.
   2. Only `app/` may depend on feature implementation packages.
   3. `app_core` and `app_config` stay pure Dart (no Flutter SDK).
   4. Runtime secrets/tokens live only in `data_secure` — never in drift,
      prefs, logs, or source.
   5. Generated files (`*.g.dart`, `*.freezed.dart`, `*.drift.dart`) are never
      hand-edited; regenerate via `tool/codegen.sh`.
   6. Any dependency change starts with a `package_graph.yaml` edit approved by
      a human before implementation code is written.
   7. Every interactive widget carries a `ValueKey` from its feature's key
      namespace (serves patrol finders and optional runtime drivers).
   8. Widget and integration tests use patrol finders; every critical flow has
      a patrol test registered in `docs/reference/critical_flows.md`.
   9. No dependencies outside the canonical stack without an accepted ADR; the
      banned list in `package_graph.yaml` is authoritative.

   Each invariant has a named enforcement owner (Principle 2 — no rule lives
   on prose alone):

   | Invariant | Enforced by |
   |---|---|
   | 1, 2, 3, 9 | verify_dependencies + verify_imports + lint plugin (from the graph) |
   | 4 | heuristic secret-leak scan over `data_local` in verify_imports + `permissions.deny` on env reads + review rubric (**accepted partial gap**: full semantic secret-tracking is review-owned) |
   | 5 | guard_generated hook (both agents) + codegen-freshness snapshot stage |
   | 6 | human graph-diff approval (the deliberate human checkpoint) |
   | 7 | review rubric + patrol e2e reality check (**accepted gap**: no lint rule in v1 — a missing key surfaces the moment a flow test needs it) |
   | 8 | critical-flows registry check in the gate + review rubric |
5. **The graph-first feature ritual** (see §5).
6. **Definition of Done:**
   1. `tool/checks.sh` (full) is green.
   2. Adversarial pass completed for new/changed behavior: test-breaker
      scenarios are covered by tests or explicitly skipped in code with a
      reason (`skip: 'deliberate: …'`).
   3. `tool/e2e.sh` is green when critical flows are touched.
   4. Codex cross-review completed; no open P0/P1 findings (each is fixed or
      rebutted with recorded reasoning). If review is honestly impossible
      (codex absent, model rejected), the human explicitly waives this item
      and the waiver is recorded in the task report — the agent never waives
      it unilaterally.
   5. Human behavioral check for UI-affecting changes.

   Every completion report ends with a mandatory **Remaining risks** section
   consolidating waivers, deliberate skips, and unverified assumptions (an
   empty section states "none" explicitly) — the honesty forcing-function
   behind any "done" claim.
7. **Stop conditions:** ambiguity → stop and ask or file an ADR draft; never
   improvise around a failing gate; keep diffs scoped to the task.
8. **Commands:** `tool/checks.sh --fast` | full | `--package <p>`,
   `tool/codegen.sh`, `tool/e2e.sh`, `dart run tool/init.dart`.
9. **`## Code Review Rules`** (final section — natively consumed as a review
   rubric by `codex review` and Codex cloud PR review; `codex exec` receives
   AGENTS.md as a project doc and the cross-review skill's structured path
   additionally instructs "apply the Code Review Rules" in the prompt): flag
   P0/P1 only —
   unawaited futures, `BuildContext` across async gaps, missing `dispose`,
   `setState`/`emit` after dispose/close, secrets in code, semantic violations
   of `*_api` contracts, tests that assert nothing, adversarial scenarios
   silently dropped. Leave formatting and style to the gate.

**`CLAUDE.md`** — first line `@AGENTS.md`, then ~30 lines of Claude-only notes:
when to invoke `cross-review` and `adversarial-tests` skills, what the
PreToolUse hook will block and what to do instead. **Rubric vs role:** the
rubric (*what findings matter*) lives in AGENTS.md because Codex consumes it
natively; role-assignment instructions (*"act as a reviewer, do not
implement"*, invocation shape, sandbox) live only in the skill and the review
profile — never in AGENTS.md, which Claude imports and Codex cloud applies to
implementation tasks too.

**`.claude/rules/`** — path-scoped modular rules:

- `testing.md` (`paths: **/test/**, **/integration_test/**`): patrol-finders
  conventions, widget-test guardrails digest, test-naming-as-test-case rule,
  the `skip: 'deliberate: …'` convention.
- `widgets.md` (`paths: packages/design_system/**, **/widgets/**`): design
  system conventions, ValueKey namespace rule.
- `codegen.md` (`paths: **/*.g.dart, **/*.freezed.dart, **/*.drift.dart`):
  never edit; run `tool/codegen.sh`.

No `llms.txt`. No nested `AGENTS.md`. `CLAUDE.local.md` is the documented
gitignored personal-overrides file (used during template development for the
Russian-twin rule; consumers may use it for their own local notes).

## 5. Architecture

**Package kinds** (exactly four): `base`, `feature_api`, `feature_impl`,
`app_root`. Declared per-package in `package_graph.yaml`.

**Feature contract:**

- `feature_x_api` exports **contracts only**: route specs, models, abstract
  ports, failure-code constants. No implementation. `*_api` packages are
  Flutter packages (so navigation/UI contracts never force a kind migration).
- `feature_x` exports **exactly one factory**: `createXModule(...)` returning
  `XModule { List<RouteBase> routes; XApi api; }`. Everything else is private.
- Cross-feature consumption goes only through `*_api`. Only `app/` constructs
  implementations (manual constructor DI in `bootstrap/`), assembles go_router
  from module routes, and wires ports.

**Canonical stack** (pinned in AGENTS.md; banned list lives in
`package_graph.yaml`):

| Concern | Canonical | Banned |
|---|---|---|
| State | `bloc` / `flutter_bloc` | riverpod, provider, getx, mobx |
| Navigation | `go_router` | auto_route |
| DI | manual constructor injection | get_it, injectable |
| Local DB | `drift` | hive, isar, shared_preferences-as-DB |
| Codegen models | `freezed` (+ `json_serializable`) | built_value |
| Secure storage | `flutter_secure_storage` | — |
| Widget/e2e tests | `patrol_finders` / `patrol` | raw flutter_test finders in new tests¹ |
| Test doubles | `mocktail` | mockito (codegen mocks) |
| Networking | *reserved:* `dio` (+ `retrofit`) — enters with the first `data_remote` package via the ritual | — |

¹ Two kinds of bans with different owners: **machine bans** are packages listed
in `banned_packages` (get_it, riverpod, mockito, …) and are enforced by the
graph consumers; **convention bans** are usage patterns a pubspec check cannot
express (raw flutter_test finders in new tests, shared_preferences-as-DB) and
are owned by `.claude/rules/testing.md` + the Code Review Rules rubric.

**The graph-first ritual** (for every new feature/package):

1. Agent proposes the package shape by **editing `package_graph.yaml`**
   (new packages, kinds, `allowed_dependencies`) and drafts the feature plan.
2. *Optional, recommended for non-trivial features:* **challenge the plan** —
   a fresh read-only Codex pass over the plan and graph diff
   (`codex exec -s read-only`), hunting misunderstood requirements, missing
   edge cases, excess complexity, and architectural conflicts. Findings come
   back as BLOCKER/MAJOR/MINOR with an `APPROVE`/`REVISE` verdict; one round
   is normally enough. The agent evaluates findings on merit — never
   auto-applies them. Catching a wrong plan here costs minutes; catching it
   in the diff costs the whole implementation.
3. Human approves the graph diff (a 30-second review — the single cheap
   checkpoint tools cannot replace: "is this designed right?").
4. Agent implements in fixed order: `*_api` → impl → wiring in `app/`.
5. Tools enforce "code matches graph" continuously; the gate, adversarial
   pass, cross-review, and behavioral check close the loop (§10).

## 6. Enforcement stack

**`docs/reference/package_graph.yaml`** — extended single source of truth.
Semantics, stated precisely because all three enforcers parse this schema:

- `allowed_dependencies` governs **workspace-member edges only**. Third-party
  (pub-hosted) dependencies are governed solely by the `banned_packages`
  blocklist; anything not banned is allowed.
- SDK dependencies (`flutter`, `flutter_test`) are allowed everywhere
  **except** packages listed in `pure_dart_packages`, which may not depend on
  the Flutter SDK or on any Flutter-dependent package (checked at pubspec and
  import level).
- Graph keys are **package names**. The app entry is named `alatyr_starter` —
  the same identity token init replaces repo-wide, so instantiation rewrites
  the graph automatically (§9). Package-name → directory resolution comes from
  the workspace list.

```yaml
package_kinds: [base, feature_api, feature_impl, app_root]
banned_packages:            # third-party blocklist, with reasons; authoritative
  get_it: "manual constructor DI (ADR-0002)"
  riverpod: "bloc is canonical state management"
  # ...
pure_dart_packages: [app_core, app_config]
packages:                   # allowed_dependencies = workspace members only
  app_core:        { kind: base,         allowed_dependencies: [] }
  app_config:      { kind: base,         allowed_dependencies: [app_core] }
  design_system:   { kind: base,         allowed_dependencies: [app_core] }
  data_local:      { kind: base,         allowed_dependencies: [app_core] }
  data_secure:     { kind: base,         allowed_dependencies: [app_core] }
  feature_settings_api: { kind: feature_api,  allowed_dependencies: [app_core] }
  feature_settings: { kind: feature_impl,
                      allowed_dependencies: [feature_settings_api, app_core,
                                             design_system, data_local] }
  alatyr_starter:  { kind: app_root,     allowed_dependencies: "*_all_members" }
```

No hardcoded rule lists anywhere else — all three consumers parse this file.
Completeness is checked both ways (every workspace member is in the graph;
every graph entry exists on disk).

**Three independent consumers:**

1. `tool/verify_dependencies.dart` — pubspec-level only: every declared
   dependency is allowed by the graph; workspace membership is complete.
2. `tool/verify_imports.dart` — the **sole** import scanner: a hand-written
   lexer (comments, raw/triple-quoted strings, conditional imports) enforcing
   boundary + banned + pure-core rules in < 1 s with `file:line:col` output,
   plus a heuristic secret-leak scan over `data_local` (token/secret-shaped
   identifiers in persistence code — invariant 4's tool layer). Deliberate
   defense-in-depth: it needs no analyzer runtime and cannot hang.
3. `lints/` — first-party analyzer plugin for IDE-time feedback: the same
   graph rules (`alatyr_boundary_import`, `alatyr_banned_dependency`,
   `alatyr_pure_core`) plus style rules (`alatyr_one_widget_per_file`,
   `alatyr_no_widget_returning_function`, `alatyr_no_nested_ternary`; test
   files exempt). Three design decisions carried from the proven original:
   pure decision logic split from AST adapters (unit tests < 1 s); the plugin
   is **not** a workspace member (its analyzer pins never constrain the app's
   codegen stack); an in-repo violations fixture with an integration check
   asserting each rule fires exactly N times. The `analysis_server_plugin`
   version pin must be re-validated against the chosen Flutter stable (known
   hang regression history).

**`tool/checks.sh`** — the canonical tiered gate (identical locally and in CI):

- `--fast`: format check → graph → imports (~5 s). Agent inner loop, pre-commit.
- **full** (default): fast stages → worktree snapshot (tracked+staged diff +
  untracked hashes) → codegen (`build_runner build --low-resources-mode
  --delete-conflicting-outputs` in every package declaring `build_runner`) →
  snapshot compare (**any** delta = stale generated artifacts → fail; tolerant
  of a dirty developer tree) → **toolchain tests** (`dart test` at the
  workspace root, under `run_guarded` — the fixture tests for init, both
  validators, the lexer, the plan builder, the e2e config parser; the
  verifiers are themselves gated) → per-package analyze+test from a plan
  derived from the root `workspace:` list (`flutter analyze --no-pub
  --fatal-infos` / `flutter test --no-pub` after the single resolve;
  `dart analyze --fatal-infos` / `dart test` for pure packages) → lints
  plugin isolated (pub get, analyze, test) → violations-fixture integration
  check → critical-flows registry check (every entry points to an existing
  test file).
- `--package <p>`: targeted analyze+test for one package.
- Generated files (`*.g.dart`, `*.freezed.dart`, `*.drift.dart`) are
  **committed**; `.gitignore` must not exclude them — the freshness stage
  depends on this policy.
- CI detection: any truthy `CI` env var (GitHub Actions sets `CI=true`).
  Outside a git repo: loud warning locally; in CI the freshness check being
  unavailable is a hard error.
- `tool/common.sh`: `run_guarded` hard OS wall-clock timeouts per package
  (analyze 180 s, test 300 s; `gtimeout` → `timeout` → perl-alarm fallback),
  fvm-first with bare fallback. Rationale: `flutter test --timeout` does not
  catch teardown hangs; a hung gate silently stalls an agent loop.
- Parallelism deliberately deferred (8 workspace members keep the full gate
  fast); revisit only on real pain.

**Agent-level hooks — one script, two thin configs:**

- `tool/hooks/guard_generated.sh`: blocks Edit/Write on `*.g.dart`,
  `*.freezed.dart`, `*.drift.dart` → exit 2 + "run tool/codegen.sh".
- `.claude/settings.json`: PreToolUse wiring via `${CLAUDE_PROJECT_DIR}`;
  PostToolUse hook running `dart format` on the edited `*.dart` file (keeps
  the format stage permanently green); `permissions.allow` for
  `flutter analyze/test`, `dart format/test/run`, `tool/*.sh`;
  `permissions.deny` for `Read(.dart-defines/*.env)`.
- `.codex/hooks.json`: the official Codex hooks schema, same script by
  repo-relative path (loads after one-time project trust). *Implementation
  note:* Codex-side matcher names for file-editing tools, blocking exit-code
  semantics, and relative-path resolution are unverified against the current
  schema — confirm during implementation; if Codex-side blocking differs, the
  codegen-freshness gate remains the backstop for invariant 5.

**Root `test/`** — fixture tests for the entire toolchain: init renamer, both
validators, the import lexer, the checks plan builder, the e2e config parser.
The verifiers are themselves verified.

## 7. Cross-review protocol (Codex)

**`.claude/skills/cross-review/`** — repo-level skill:

1. **Pre-flight:** `codex` binary present; diff vs base branch non-empty.
   If not runnable → **honest failure**: report "review not performed
   because …"; never fabricate a verdict.
2. **Primary invocation:** `codex review --base <branch> --json "<reviewer
   prompt>"` — purpose-built, honors `## Code Review Rules` from AGENTS.md.
   Default base ref: `main`; overridable via skill argument.
3. **Structured path** (when machine-readable findings are needed):
   `codex exec --profile review --ephemeral --sandbox read-only
   --output-schema .codex/review-schema.json` over `git diff --merge-base
   main HEAD`, with an explicit "apply the Code Review Rules from AGENTS.md"
   instruction in the prompt.
4. **Evaluate, don't obey:** every P0/P1 is either fixed or explicitly
   rebutted with reasoning in the task report; P2/P3 at the implementer's
   discretion; the verdict is quoted, not paraphrased.

**`.codex/config.toml`** (project-scoped; loads after one-time trust —
documented in getting-started):

```toml
review_model = "gpt-5.6-sol"

[profiles.review]
model = "gpt-5.6-sol"
model_reasoning_effort = "high"
sandbox_mode = "read-only"
approval_policy = "never"
```

**`.codex/review-schema.json`:** `findings[] { title, body, priority (0–3),
confidence_score (0–1), code_location { filepath, line_range } }` (the Codex
SDK cookbook findings shape) plus a top-level
`verdict: approve | request_changes` field.

One rubric, three consumers: the same `## Code Review Rules` section drives
local CLI review, headless review, and Codex cloud PR review (`@codex review`)
with zero extra configuration. Read-only sandbox + `approval_policy = "never"`
make the reviewer physically unable to modify files. A Stop-hook-enforced
review gate is documented as an opt-in hardening in a dedicated subsection of
`docs/workflow/feature-workflow.md`, not wired by default. The model pin will
rot; `docs/workflow/maintenance.md` owns it (§13, §15).

## 8. Package skeleton and the example feature

Eight workspace members (see §3) — every package kind demonstrated, no
speculative packages.
`feature_settings` (theme mode: system/light/dark) is the worked example
because it is product-neutral yet crosses **every** layer: design_system
widgets → bloc → repository port → drift (codegen!) → app wiring — and
demonstrates external consumption: `MaterialApp.themeMode` in `app/` is driven
through a port from `feature_settings_api`.

Shipped test exemplars (the copyable pattern set): bloc tests, structural
widget tests via patrol finders, repository tests on in-memory drift
(`NativeDatabase.memory()`), module assembly test, app bootstrap smoke test,
one patrol e2e (launch → settings → toggle theme → restart → theme persisted).
"Restart" here means re-invoking the app entrypoint within the test (fresh
widget tree and DI graph, same storage); OS-level process-death testing is out
of scope — the convention is recorded in `critical_flows.md`.

Deliberately absent: `domain_core` (would be empty; born via the ritual when
shared domain types appear), auth/home scaffolds, `data_remote` (born with the
first network need, bringing the reserved dio/retrofit decision as an ADR).

## 9. Instantiation

The template is a **working placeholder project** with a unique, greppable
identity — instantiation is a deterministic token replacement, not templating
(mason and `.tmpl` approaches were evaluated and rejected: they make the repo
a non-project — analyzer off, unreadable on GitHub, verifiable only through
render-fixture CI; even mason's authors ship their template product as a
working app and machine-generate the brick from it).

**Placeholder identity:**

| Token | Value |
|---|---|
| Dart package / project name | `alatyr_starter` |
| Org / bundle id | `dev.alatyr` / `dev.alatyr.starter` |
| Display name | `Alatyr Starter` |
| Workspace root name | `alatyr_workspace` |

**`dart run tool/init.dart --name my_app --org com.example
[--display-name "My App"] [--yes]`:**

1. Validates inputs (Dart identifier, reverse-domain org).
2. Whole-token replacement of placeholder identity across the repo (file
   contents and paths). The tokens legitimately appear only in: `app/` and
   native shells, root `pubspec.yaml` (workspace name),
   `docs/reference/package_graph.yaml` (the app entry), and `README.md`.
   `packages/`, `lints/`, `tool/` are product-neutral by construction, and a
   template test asserts they contain no identity tokens.
3. Android: moves package directories, rewrites `MainActivity` package and
   Gradle `applicationId`/`namespace`.
4. iOS/macOS: rewrites `PRODUCT_BUNDLE_IDENTIFIER` and display name scoped to
   app targets only (known third-party-tool pitfalls — over-renaming extension
   targets, missing `CFBundleIdentifier` customizations — are in the fixture
   test matrix).
5. Web/Linux/Windows: manifest/title/binary-name updates.
6. Replaces `README.md` with a product stub (link back to Alatyr), removes
   init machinery (`tool/init.dart`, `tool/src/init_*`, their tests),
   `template-smoke.yml`, and this spec's `docs/superpowers/` history.
7. Runs `dart format` over modified Dart files (token replacement can change
   line lengths; the format gate must stay green — the fixture matrix includes
   long-name cases), then `dart pub get` + `tool/checks.sh --fast` as a
   post-init smoke.

Post-init identity changes are a manual operation, as in any Flutter project
(deliberate YAGNI). `tool/init.dart` logic lives in `tool/src/` and is covered
by fixture tests, including pbxproj edge cases.

## 10. Testing and verification

**Test types (all present in the skeleton as copyable exemplars):**

| Layer | Test type | Tools |
|---|---|---|
| app_core, app_config | pure unit | `test` |
| Blocs | bloc tests | `bloc_test`, `mocktail` |
| Repositories | unit on real DB | drift in-memory |
| Screens | structural widget tests | `patrol_finders` (`$` syntax) |
| Feature module | assembly test | `flutter_test` + patrol finders |
| App shell | bootstrap smoke | `flutter_test` |
| Critical flows | patrol e2e | `patrol` via `tool/e2e.sh` |
| Toolchain | fixture tests | `test` (root `test/`) |
| Lint rules | unit + integration fixture | `test` + real `dart analyze` |

**Patrol e2e:** lives in `app/integration_test/`; **not** part of
`checks.sh` (device required; the core gate stays fast and deterministic).
`docs/reference/critical_flows.md` is the flow registry (flow name → patrol
test path); the gate verifies every entry points to an existing file; a new
feature with a critical flow must add a row + test (reviewable in the diff).

**e2e device config — `tool/e2e.yaml`** (committed; no machine-specific IDs —
devices are found-or-created from declarative specs, so local and CI runs use
the same pinned API level and device profile; the system image is pinned **per
host architecture**, since an arm64 image cannot boot under KVM on x86_64
runners and vice versa):

```yaml
default_platform: android
android:
  avd_name: e2e_pixel
  device_profile: pixel_7
  api_level: 34
  system_images:
    arm64:  system-images;android-34;google_apis;arm64-v8a
    x86_64: system-images;android-34;google_apis;x86_64
ios:
  simulator_name: e2e_iphone
  device_type: iPhone 16
  runtime: iOS 18.0
```

`tool/e2e.sh [android|ios] [-t <test>] [--device <id>] [--list]`: read config →
find-or-create the pinned AVD/simulator → boot → `patrol test` under
`run_guarded` → shut down in CI, keep alive locally. No "first available
device" fallback — missing tooling produces an actionable error.

**Adversarial test design** (the anti-self-confirmation layer):

- `.claude/agents/test-breaker.md` — project subagent, **fresh context**
  (uncontaminated by the implementer's reasoning), read-only tools. Input:
  the `*_api` contract, feature spec, diff. Output: structured break
  scenarios — boundary values, races/double-taps, lifecycle (dispose during
  load, emit after close), process death/restart, dependency failures,
  corrupted stored data — each as "action → required behavior → test layer".
- `.claude/skills/adversarial-tests/` orchestrates: invoke test-breaker →
  implement tests for each scenario → deliberately-uncovered scenarios become
  skipped test stubs with reasons (`skip: 'deliberate: …'`) — enumerable by
  machine, visible in the diff, impossible to lose silently.

**Test-case management ("TMS from code" — no external TMS):** test names are
the test cases (`'given stored theme is corrupted, settings falls back to
system'`), so the case catalog is generated from code (`flutter test
--reporter json`), never hand-maintained; the critical-flows registry is the
e2e test plan; skipped stubs are the record of known-uncovered scenarios.
Rationale: an external TMS adds credentials and a second source of truth that
drifts silently and is invisible to agents, the gate, and review.

**Deliberately absent:** coverage thresholds (they reward percentage-chasing
and slow the gate; hardness comes from mandatory test types + review of test
quality), golden tests in the default gate (opt-in only, Flutter-engine only,
deterministic harness; cross-engine visual comparison is banned by ADR),
e2e in `checks.sh`.

**The eight verification layers of a feature:**

1. Types + analyzer (`--fatal-infos`) — instant.
2. Architecture: graph / imports / lints — seconds, machine.
3. Package test pyramid (widget tests via patrol finders) — minutes, machine.
4. Codegen freshness (snapshot diff) — machine.
5. Adversarial tests (fresh-context test-breaker) — machine + independent context.
6. Patrol e2e over registered critical flows — machine, on-device.
7. Codex cross-review of the diff — independent AI.
8. Human behavioral check (UI changes) — the one human layer, by design.

## 11. CI

- **`ci.yml`** — PRs + main. `ubuntu-latest` (+ `libsqlite3-dev` for drift
  tests — standard drift practice, verify on first CI run), Flutter via
  `flutter-action` pinned from `.fvmrc`, then exactly: `tool/checks.sh`
  (GitHub sets `CI=true`; checks.sh detects it). CI owns no logic
  (`docs/reference/ci_contract.md`).
- **`e2e.yml`** — PRs to main. GitHub-hosted x86_64 ubuntu runner with KVM
  enabled, `tool/e2e.sh android` with the same committed device spec (x86_64
  system image per `e2e.yaml`). KVM/emulator viability on hosted runners is
  verified during implementation (§15).
- **`template-smoke.yml`** — template-repo only: copy the tree → `git init &&
  git add -A` in the copy (the freshness stage requires a git worktree) →
  `init.dart --name fixture_app --org dev.fixture --yes` → full `checks.sh`
  on the result. Deleted by init.
- Claude GitHub bot and Codex cloud PR review are **documented, not shipped**
  (they need per-user secrets/app installs; Codex cloud needs zero workflow —
  installing the GitHub app already picks up `## Code Review Rules`).

## 12. Pluggable modules (nothing vendored)

All evaluated modules churn faster than a template can track (beads swapped
storage backends within a year; spec-kit releases near-daily), so the template
vendors none of them — `docs/workflow/modules.md` carries install one-liners
and scope guidance:

- **superpowers** — *recommended*, per-user, zero repo footprint:
  `/plugin install superpowers@claude-plugins-official` (Claude Code) + the
  documented Codex bootstrap. Provides brainstorming/TDD/debugging/review
  discipline that composes with this template's harness.
- **spec-kit** — *optional*, when a real product needs per-feature spec
  ceremony: `uv tool install specify-cli`, `specify init . --integration
  claude`, `specify integration install codex`. The constitution concept is
  already implemented natively by AGENTS.md — no dependency needed for that.
- **beads** — *optional*, long-horizon multi-session work:
  `brew install beads && bd init && bd setup claude && bd setup codex`.
- **marionette** (runtime UI verification: the agent drives the debug app) —
  *optional module page*: wiring `marionette_flutter` into the debug build +
  a verify-flow skill. The core template ships only the ValueKey convention,
  which patrol finders already use — so the module plugs in without code
  changes.

## 13. Documentation set

```
docs/
├── README.md                  # index + supersession-banner convention
├── architecture/
│   ├── 01-overview.md         # system map, package kinds
│   ├── 02-package-graph.md    # graph-as-truth, its three enforcers
│   ├── 03-feature-contract.md # api/impl, module factory
│   ├── 04-composition.md      # manual DI, bootstrap, router assembly
│   ├── 05-error-handling.md   # failure codes, Result
│   └── 06-security.md         # .dart-defines scheme, data_secure, never-in-repo list
├── adr/                       # 0001 boundaries · 0002 manual DI · 0003 test
│   │                          # strategy (structural default, goldens opt-in)
│   │                          # 0004 single gate · 0005 cross-review protocol
│   │                          # 0006 working-placeholder instantiation
│   └── template.md, README.md # ADR-draft escalation flow
├── testing/
│   ├── strategy.md            # pyramid, no-coverage-floor rationale, patrol policy
│   └── widget-test-guardrails.md  # anti-hang rules (FakeAsync/teardown, finite
│                              # fake streams, pumpUntil, drift timers)
├── workflow/
│   ├── getting-started.md     # fvm, init, trust steps (Claude workspace trust;
│   │                          # Codex config + hooks trust), first gate run
│   ├── feature-workflow.md    # the ritual step-by-step (incl. optional
│   │                          # plan-challenge stage) + role table +
│   │                          # opt-in hardening (Stop-hook review gate) +
│   │                          # reasoning-effort escalation note
│   ├── maintenance.md         # pin-update cadence (Codex model, Flutter,
│   │                          # patrol), upgrade checklist — survives init;
│   │                          # README links here
│   └── modules.md             # §12
└── reference/
    ├── package_graph.yaml     # machine truth
    ├── critical_flows.md      # e2e flow registry (gate-checked)
    ├── ci_contract.md         # CI runs checks.sh verbatim; single discovery owner
    └── feature_package_skeletons.md  # file trees for the ritual
```

Every architecture doc is 1–2 pages. Obsoleted docs get a supersession banner,
never a silent rewrite. Russian twins (`*.ru.md`) exist only during template
development and are gitignored.

## 14. Explicitly not taken from ReviDeck

| Not taken | Why |
|---|---|
| `.agent/project/*.yaml` + `sync_project_metadata` | replaced by init-once; no perpetual sync layer |
| `llms.txt`, CLAUDE.md-as-digest | drift source; replaced by `@AGENTS.md` import |
| `apps/` multi-app layout | single app decision |
| `domain_core`, product feature/data packages | each kind shown once; the rest born via the ritual |
| `repo_manifest.yaml` | consumed by nothing; already drifted in origin |
| `checklists.md` board remnants, `CHANGES.md` | reference a deleted harness |
| All product content (product.md, product ADRs, specs, Pencil design files) | product, not template |
| `.cursor/` | Cursor is not part of the scheme |
| `dependency_overrides` pins, sqlite3 user_defines | machine/time-specific workarounds that rot |
| Russian text in shipped files | public template is English |
| `.codex/hooks.json` with absolute path + duplicated script | rebuilt on the official schema, shared script, relative path |
| Coverage gates | never existed; decision now recorded in testing/strategy.md |

## 15. Risks and maintenance

1. **`analysis_server_plugin` pin fragility** — re-validate against the chosen
   Flutter stable during implementation; the deterministic import scanner
   remains the enforcement floor if the plugin misbehaves.
2. **Codex model pin rot** (`gpt-5.6-sol`) — `docs/workflow/maintenance.md`
   owns the update cadence (it survives init; README links to it); the
   cross-review skill fails honestly if the model is rejected.
3. **Patrol ecosystem facts are assumed, not researched** — patrol_finders'
   device-free widget testing, `integration_test/` layout, patrol_cli↔patrol
   version coupling match general knowledge but were not covered by the
   Aug-2026 research pass. Run a short patrol research pass at implementation
   start; pin patrol and patrol_cli; cover setup in getting-started
   troubleshooting.
4. **Codex hook semantics unverified** — matcher names for file-editing
   tools, blocking exit codes, relative-path resolution (§6 implementation
   note); freshness gate is the backstop.
5. **CI environment assumptions to verify on first runs** — drift on
   `ubuntu-latest` with `libsqlite3-dev` (the reference repo used
   macos-latest + a sqlite3 amalgamation for machine-specific reasons we
   deliberately do not carry), and KVM/emulator viability for `e2e.yml` on
   hosted x86_64 runners. Both stated in `ci_contract.md` so failures are
   diagnosable.
6. **Flutter/Dart major upgrades** — a documented upgrade checklist in
   `docs/workflow/maintenance.md`: bump `.fvmrc`, re-validate the plugin pin,
   re-run the full gate + template smoke.

## 16. Implementation phasing

Five ordered milestones, each independently green before the next starts, so a
failure in one subsystem (e.g. the lint-plugin pin) never blocks the rest:

1. **M1 — Workspace + gate core:** root workspace, `app_core`/`app_config`,
   `package_graph.yaml`, both validators, `checks.sh` (`--fast` + full
   skeleton), `common.sh`, root toolchain tests, `ci.yml`.
2. **M2 — Lint plugin:** `lints/` with graph + style rules, violations
   fixture, integration check; `analysis_server_plugin` pin validation.
3. **M3 — Example slice:** `design_system`, `data_local`, `data_secure`,
   `feature_settings_api`/`feature_settings`, `app/` wiring; the full test
   exemplar set; codegen freshness live.
4. **M4 — Agent harness:** AGENTS.md, CLAUDE.md, rules, hooks for both
   agents, skills (cross-review, adversarial-tests), test-breaker agent,
   `.codex/` config + schema, the docs set.
5. **M5 — Instantiation + e2e:** `init.dart` + fixture tests +
   `template-smoke.yml`; `e2e.sh` + `e2e.yaml` + the patrol exemplar +
   `e2e.yml`.

## Appendix A. Decision log (this session, 2026-08-13)

1. Audience: **public open-source** (English, MIT, GitHub template repo).
2. Skeleton: **monorepo-minimum** — full architecture, one example feature.
3. Cross-review hardness: **part of DoD via repo skill; no Stop-hook** by default.
4. Stack: **as ReviDeck** (bloc, go_router, manual DI, drift, freezed).
5. Build approach: **clean-room** — informed by ReviDeck, no code carried over.
6. Single app (`app/`), no `apps/`.
7. Instantiation: **working placeholder + own init tool**; mason and `.tmpl`
   evaluated and rejected (evidence: VGV's own template product is a working
   app with a machine-generated brick).
8. Widget tests exclusively via **patrol finders**; **patrol e2e mandatory for
   critical flows** (registry-backed); e2e devices via declarative committed
   config.
9. **Adversarial test design**: fresh-context test-breaker subagent + skill;
   uncovered scenarios become `skip: 'deliberate: …'` stubs.
10. **No TMS**: test names as cases, registry as e2e plan, skips as the record.
11. Marionette: **optional module**; ValueKey convention in core.
12. Modules: superpowers recommended (per-user), spec-kit/beads optional,
    nothing vendored.
13. Russian doc twins (`*.ru.md`, gitignored) during template development.
14. Adopted after comparison with an external Claude+Codex workflow (Habr
    №1068372, roles inverted there): optional plan-challenge stage in the
    ritual; mandatory "Remaining risks" section in completion reports. Role
    inversion itself rejected — our harness lives on the implementer side
    where Claude Code tooling is richer, and Codex's review tooling is native.
