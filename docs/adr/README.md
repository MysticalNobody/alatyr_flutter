# Architecture Decision Records

An ADR here is a short, numbered record of a decision that shapes the
template's architecture or process — the kind of choice that is expensive
to re-litigate from scratch every time someone asks "why not X instead?".
Every ADR follows [`template.md`](template.md): Status, Date, Context,
Decision, Consequences, Alternatives considered.

## Numbering and status

ADRs are numbered sequentially, zero-padded to four digits
(`0001`, `0002`, …), and never renumbered or deleted. `Status` is one of
`draft`, `accepted`, or `superseded by ADR-NNNN`. A superseded ADR keeps
its file and its number — the supersession is recorded in its own
`Status` line and, at the doc's top, per the banner convention in
[`../README.md`](../README.md).

## The ADR-draft escalation flow

`AGENTS.md`'s stop conditions (§7) say: when an agent hits ambiguity it
cannot resolve by reading the graph, the docs, or asking, and the
ambiguity is architectural rather than a one-off judgment call, it writes
`docs/adr/NNNN-<slug>.md` from `template.md` with `Status: draft` — and
stops there. It does not guess an answer and implement against it. A human
reviews the draft, accepts or rejects it (updating `Status` accordingly),
and only then does implementation code land against that decision. No code
is written against a draft ADR.

## Index

| ADR | Title |
|---|---|
| [0001](0001-package-boundaries.md) | Package boundaries |
| [0002](0002-manual-di.md) | Manual dependency injection |
| [0003](0003-test-strategy.md) | Test strategy |
| [0004](0004-single-gate.md) | Single gate |
| [0005](0005-cross-review-protocol.md) | Cross-review protocol |
| [0006](0006-working-placeholder-instantiation.md) | Working-placeholder instantiation |
