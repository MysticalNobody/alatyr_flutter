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
  locally and in CI.
- [adr/0005-cross-review-protocol.md](adr/0005-cross-review-protocol.md) —
  Codex as an independent reviewer.
- [adr/0006-working-placeholder-instantiation.md](adr/0006-working-placeholder-instantiation.md)
  — token replacement over a working app, not a template engine.

## Reference

- [reference/package_graph.yaml](reference/package_graph.yaml) — the
  machine-readable dependency graph every enforcer parses.

The rest of `docs/reference/`, `docs/testing/`, and `docs/workflow/` land in
a later task of this milestone; this index grows with them.

## Supersession convention

A doc is never silently rewritten out from under a reader. An obsoleted
doc's first line becomes a blockquote pointing at its replacement, so the
history stays readable in place:

```
> **Superseded by [NEW_DOC_TITLE](relative/path.md) on YYYY-MM-DD.** Kept for history.
```

## Russian twins

Every file in this tree has a `*.ru.md` twin next to it (for example
`docs/README.ru.md`). Twins are gitignored (`*.ru.md`) and exist only during
template development — the public template ships English only.
