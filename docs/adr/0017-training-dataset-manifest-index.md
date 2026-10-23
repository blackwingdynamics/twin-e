# ADR-0017: Deterministic Training Dataset Manifest Index

- **Status:** Accepted
- **Date:** 2026-10-22
- **Scope:** directory-based TWF batch discovery and runner checkpoints
- **Related work:** ADR-0013 and ADR-0016

## Context

Filesystem directory enumeration does not provide a portable ordering
contract. Sorting every discovered path in the runner would require retaining
an unbounded collection, which conflicts with Twin-e's bounded Actus runtime
model. A large training corpus also needs a resumable, auditable input order
that does not depend on the host filesystem.

## Decision

Directory training uses a dataset manifest index as its canonical input order.
The index contains one validated, normalized TWF path per record, in the exact
order in which the runner must teach the files. The index is generated from a
directory by discovering regular `.twf` files and sorting their relative names
deterministically before publication. The runner consumes the published index
sequentially and does not sort or retain the complete directory listing.

The index is bounded per batch by a named profile limit. A corpus larger than
that limit is split into multiple index batches; the limit is a memory and
validation bound, not a limit on the total corpus or the number of generations
the brain may accumulate. Every path is resolved relative to the configured
dataset directory and must remain a regular `.twf` file at consumption time.

Directory-mode training publishes a checkpoint after every successfully
trained file. The checkpoint is mandatory in this mode, independent of the
final-save option used by single-file and stdin modes. Before the next file,
the runner restores the published generation so the next transaction starts
from the durable state. A failed file, failed checkpoint, missing entry, or
malformed TWF stops the batch and leaves the last successful checkpoint active.

## Consequences

- Training order is reproducible across hosts and filesystem implementations.
- Very large corpora are processed as bounded, resumable index batches.
- A runner crash loses at most the file currently being processed.
- The dataset index becomes an auditable input artifact and must be validated
  before teaching starts.
- Directory enumeration remains useful for index generation, but it is not the
  runtime source of training order.

## Acceptance

- An index with one, multiple, unordered, empty, malformed, and missing-entry
  cases has typed validation outcomes.
- Directory-mode training checkpoints after each accepted file and reloads the
  published generation before the next file.
- Batch metrics report file count, record count, accepted count, and final
  generation.
- The runner never uses an unbounded path collection or filesystem ordering as
  its teaching order.
