# Phase 5.8 Generation Recovery Evidence

This record proves that recovery does not silently select an older generation
when a newer complete manifest is available, and does not accept a shard under
the wrong manifest descriptor.

## Environment

- Compiler: `/home/magradze/Projects/actus_project/actus/target/debug/actus`
- Compiler digest:
  `322711227604bc52452f2ad015748f17df7facee1a9233c114a2bc4bdc6817bb`
- Profile: strict native executable
- Floating point: native IR verification reported no floating-point
  instructions

## Generation selection

```sh
actus build --strict --emit exe -o /tmp/twin-e-manifest-dynamic.aie \
  benchmarks/aie_manifest_dynamic.act
/tmp/twin-e-manifest-dynamic.aie
```

Captured result:

```text
AIE_MANIFEST_DYNAMIC shards=3 appended_shard=3 allocation_shard=3 local_index=0 allocator_head=5 allocator_shard=0 allocator_local=5 roundtrip=1 generation_publish=1 newest_generation=10 stale_rejected=1
```

The fixture writes a complete fallback at generation `8`, publishes generation
`10`, rejects an invalid staged replacement, and confirms that recovery still
selects the complete generation `10`.

## Descriptor binding

```sh
actus build --strict --emit exe -o /tmp/twin-e-shards-dynamic.aie \
  benchmarks/aie_shards_dynamic.act
/tmp/twin-e-shards-dynamic.aie
```

Captured result:

```text
AIE_SHARDS_DYNAMIC files=3 generated=1 staged_shard=1 validated=3 partial_rejected=1 truncated_rejected=1 active_unchanged=1 manifest_bound=2 swapped_rejected=1 dynamic_loaded=1 dynamic_collection=3 manifest_selected=1 dynamic_failed_unchanged=1 free_chain=5-2-0-null reallocated=2 payload_bytes=128
```

`swapped_rejected=1` proves that a valid shard under a different descriptor
cannot be accepted as the selected manifest shard.
