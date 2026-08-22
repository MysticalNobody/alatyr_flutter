---
name: adversarial-tests
description: Adversarial test pass (Definition of Done item 2) - dispatch the fresh-context test-breaker subagent over a feature's *_api contract and implementation, then cover every scenario with a test or a deliberate skip stub. Use after the first green implementation of new behaviour, or when asked to "break this", "adversarial pass", "test-breaker".
argument-hint: "<feature_api dir> [feature impl dir]"
---

# Adversarial tests

Self-confirmation is the failure mode this skill exists for: the agent that
wrote the code is the worst judge of what breaks it. The scenarios come
from a subagent that has not seen your reasoning.

## 1. Break it

Dispatch the `test-breaker` subagent (Agent tool, `subagent_type:
test-breaker`) with: the `*_api` directory (`$0`), the implementation
directory (`$1`, if given), the feature's spec/plan excerpt if you have
one, and the diff range. Do not pass your own analysis or assumptions -
only the artefacts. Wait for its scenario list.

## 2. Cover it

For every scenario:
- **NOT COVERED and implementable** → write the test at the named layer
  (patrol finders for widgets; in-memory drift for repositories; bloc_test
  for blocs). The test name is the scenario. Run it: it must fail before
  the fix if the scenario exposed a bug, and pass after.
- **NOT COVERED and deliberately out of scope** (OS-level process death,
  hardware, a platform channel you cannot fake) → add a stub in the right
  test file so the gap is machine-visible:
  `test('<scenario>', () {}, skip: 'deliberate: <why>');`
- **covered** → nothing, but verify the cited test really asserts the
  behaviour; if it only exercises the path, strengthen it.
- **contract gap** (a promise with neither code nor test) → fix the code or
  the contract doc comment; never leave the promise dangling.

## 3. Report

```
Adversarial pass (<api package>): <N> scenarios - <a> already covered,
<b> tests added, <c> deliberate skips, <d> contract gaps fixed.
Deliberate skips: <list with reasons>
Remaining risks: <anything you could not cover or verify, or "none">
```
The skipped stubs ARE the record of known-uncovered scenarios
(`flutter test --reporter json` enumerates them); do not keep a separate
list.
