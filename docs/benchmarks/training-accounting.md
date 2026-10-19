# Training accounting for BPE and byte fallback

This fixture trains five equal-length 32-byte inputs in separate fresh
64-column fabrics and 64-slot binding tables. It reports tokenizer events,
active `(token_id, context_key)` bindings, allocated minicolumns, and the
fixed resident/snapshot layout. `active_shards=0` is intentional: this is an
in-memory training measurement and does not open a shard or perform disk I/O.

The resident inline figure is `64 * 64 + 64 * 24 + 8 = 5640` bytes: columns,
binding slots, and the two fabric counters. The `.brain` figure is the fixed
serialized text-brain size of `5702` bytes and is not multiplied by emitted
events. Payload and metadata are therefore reported separately from the
future shard header, manifest, and alignment accounting, which remain open.

Command:

```sh
actus fmt --check benchmarks/aie_training_accounting.act
actus build --strict --emit exe -o /tmp/twin-e-training-accounting.aie benchmarks/aie_training_accounting.act
/tmp/twin-e-training-accounting.aie
```

Conditions: strict native executable, Cranelift backend, integer-only engine,
32 input bytes, 64 minicolumns, 64 binding slots, and the release Actus
compiler binary digest: `e6293f8075d7982b95c1ec8b54eb18d97d1c2ec98f5cf9a8c70120522e38feda`.

Captured output is recorded below after the fixture is built and executed.

```text
AIE_TRAINING_ACCOUNTING input_bytes=32 arena_columns=64 binding_slots=64
AIE_TRAINING_ACCOUNTING case=bpe\\n input_bytes=32
 emitted_token_events=16
 unique_context_bindings=2
 allocated_minicolumns=2
 active_shards=0
 resident_inline_bytes=5640
 brain_bytes=5702
AIE_TRAINING_ACCOUNTING case=repeated_byte_fallback\\n input_bytes=32
 emitted_token_events=32
 unique_context_bindings=2
 allocated_minicolumns=2
 active_shards=0
 resident_inline_bytes=5640
 brain_bytes=5702
AIE_TRAINING_ACCOUNTING case=utf8_unknown\\n input_bytes=32
 emitted_token_events=32
 unique_context_bindings=3
 allocated_minicolumns=3
 active_shards=0
 resident_inline_bytes=5640
 brain_bytes=5702
AIE_TRAINING_ACCOUNTING case=unique_byte_fallback\\n input_bytes=32
 emitted_token_events=32
 unique_context_bindings=32
 allocated_minicolumns=32
 active_shards=0
 resident_inline_bytes=5640
 brain_bytes=5702
AIE_TRAINING_ACCOUNTING case=mixed\\n input_bytes=32
 emitted_token_events=24
 unique_context_bindings=4
 allocated_minicolumns=4
 active_shards=0
 resident_inline_bytes=5640
 brain_bytes=5702
```

The repeated fallback result is the bounded reuse evidence: 32 emitted events
produce only two equivalent active context bindings in a fresh fabric. The
UTF-8 vocabulary-miss input uses the raw two-byte encoding of `é` with no
matching BPE rule; both bytes remain bounded fallback tokens and the repeated
sequence reuses three bounded context bindings created by its sequence
boundaries. The unique fallback case reaches
one binding and one minicolumn per event in this 32-byte sample, while the fixed
resident and `.brain` layout does not grow.

The strict regression test in `tests/aie_fallback_reuse.act` trains the same
repeated fallback sequence twice in one fabric. The first pass allocates two
columns and two bindings; the second pass allocates zero columns and leaves the
active binding count at two.

## Same-length comparison

| Profile | Input bytes | Token events | Active bindings | Minicolumns | Resident inline | `.brain` |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| BPE-friendly | 32 | 16 | 2 | 2 | 5640 | 5702 |
| Repeated byte fallback | 32 | 32 | 2 | 2 | 5640 | 5702 |
| UTF-8 vocabulary miss | 32 | 32 | 3 | 3 | 5640 | 5702 |
| Unique byte fallback | 32 | 32 | 32 | 32 | 5640 | 5702 |
| Mixed BPE/fallback | 32 | 24 | 4 | 4 | 5640 | 5702 |

The current resident breakdown is:

| Resident component | Bytes |
| --- | ---: |
| 64 minicolumns (`64 * 64`) | 4096 |
| 64 binding slots (`64 * 24`) | 1536 |
| Fabric bookkeeping (`free_list_head`, `active_count`) | 8 |
| Total inline resident state | 5640 |

The fixed `.brain` breakdown is 32-byte header, 4116-byte fabric section, and
1554-byte binding section, totaling 5702 bytes. Shard headers, manifests, and
alignment padding are not part of this in-memory fixture and remain open for
the persistence gate.
