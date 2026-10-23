# Phase 11 capacity-profile evidence

## Host profile

The Gate 11.1 production profile is bounded and canonical in
`src/config/values.act`:

- maximum logical shards: `8`;
- columns per shard: `1024`;
- resident working-set capacity: `4` shards;
- bindings per shard: `1024`;
- auxiliary records per shard: `8`;
- request items: `8`;
- manifest descriptors: `8`.

The profile validator rejects zero bounds, non-power-of-two shard capacity,
shift/mask mismatches, arithmetic overflow, and inconsistent bound sets before
logical-brain initialization mutates resident state.

## Complete artifact measurement

Command:

```sh
actus build --strict --emit exe \
  -o /tmp/twin-e-gate11-1-profile-benchmark.ie \
  benchmarks/ie_logical_profile.act
/tmp/twin-e-gate11-1-profile-benchmark.ie
```

Observed on the Arch Linux host on 2026-10-21:

```text
IE_PROFILE max_logical_shards=8
 max_columns_per_shard=1024
 max_resident_shards=4
 max_bindings_per_shard=1024
 max_auxiliary_records=8
 max_request_items=8
 max_manifest_descriptors=8

IE_PROFILE shard_bytes=90616
 manifest_bytes=112
 complete_bytes=90728
 header_bytes=48
 columns_bytes=65536
 bindings_bytes=24576
 auxiliary_bytes=456
 checksum_bytes=8
 peak_resident_payload_bytes=362272
 logical_columns=1024 shard_count=1 binding_records=1024 auxiliary_records=8
 routing_profile=shift_mask power_of_two=1
```

The shard measurement includes its header, 1024 column payload, shard-local
bindings, auxiliary section, and checksum. The complete figure also includes
the manifest descriptor and metadata. `peak_resident_payload_bytes` is the
four-shard resident payload envelope (`4 * (columns + bindings + auxiliary)`);
it excludes language-runtime object and alignment overhead.

## Routing comparison

Command:

```sh
actus build --strict --emit exe \
  -o /tmp/twin-e-gate11-1-routing-benchmark.ie \
  benchmarks/ie_logical_routing.act
/tmp/twin-e-gate11-1-routing-benchmark.ie
```

Observed for one million equivalent routes in one run:

```text
IE_PROFILE routing_shift_mask_ns=549632
 reference_arithmetic_ns=2298248
1
```

The final `1` confirms equal routing results. These timings are target- and
run-dependent measurements; they are not a fixed cycle-count claim.

## Validation

```text
actus lock --check                         PASS
actus check --strict                       PASS
actus test --strict                       144 passed; 0 failed
strict profile benchmark build            PASS; no floating-point instructions
strict routing benchmark build            PASS; no floating-point instructions
```
