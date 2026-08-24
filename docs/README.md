# Alatyr documentation

Machine-checked index: `test/docs_test.dart` asserts that every file listed
here exists, that every relative link in this tree resolves, and that
nothing shipped is in Russian.

## Architecture

One page per topic, newest facts first, always true of the current commit:

- [architecture/01-overview.md](architecture/01-overview.md) — the eight
  workspace members, their layers, the four package kinds.
- [architecture/02-package-graph.md](architecture/02-package-graph.md) —
  `package_graph.yaml` as the single source of truth, its three enforcers.
- [architecture/03-feature-contract.md](architecture/03-feature-contract.md)
  — the `*_api`/impl split, the module factory, the key namespace.
- [architecture/04-composition.md](architecture/04-composition.md) — manual
  constructor DI, the composition root, router assembly.
- [architecture/05-error-handling.md](architecture/05-error-handling.md) —
  `Result`, `AppFailure`, failure codes, where errors surface.
- [architecture/06-security.md](architecture/06-security.md) — the
  dart-defines scheme, `data_secure`, the never-in-repo list.

## Architecture Decision Records

- [adr/README.md](adr/README.md) — what an ADR is here, numbering, the
  draft-escalation flow, the index of all ADRs.
- [adr/template.md](adr/template.md) — the ADR skeleton every entry follows.
- [adr/0001-package-boundaries.md](adr/0001-package-boundaries.md) — the
  four package kinds and the graph-as-truth decision.
- [adr/0002-manual-di.md](adr/0002-manual-di.md) — no get_it/injectable.
- [adr/0003-test-strategy.md](adr/0003-test-strategy.md) — patrol finders,
  opt-in goldens, no coverage floor.
- [adr/0004-single-gate.md](adr/0004-single-gate.md) — one `tool/checks.sh`
  on every machine; a future CI runs it verbatim.
- [adr/0005-cross-review-protocol.md](adr/0005-cross-review-protocol.md) —
  Codex as an independent reviewer.
- [adr/0006-working-placeholder-instantiation.md](adr/0006-working-placeholder-instantiation.md)
  — token replacement over a working app, not a template engine.

## Testing

- [testing/strategy.md](testing/strategy.md) — the pyramid table, no
  coverage floor and why, the patrol-finders policy, "TMS from code",
  the adversarial pass, and the eight verification layers of a feature.
- [testing/widget-test-guardrails.md](testing/widget-test-guardrails.md)
  — the eleven anti-hang rules for widget tests, each with its symptom,
  cause, and recipe.

## Workflow

- [workflow/getting-started.md](workflow/getting-started.md) —
  prerequisites, clone-to-green-gate walkthrough, running the app, and
  the one-time Claude Code / Codex trust steps.
<!-- template-only:begin -->
- `workflow/instantiation.md` — `tool/init.dart` in full: the rename
  plan, the bundle-id grammar, what it deletes. Template-repo only —
  init deletes the page, the tool it documents, and this index entry.
<!-- template-only:end -->
- [workflow/e2e.md](workflow/e2e.md) — `tool/e2e.sh` in full: the device
  spec, the `patrol_cli` pin, exit codes, disk cleanup.
- [workflow/feature-workflow.md](workflow/feature-workflow.md) — the
  graph-first ritual step by step, the role table, the completion-report
  shape, and the opt-in Stop-hook review-gate hardening.
- [workflow/maintenance.md](workflow/maintenance.md) — pin update
  cadence and checklist (Flutter, the codegen ceiling, patrol, the Codex
  model). Survives instantiation.
- [workflow/modules.md](workflow/modules.md) — optional modules
  (superpowers, spec-kit, beads, marionette) and why nothing is vendored.

## Reference

- [reference/package_graph.yaml](reference/package_graph.yaml) — the
  machine-readable dependency graph every enforcer parses.
- [reference/critical_flows.md](reference/critical_flows.md) — the e2e
  test-plan registry; `tool/checks.sh` gate-checks every row.
- [reference/ci_contract.md](reference/ci_contract.md) — no CI is
  wired today (verification is local); the contract any future
  runner must keep.
- [reference/feature_package_skeletons.md](reference/feature_package_skeletons.md)
  — the file trees the graph-first ritual produces for a new feature
  package pair.

## Supersession convention

A doc is never silently rewritten out from under a reader. An obsoleted
doc's first line becomes a blockquote pointing at its replacement, so the
history stays readable in place:

```
> **Superseded by [NEW_DOC_TITLE](relative/path.md) on YYYY-MM-DD.** Kept for history.
```

## Russian twins

During template development each file in this tree had a gitignored
`*.ru.md` twin next to it (for example `docs/README.ru.md`); the public
template ships English only, so a fresh clone contains no twins.
