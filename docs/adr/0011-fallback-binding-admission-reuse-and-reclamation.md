# ADR-0011: Bounded Admission, Reuse, and Reclamation of Fallback Bindings

- **Status:** Accepted
- **Date:** 2026-10-19
- **Scope:** byte-fallback token events, context bindings, bounded training,
  decay, and future tokenizer changes
- **Related work:** ADR-0001, ADR-0002, ADR-0004, ADR-0006, Phase 5.8

## Context

The byte fallback is intentionally a bounded representation: every input byte
remains one token event, including malformed UTF-8. Training attaches the
current token and its bounded preceding-token context to a fixed minicolumn
and stores the identity in the fixed binding sidecar. A fallback-heavy input
can therefore exercise both limits independently:

- the tokenizer limits the number of emitted events to
  `TOKENIZER_MAX_BYTES`;
- the engine limits resident minicolumns and active token bindings to their
  fixed capacities.

The repeated-fallback benchmark and regression test show that equivalent
fallback contexts are reused instead of creating a new binding for every
event. The system still needs an explicit policy before tokenizer behavior or
fallback identity is extended. In particular, generic column reclamation must
not leave a stale binding that can be counted, selected, or serialized as if
its column were still active.

## Decision

Fallback-derived bindings follow four bounded rules.

### 1. Admission

1. The tokenizer emits one bounded byte token per input byte under the
   existing fallback contract. It does not allocate a new vocabulary entry,
   aggregate bytes, or perform filesystem I/O.
2. `validate_training_sequence` is the first training admission boundary. An
   empty, invalid, or over-capacity sequence is rejected before fabric or
   binding mutation.
3. After sequence admission, each new fallback context must pass both fixed
   resident limits: a free minicolumn and a free binding slot. Failure returns
   the existing typed bounded training error; it does not evict arbitrary
   state, retry through filesystem work, or partially publish a binding.
4. Fallback input does not receive a separate unbounded allocation pool. Its
   capacity is the same bounded arena and sidecar capacity used by other
   token identities.

### 2. Reuse

1. Before admission of a new column, training performs an exact lookup of
   `(token_id, context_key, tokenizer_version, context_version)`.
2. An active exact match reuses its existing arena slot and reinforces the
   observed transition. It does not increment active binding count or allocate
   another minicolumn.
3. A different byte, ordered context, or compatibility version is a distinct
   identity and may consume one additional bounded slot.
4. Reuse is deterministic and remains valid after snapshot restore when the
   same compatibility metadata is accepted.

### 3. Reclamation

1. Fallback identity is not reclaimed by the tokenizer and is not removed
   merely because an input sequence ended. Reclamation belongs to the engine's
   existing homeostatic policy.
2. A binding may be reclaimed only when its owning minicolumn is eligible for
   the configured decay policy and the column and binding are cleared as one
   bounded operation. The operation must remove outgoing links according to
   the existing arena rules, clear the binding's active flag and metadata, and
   return the slot to the free list.
3. A failed or partial cleanup must not expose a free column with an active
   binding, or an active column with a stale binding. Until the paired cleanup
   operation is implemented and tested, fallback-specific binding reclamation
   is not considered enabled.
4. Reclaimed slots may later be admitted for a different fallback context, but
   only after the paired cleanup has completed. No generation counter or
   hidden tombstone storage is introduced by this policy.

### 4. Exhaustion and persistence boundary

When no admissible slot exists, training returns a typed capacity failure and
leaves the already resident state usable. Fallback pressure does not trigger
synchronous save, load, flush, rename, or checksum work. Persistence remains
behind the explicit boundaries defined by ADR-0004 and ADR-0006.

## Required evidence before implementation changes

The accepted policy requires the following evidence before changing fallback
or tokenizer behavior:

- repeated equivalent fallback contexts reuse one binding identity;
- a full binding/arena limit returns a typed error without partial mutation;
- paired decay clears both the minicolumn and its binding;
- a reclaimed slot can be reused for a new context without stale identity;
- snapshot save/load preserves active fallback bindings and rejects invalid
  or oversized state before live-state mutation.

The current repository provides the first item through the training-accounting
benchmark and `tests/aie_fallback_reuse.act`. The paired cleanup, exhaustion,
and fallback persistence checks remain open roadmap work. This ADR closes the
policy-definition gate only; it does not claim those implementation gates are
complete.

## Consequences

### Positive consequences

- fallback input has the same explicit bounded resource contract as other
  token identities;
- repeated data cannot create duplicate bindings when identity is equivalent;
- stale sidecar records cannot be accepted as a valid reclamation result;
- capacity pressure has an observable in-memory failure path with no hidden
  filesystem latency.

### Costs

- decay must eventually use a paired column-and-binding cleanup operation;
- fallback-heavy exhaustion and persistence require additional evidence before
  tokenizer behavior is expanded;
- no automatic fallback-specific eviction policy is available yet.

### Phase 5.8 acceptance update

The integrated fallback persistence fixture records stable artifact size across
repeated training (`growth_bytes=0`), rejects an oversized artifact before
mutation (`oversized_rejected=1`, `unchanged=1`), and preserves resident state
after a failed save (`failed_save_unchanged=1`). These results close the
current host-profile persistence evidence without claiming unbounded fallback
storage or automatic reclamation.

## Rejected alternatives

- allocating a new binding for every fallback event;
- silently replacing the oldest or weakest binding at capacity;
- clearing only the minicolumn while leaving its sidecar active;
- persisting synchronously to make room during training;
- widening or aggregating fallback tokens before identity and round-trip tests
  exist.
