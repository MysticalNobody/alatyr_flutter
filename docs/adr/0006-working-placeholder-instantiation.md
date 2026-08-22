# ADR-0006: Working-placeholder instantiation

**Status:** accepted
**Date:** 2026-08-13

## Context

Turning this template into someone's actual project needs a rename step:
package name, org/bundle id, display name, workspace name. The common
approach for Flutter starters is a templating engine that renders
placeholder tokens into a brick at generation time.

## Decision

The template ships as a working, uniquely and greppably named placeholder
project (`alatyr_starter` / `dev.alatyr` / `Alatyr Starter` /
`alatyr_workspace`) and instantiates itself through a deterministic
whole-token replacement across file contents and paths — its own
`dart run tool/init.dart --name … --org …` (lands in M5) — rather than
through a template-rendering engine.

## Consequences

The repository is buildable, analyzable, and testable at every point in
its life, including before instantiation — there is no separate
"template mode" where the analyzer is off or the project only resolves
after a render step. `packages/`, `lints/`, and `tool/` are
product-neutral by construction and never contain the placeholder tokens,
so instantiation touches only `app/`, native shells, the root
`pubspec.yaml`, `docs/reference/package_graph.yaml`, and `README.md` — a
scope a fixture test can assert directly by grepping for the tokens
elsewhere.

## Alternatives considered

- **Mason and `.tmpl`-style templating** — evaluated and rejected: they
  turn the repo into a non-project between renders (no working analyzer,
  unreadable on GitHub as raw `.tmpl` files, verifiable only through a
  separate render-fixture CI step). Even mason's own template product is
  itself shipped as a working app, with the brick machine-generated from
  it — the working-project shape is the thing being copied here, done
  directly instead of through an extra generation layer.
- **A setup wizard that edits files interactively** — rejected in favor
  of one deterministic, scriptable, fixture-tested command; interactive
  prompts are harder for an agent (or CI) to drive unattended.
