# Phase 5 Contract Evidence

This document defines the evidence record for the Phase 5 contract gate. It is
not a benchmark result and must not be read as measured runtime performance.

## Required command metadata

Each executable Phase 5 benchmark records:

- command;
- source commit;
- Actus compiler version and binary digest;
- target and profile;
- input size and configured bounds;
- captured stdout and stderr status;
- deterministic result fields.

## Contract record

The compatibility and integer-only baseline uses this shape:

```text
IE_P5_CONTRACT profile=integer_v1 brain_format=1 tokenizer=1 context=1 codebook=1 deterministic=1 zero_float=1
```

The values are populated only by an executable benchmark after the supported
profile has been implemented and verified.

## Separate latency boundaries

Hot-path and persistence work must be measured separately:

```text
IE_P5_HOT_PATH inference_ns=<value> training_ns=<value> neurogenesis_ns=<value> disk_writes=0
IE_P5_PERSISTENCE save=1 flush_ns=<value> restart_recall=1 recovery=1
```

`disk_writes=0` applies only to the measured hot-path operation. The save and
flush record reports explicit persistence work separately.

## Acceptance rule

Do not replace placeholders with estimates. A Phase 5 evidence report may
claim a result only when the exact command produces the recorded values under
the documented compiler, target, input, and configuration conditions.
