# ADR-0014: Bounded Auxiliary Fan-out Sidecar

- **Status:** Accepted; Phase 9 complete
- **Date:** 2026-10-19
- **Scope:** Extending successor fan-out without changing `Minicolumn.axons`
- **Related work:** ADR-0002, ADR-0007, ADR-0009, ADR-0013, Phase 5.8,
  Phase 8

## Context

Each `Minicolumn` currently stores exactly eight `u32` axon targets inside the
established 64-byte packed representation. This inline representation is part
of the runtime, snapshot, free-list, and benchmark contracts. Some learned
contexts may eventually require more than eight deterministic successors, but
an overflow mechanism must not turn ordinary eight-axon forwarding into a
dynamic or filesystem-backed operation.

The auxiliary representation is a sidecar concern. It must not reinterpret,
resize, or replace `Minicolumn.axons: Array[u32, 8]`. Existing inline links
remain the common hot path and retain their current meaning and layout.

## Decision

The first implementation uses a fixed-capacity `AuxAxonArena` and a compact
`aux_map` indexed by source column ID. `aux_map` stores a bounded `u16` table
ID, not a raw arena link; `0xFFFF` means that no auxiliary record is attached.
The auxiliary free-list and all arena links remain `u32` indexes to preserve
the repository-wide link contract.

Each overflow source receives at most one auxiliary record in this phase. The
record stores eight additional `u32` targets, a used count, reserved bytes for
stable packing, and a `u32` free-list link. Chaining and fan-out above sixteen
total successors are explicitly deferred to a later gate.

`FLAG_HAS_AUX = 0x80` is the reserved-state marker. Inline forwarding keeps
the existing eight-slot loop. Only a source marked with `FLAG_HAS_AUX` consults
`aux_map` and the auxiliary arena. The branch is bounded overhead, not a
zero-time guarantee; inline-only and overflow paths must be benchmarked
separately.

The `Minicolumn.axons` array remains semantically unchanged in both options.
The initial maximum total fan-out is sixteen successors per source: eight
inline plus eight auxiliary. This is a phase-local bounded policy and becomes
a shared protocol constant only after implementation evidence.

Persistence is a shard-local section, not a global file. Every `.brain` shard
is one independent unit with this order: `Header`, `Columns`, `Bindings`, and
`Auxiliary`. The auxiliary section uses the fixed-width snapshot contract
already covered by the runtime tests: a `u16` source directory, fixed records,
and `u32` free-list/active-count metadata. Its byte length and checksum are
recorded in the shard generation metadata, and the complete shard checksum
covers all sections together. A staged shard is validated completely before
rename; the manifest is published only after the complete shard generation is
available. There is no global `auxiliary.brain` and no one-to-one auxiliary
file beside each shard.

The dynamic manifest descriptor is widened from 40 to 48 bytes. Its ordered
fields are `shard_id`, `first_column_index`, `column_count`, `payload_offset`,
`payload_bytes`, `binding_offset`, `binding_bytes`, `auxiliary_offset`,
`auxiliary_bytes`, `checksum`, and `state`. The auxiliary offset is derived as
the end of the bindings section and is recorded explicitly so publication
validation can reject a mismatched section layout before activation. The
descriptor-size change is a format change: writers, readers, validators, and
fixed-manifest compatibility fixtures must move together.

## Invariants

- `Minicolumn` remains exactly 64 bytes and its eight inline axon offsets do
  not move.
- Existing eight-axon training, forwarding, selection, decay, and snapshot
  behavior remains unchanged.
- Auxiliary records are fixed-size, bounded, position-independent, and owned
  by an explicit `u32` free-list.
- Auxiliary capacity failure is typed and leaves live fabric state unchanged.
- Reclamation clears both inline and auxiliary links before returning storage.
- Snapshot publication validates auxiliary descriptors, bounds, indexes, and
  checksums before mutating live state.
- Each shard owns only its local auxiliary records; auxiliary data never
  crosses shard-file boundaries.
- A shard with no auxiliary records remains valid with an empty auxiliary
  section; auxiliary capacity is bounded per shard.
- Forwarding order is deterministic: inline successors first, then auxiliary
  successors in stored order.
- No synchronous filesystem or network I/O is introduced into forwarding,
  inference, training, or reclamation.

## Required evidence before implementation is accepted

- A source with exactly eight successors behaves identically to the current
  implementation.
- A source with more than eight and within the selected bound reaches every
  valid successor in deterministic order.
- Auxiliary arena exhaustion rejects the new link without partial mutation.
- Free-list reclamation permits safe bounded reuse.
- Snapshot round-trip preserves auxiliary links and corrupted or truncated
  auxiliary data is rejected without partial restore.
- Native benchmark output separates inline-only forwarding from overflow
  forwarding and records the additional work.
- Complete shard publication precedes manifest publication, and an invalid
  manifest cannot become active after a complete shard is published.
- Restart recovery selects the last complete manifest generation when the
  primary generation is corrupted, including its shard-local Auxiliary
  descriptor.

## Rejected shortcuts

- Reinterpreting the eighth inline slot as a pointer or changing its meaning.
- Resizing `Minicolumn`, changing its serialized offsets, or replacing the
  fixed array with a dynamic collection.
- Introducing an unbounded linked list or hidden allocation in the hot path.
- Removing `TokenBinding` or changing token identity as part of fan-out work.
- Claiming that auxiliary fan-out provides semantic generalization; it only
  expands bounded successor capacity.

## Deferred work

Chaining, more than one auxiliary record per source, fan-out above sixteen,
and any alternative compact index width require a new design review. The
selected manifest descriptor encoding, round-trip, corruption-rejection,
publication-order, and restart-recovery evidence are complete in Phase 9.
Future changes to chaining, fan-out above sixteen, or compact index width
require a new design review.
