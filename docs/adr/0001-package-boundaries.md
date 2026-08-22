# ADR-0001: Package boundaries

**Status:** accepted
**Date:** 2026-08-13

## Context

A Flutter starter needs an architecture that stays legible as features are
added by agents working largely unsupervised, without a human re-deriving
"what's allowed to depend on what" from memory on every change.

## Decision

Four package kinds — `base`, `feature_api`, `feature_impl`, `app_root` —
declared per package in `docs/reference/package_graph.yaml`, which is the
single machine-readable source of truth for every allowed dependency edge.
The skeleton is monorepo-minimum: every kind is demonstrated exactly once
(`feature_settings` is the one example feature), and no package exists
without a demonstrated purpose. There is a single app (`app/`); no `apps/`
layout.

## Consequences

Three independent tools (`verify_dependencies`, `verify_imports`,
`alatyr_lints`) parse the same file, so "the graph says X" and "the code
does X" cannot silently drift — a violation is a gate failure, not a code
review nit. A new package's shape is proposed as a graph edit, reviewed by
a human before any implementation code is written (the graph-first
ritual). YAGNI is structural: `domain_core`, a second app target, and any
speculative feature package are absent until a real need creates them
through that same ritual.

## Alternatives considered

- **`apps/` multi-app layout** — rejected; a single app keeps the skeleton
  legible and every enforcer simpler. One app is what this template ships.
- **Pre-creating every plausible package kind's example up front** —
  rejected as speculative; each kind is shown once, deliberately, not
  padded with unused scaffolding.
- **A richer per-package manifest format** (e.g. embedding descriptions,
  owners) — rejected for v1; the graph stays minimal enough that all three
  consumers can parse it without a schema library.
