# ADR-0016: Brain Directory and Manifest Discovery

- **Status:** Accepted
- **Date:** 2026-10-22
- **Scope:** runner configuration and logical-brain artifact path resolution
- **Related work:** ADR-0003 and ADR-0015

## Context

The logical brain is published as one manifest plus a bounded set of shard
files. Requiring a configuration entry for every possible shard duplicates the
manifest's responsibility and makes the configuration grow with the profile.
The manifest is the source of truth for the admitted shard descriptors.

The manifest intentionally does not serialize host-specific filesystem paths.
The runner therefore needs one host path that identifies the published brain
directory, while shard filenames remain deterministic and position-independent.

## Decision

Runner configuration contains one `brain_dir` path. The runner resolves:

```text
brain_dir/manifest.brain
brain_dir/shard-000000.brain
brain_dir/shard-000001.brain
...
```

The manifest is opened first and its validated descriptors determine which
shards are present and loadable. The runner does not require `shard0` through
`shard7` configuration keys and does not create a configuration entry for an
unadmitted shard.

The logical disk profile admits up to `1,000,000` shards (`shard_id` values
`0..=999999`). Filenames use exactly six decimal digits, from
`shard-000000.brain` through `shard-999999.brain`; indexes outside that range
are rejected. `src/ie/persistence/paths.act` is the only implementation of
this formatting and path derivation. The logical path module is a namespace
facade only and must not duplicate the formatter or its constants.

The resident working set remains bounded at four cache slots. A manifest may
describe more shards than fit in memory: preflight validates the complete
manifest and referenced shard artifacts, then only the bounded resident set is
restored. Later shard access derives `brain_dir/shard-NNNNNN.brain` on demand;
the runner never stores a path array. Deterministic filename derivation does
not create files or perform filesystem I/O during inference or teaching
mutation. Publication continues to create and validate complete shard files
before publishing the manifest.

## Consequences

- A training profile has one brain directory instead of one path per shard.
- Manifest discovery is stable across machines when the directory is moved.
- Shard files remain individually addressable without serializing OS paths.
- The manifest, not runner configuration, determines the number of logical
  shard descriptors; there is no eight-shard path-table ABI.
- The four-slot resident cache is a memory bound, not a disk-shard limit.
- The runner must reject a missing manifest, malformed manifest, or missing
  referenced shard through its existing typed load failure boundary.
- Existing explicit shard-path configuration is removed from the public config
  contract rather than retained as a second source of truth.
- The production source tree contains no `Array[Path, 8]` shard-path boundary;
  test fixtures must use `brain_dir` and canonical derivation as well.

## Acceptance

- Config parsing accepts `brain_dir` and rejects the removed shard keys as
  irrelevant input rather than requiring them.
- The runner derives the manifest and bounded shard paths using the canonical
  names above.
- Empty creation, save, reload, and multi-shard training tests use only
  `brain_dir`.
- Strict checks and the complete test suite pass.
