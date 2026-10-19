# Phase 9 — Bounded Auxiliary Fan-out

- **Status:** In progress
- **Branch:** `phase-9-bounded-fanout`
- **Scope:** Extend successor capacity without changing the 64-byte
  `Minicolumn` layout or the meaning of `Array[u32, 8]`.
- **Related ADR:** [ADR-0014](../adr/0014-bounded-fanout-sidecar.md)

## Objective

Give a source column a bounded overflow path for additional successors while
preserving the existing eight-axon inline hot path, deterministic traversal,
position-independent persistence, and fixed-memory behavior.

This phase does not change token identity, introduce HDC semantics, enlarge
the coincidence vector, or claim semantic generalization. It addresses only
bounded successor capacity.

## Progress

### Step 1 — Architectural boundary

- [x] Draft ADR-0014 for the auxiliary sidecar boundary.
- [x] Preserve `Minicolumn` at exactly 64 bytes.
- [x] Preserve the meaning and offsets of `axons: Array[u32, 8]`.
- [x] Record marker/directory alternatives and unresolved design questions.

### Step 2 — Regression-test skeleton

- [x] Add a baseline test for the eight inline axon contract.
- [x] Verify the baseline with strict checking and the full test suite.
- [x] Record the 100-test baseline before runtime changes.

### Step 3 — Select the overflow addressing boundary

- [x] Choose the reserved-state marker and bounded external directory.
- [x] Define the auxiliary record layout and ownership roles.
- [x] Define the initial total fan-out: eight inline plus eight auxiliary.
- [x] Define deterministic inline-then-auxiliary traversal.
- [x] Update ADR-0014 from Proposed to Accepted.

The accepted first implementation uses `FLAG_HAS_AUX = 0x80`, a compact
`u16` `aux_map` table ID with `0xFFFF` as the empty sentinel, and one fixed
auxiliary record per overflow source. Auxiliary free-list links remain `u32`.
Chaining and fan-out above sixteen are deferred.

### Step 4 — Implement bounded auxiliary storage

- [x] Add fixed-size `AuxAxonTable` storage and bounded allocation.
- [x] Keep eight-successor forwarding on the existing inline path.
- [x] Add overflow insertion and typed capacity rejection.
- [x] Preserve free-list and reclamation invariants.

The bounded implementation keeps `CorticalFabric` and the eight inline axons
unchanged. `AuxAxonTable` owns eight fixed records, a compact `u16` source map,
and a `u32` free-list. Auxiliary forwarding is explicitly gated by
`FLAG_HAS_AUX`; capacity and duplicate failures return typed errors without
publishing partial links, and paired release clears the marker before record
reuse.

### Step 5 — Add behavioral evidence

- [x] Reach every successor for a source above eight and within the bound.
- [x] Reject auxiliary exhaustion without partial mutation.
- [x] Reuse reclaimed auxiliary records safely.
- [x] Preserve existing eight-axon behavior byte-for-byte.

The inline compatibility test runs the legacy eight-slot step and the
sidecar-aware step against identical fixtures. Their fixed result fields match,
the sidecar count remains zero, and no auxiliary marker or record is created.

### Step 6 — Persistence and recovery

- [ ] Serialize auxiliary descriptors and records position-independently.
- [ ] Validate bounds, indexes, counts, and checksums before publication.
- [ ] Reject truncated or corrupted auxiliary state without live mutation.
- [ ] Prove snapshot round-trip and recovery after reclamation.

### Step 7 — Performance and acceptance

- [ ] Benchmark inline-only forwarding separately from overflow forwarding.
- [ ] Record memory usage, capacity, traversal order, and failure metrics.
- [ ] Run formatter, lock, strict check, strict tests, and native build.
- [ ] Verify generated native IR remains free of floating-point instructions.
- [ ] Update ADR-0014 and close the phase only after all gates are green.

## Current evidence

The strict suite passes with `104 passed; 0 failed`. The fan-out tests verify
the unchanged eight-slot inline contract, reach one auxiliary successor
through the gated forwarding path, reject the ninth auxiliary record without
mutating the table, and reclaim a record while clearing `FLAG_HAS_AUX`. The
native and persistence gates remain open for the next steps.

## Out of scope

- HDC, 1024-bit SDR, or semantic vector generalization;
- removal or weakening of `TokenBinding` identity checks;
- hierarchical cortical layers;
- endocrine or neuromodulatory policy;
- network transports or external teacher integrations.
