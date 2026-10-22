# Phase 11 production acceptance

Recorded on 2026-10-22 from a clean Arch Linux workspace at Twin-e commit
`89d8cdc`.

## Command

```sh
actus build --strict --emit exe -o /tmp/twin-e-gate-11-9-runner src/main.act
/tmp/twin-e-gate-11-9-runner --config /tmp/twin-e-gate-11-7.conf
/tmp/twin-e-gate-11-9-runner --config /tmp/twin-e-gate-11-7-2.conf
/tmp/twin-e-gate-11-9-runner --config /tmp/twin-e-gate-11-7-3.conf
/tmp/twin-e-gate-11-9-runner --config /tmp/twin-e-gate-11-7-restart.conf
```

The configs use one manifest and the bounded `shard0` through `shard7` path
slots. The three accepted Georgian TWF inputs are the content-hashed files
listed in `phase-11-provenance.md`.

## Observed output

```text
starter-0001.twf records=8 accepted=8 events=252 allocated_columns=128 transitions=0 published
starter-0002.twf records=8 accepted=8 events=194 allocated_columns=52 transitions=0 published
starter-0003.twf records=7 accepted=7 events=292 allocated_columns=136 transitions=1 published
restart starter-0001.twf records=8 accepted=8 events=252 allocated_columns=100 transitions=2 resident_only
```

The published manifest contained two complete shard descriptors. The final
artifact sizes were manifest `160` bytes and two shard files of `90,616` bytes
each. The restart run loaded that published generation into one fresh logical
brain before accepting the next input; it did not create or switch to a second
brain.

The strict build reported no floating-point instructions. Runner executable
SHA-256:

```text
cfa7020c2f5eeece27c7b81c485df13e89cf05debeaf11bf8e850cc86aedc095
```

This is hosted Linux evidence only; it does not claim Cortex-M behavior or
large-scale performance beyond the recorded bounded profile.

The supported profile is eight logical shards, 1024 columns per shard, four
resident shards, 1024 bindings per shard, eight auxiliary records per shard,
eight request items, and eight manifest descriptors. Larger logical or resident
profiles are unsupported until a new bounded profile is validated; no
unbounded or multiple-brain fallback is part of this acceptance.
