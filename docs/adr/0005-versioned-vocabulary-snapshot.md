# ADR-0005: Versioned Vocabulary in the `.brain` Snapshot

- **Status:** Accepted
- **Date:** 2026-10-05
- **Scope:** tokenizer vocabulary persistence and restart compatibility
- **Related work:** ADR-0001, ADR-0002, ADR-0004, Phase 5 P5.1 and P5.2

## Context

The current combined `.brain` file stores the fixed fabric and token/context
bindings. Its header records tokenizer, context, and codebook versions, but it
does not store the vocabulary records or ranked merge rules that give token IDs
their meaning. A process can therefore restore arena state while lacking the
exact tokenizer artifact that produced that state.

## Decision

The versioned text snapshot gains a bounded vocabulary section containing the
complete `BpeVocabulary` artifact:

- vocabulary magic and format version;
- tokenizer compatibility version;
- BOS, EOS, and unknown token IDs;
- the bounded ranked merge-rule table;
- the bounded token record table with inline byte payloads.

The section is fixed-size and position-independent. Its limits are the
existing configured BPE limits; no dynamic collection or pointer is serialized.
The snapshot checksum covers the vocabulary section together with the fabric
and binding sections.

The existing fabric-and-binding API remains available for compatibility. A new
vocabulary-aware API accepts a validated `BpeVocabulary` for save and restore.
Loading validates the complete vocabulary section before mutating fabric,
bindings, or the caller's active vocabulary state. Invalid magic, versions,
counts, token widths, merge ranks, or checksum reject the file unchanged.

The context version, codebook version, and active-bit profile remain explicit
compatibility metadata. This ADR records persistence of the artifact; bounded
multi-merge quality and corpus token-count measurements remain P5.2 work.

## Consequences

- Restart can reproduce token IDs and merge behavior from the same snapshot.
- The `.brain` file grows by a fixed vocabulary section even when only a small
  vocabulary prefix is active.
- The artifact remains deterministic and inspectable, at the cost of copying
  fixed tables during save and load.
- Existing snapshots without this section remain readable only through the
  legacy fabric-and-binding API; the vocabulary-aware loader rejects them as
  incompatible.

## Acceptance evidence

The implementation must provide strict tests for vocabulary round-trip,
incompatible vocabulary rejection, unchanged live state after failed load,
and process restart encode/decode identity. The benchmark must report the
header, fabric, binding, vocabulary, and total byte sizes.
