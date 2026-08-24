# Pluggable modules

Nothing is vendored into this template beyond what ships today. Every
module below churns faster than a template can track — beads swapped
storage backends within a year of its release, spec-kit ships near-daily —
so this page carries install one-liners and scope guidance instead of a
dependency.

## superpowers — recommended, per-user, zero repo footprint

```bash
/plugin install superpowers@claude-plugins-official
```

(Claude Code) plus the documented Codex bootstrap for the same skill set
on the Codex side. Provides brainstorming/TDD/debugging/review discipline
that composes with this template's harness rather than replacing it —
nothing here assumes it is installed.

Superpowers work products may live locally under `docs/superpowers/`. That
directory is gitignored and is neither shipped nor a source of truth. Promote
every accepted decision into the relevant architecture, ADR, testing,
workflow, or reference document before relying on it; the local plan may then
change or disappear without losing the decision.

## spec-kit — optional, per-feature spec ceremony

For a real product that wants formal per-feature spec ceremony beyond this
template's graph-first ritual:

```bash
uv tool install specify-cli
specify init . --integration claude
specify integration install codex
```

The "constitution" concept spec-kit introduces is already implemented
natively here by `AGENTS.md` — installing spec-kit does not require a
separate constitution file.

## beads — optional, long-horizon multi-session work

```bash
brew install beads && bd init && bd setup claude && bd setup codex
```

Useful when work spans more sessions than a single completion report can
track; not needed for the single-session graph-first ritual this template
ships by default.

## marionette — optional, runtime UI verification

Lets an agent drive the running debug app directly (tap, read widget
state, screenshot) rather than only through tests. The core template ships
only the prerequisite: the `ValueKey` namespace convention (hard invariant
7) that patrol finders already use, so the module plugs in without any
code change once you add it — wiring `marionette_flutter` into the debug
build plus a verify-flow skill.

## Nothing vendored, and why

Each of these composes with the harness rather than being required by it.
Vendoring any of them would mean tracking its churn as part of this
template's own maintenance surface (see `docs/workflow/maintenance.md` for
what is already tracked); per-user or per-project opt-in keeps that
surface at the version each consuming project actually wants, not the
version this template happened to pin last.
