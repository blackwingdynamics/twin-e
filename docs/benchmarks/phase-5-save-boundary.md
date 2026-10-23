# Phase 5 Save Boundary Evidence

## Scope

This record covers the first implementation pass for the caller-driven shard
save boundary. The save path keeps resident state in memory, writes a staged
`.brain` generation, validates the staged bytes, publishes the generation, and
only then reports the save as successful.

The benchmark is intentionally separate from inference and impulse forwarding.
It is allowed to perform filesystem I/O because it exercises the explicit save
boundary.

## Current implementation

- `src/ie/persistence/shard/save.act` owns the dirty-slot save request and
  changes the cache lifecycle to `Persisted` only after the flush returns
  successfully.
- `src/ie/persistence/shard/flush.act` writes the staged generation, reads it
  back, validates the header, payload, local bindings, and metadata, and then
  publishes it through rename.
- `benchmarks/ie_shard_bindings_dynamic.act` reports typed stage labels for
  path probing, writing, staged reads, validation, and cleanup failures.
- `docs/roadmap/phase-5.md` tracks the save boundary as ordered acceptance
  gates. The gates remain open until failure fixtures and recovery evidence are
  complete.

## Reproduction command

From the Twin-e repository root:

```sh
actus fmt --check benchmarks/ie_shard_bindings_dynamic.act
actus build --strict --emit exe \
  -o /tmp/twin-e-shard-bindings-save.ie \
  benchmarks/ie_shard_bindings_dynamic.act
rm -f /tmp/twin-e-binding-shard.brain /tmp/twin-e-stage.brain
/tmp/twin-e-shard-bindings-save.ie
```

## Observed success evidence

The current run produced:

```text
benchmarks/ie_shard_bindings_dynamic.act is formatted
built `/tmp/twin-e-shard-bindings-save.ie` (strict)
verified generated native IR: no floating-point instructions
IE_BINDING_STAGE start
IE_BINDING_STAGE staged_read_failed error=IoError.Failed status=11
IE_BINDING_STAGE write_failed error=IoError.Failed status=11
IE_BINDING_STAGE rename_failed error=IoError.Failed status=11
IE_BINDING_STAGE previous_generation_preserved
IE_BINDING_STAGE dirty_after_failed_save
IE_BINDING_STAGE resident_usable_after_failed_save
IE_BINDING_STAGE validation_rejected error=IoError.InvalidData status=13
IE_BINDING_STAGE persisted_after_successful_save
IE_BINDING_STAGE write_ok
IE_BINDING_STAGE validate_ok
IE_BINDING_STAGE publication_ok
IE_BINDING_STAGE payload_bindings_checksum_metadata_ok
IE_BINDING_STAGE capacity_recovered_after_flush
IE_SHARD_BINDINGS_DYNAMIC columns=2 bindings=2 stride=24 validated=1
exit_status=0
```

The four failure markers are deterministic fixtures. The read fixture removes
the staged file before reading it; the write fixture turns the staged path into
a directory; the rename fixture makes the active path a directory; and the
validation fixture writes one invalid byte. Their typed results are preserved as
`IoError.Failed` or `IoError.InvalidData` with status codes 11 and 13. The
active file was then created at `/tmp/twin-e-binding-shard.brain`, and the staged
file was consumed by publication. The final markers prove the successful write,
validation, and publication path for one two-column shard with two local
bindings. `publication_ok` is emitted after the published active file is read
and validated. `payload_bindings_checksum_metadata_ok` is emitted only after the
validator has checked the expected payload section, shard-local binding section,
compatibility metadata, total length, and checksum. The lifecycle markers prove
that the public save API leaves a failed resident save dirty and usable for a
subsequent cache lookup/touch, and changes the same entry to persisted only
after successful publication.

After a successful flush changes the entry to `Persisted`, the capacity
fixture admits a fifth shard into the four-entry cache by evicting that clean
resident entry. This is reported as `capacity_recovered_after_flush`.

## Remaining evidence after Gate D

Gates A through D are closed by the benchmark output above. The previous active
generation and failed-publication recovery are recorded by the
`previous_generation_preserved` marker.

ADR-0006 defines the committed flush order: write and validate shard payload
and shard-local bindings, publish the shard generation, then publish compatible
manifest metadata and mark the resident entry persisted. The dynamic shard
recovery benchmark confirms that incomplete generations are rejected and the
newest complete manifest generation is selected after restart.

## Gate E executable evidence

The save-boundary executable was built and run with:

```sh
rm -rf /tmp/twin-e-binding-shard.brain /tmp/twin-e-stage.brain
actus build --strict --emit exe \
  -o /tmp/twin-e-shard-bindings-save.ie \
  benchmarks/ie_shard_bindings_dynamic.act
/tmp/twin-e-shard-bindings-save.ie
stat -c 'active=%n bytes=%s' /tmp/twin-e-binding-shard.brain
test ! -e /tmp/twin-e-stage.brain && echo staged_state=consumed
```

Observed result:

```text
verified generated native IR: no floating-point instructions
save_exit_status=0
active=/tmp/twin-e-binding-shard.brain bytes=104
staged_state=consumed
```

The separate recovery executable was built from
`benchmarks/ie_shards_dynamic.act`. It returned exit status 0 and reported
`manifest_selected=1`, `dynamic_loaded=1`, `dynamic_failed_unchanged=1`, and
`reallocated=2`. Its four complete shard files were 176, 176, 176, and 184
bytes. This is the restart and incomplete-generation recovery evidence used by
Gate E.

The full repository checks passed after the Gate E changes:

```text
actus lock --check       PASS
actus check --strict     PASS
actus test --strict      18 passed; 0 failed
```

Gates A through E are now closed. The remaining P5.1A work concerns broader
hot-path benchmarking, background flush policy, capacity configuration, and
negative filesystem-write instrumentation; those are separate from the
caller-driven save API acceptance gate.

## Regression baseline

The current repository baseline remains:

```text
actus lock --check       PASS
actus check --strict     PASS
actus test --strict      18 passed; 0 failed
actus build --strict     PASS; no floating-point instructions
```

These results do not close the save-boundary gates by themselves. The failure
and recovery fixtures above are part of the acceptance contract.

## Storage accounting evidence

The dedicated `benchmarks/ie_storage_accounting.act` fixture reports the
same two-column, two-binding layout separately:

```sh
actus fmt --check benchmarks/ie_storage_accounting.act
actus build --strict --emit exe \
  -o /tmp/twin-e-storage-accounting.ie \
  benchmarks/ie_storage_accounting.act
/tmp/twin-e-storage-accounting.ie
```

The measured run used Actus binary digest
`e6293f8075d7982b95c1ec8b54eb18d97d1c2ec98f5cf9a8c70120522e38feda`.

```text
IE_STORAGE_ACCOUNTING column_payload_bytes=128
 column_storage_bytes=128
 binding_metadata_bytes=48
 shard_header_bytes=48
 shard_file_bytes=224
 manifest_header_bytes=64
 manifest_descriptor_bytes=40
 manifest_bytes_for_one_shard=104
 alignment_bytes=0
```

The payload is two 64-byte minicolumn records. The shard-local binding section
is two 24-byte records, and the fixed 48-byte header is not counted as payload.
A one-shard dynamic manifest is its 64-byte header plus one 40-byte descriptor.
The fixture uses no alignment padding; any future padded format must report the
padding separately rather than hiding it in payload or metadata bytes.
