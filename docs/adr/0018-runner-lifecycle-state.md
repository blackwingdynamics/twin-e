# ADR-0018 — Production runner lifecycle state

## Status

Accepted

## Context

The production runner distinguishes resident learning from explicit persistence.
The IE persistence implementation already stages and validates shard artifacts,
but the runner boundary previously had no typed lifecycle contract describing
those states.

## Decision

The runner exposes the following bounded lifecycle states:

```text
Loaded -> ResidentDirty -> SaveRequested -> Published
                                      \-> SaveFailed
```

`Published` and `SaveFailed` may transition back to `ResidentDirty` or
`SaveRequested` for a subsequent operation. Invalid transitions are rejected
without mutating the lifecycle record. The lifecycle module performs no
filesystem I/O and does not own IE state; callers update it only after the
corresponding load, teaching, save, or publication boundary returns.

## Consequences

- Public runner results can distinguish resident acceptance from publication.
- Save failures can be retried without claiming that persistence succeeded.
- The state model is independent of the `.brain` binary format and shard cache.
- Future wire and batching layers can carry lifecycle outcomes without reaching
  into IE internals.

## Evidence

`tests/runner_lifecycle.act` covers the successful load/teach/save/publish path,
save failure and retry, and rejection without state mutation. The strict suite
passes with 191 tests.
