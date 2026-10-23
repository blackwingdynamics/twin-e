# Teaching wire evidence

This fixture records the bounded `std::wire` teaching transport evidence for
the current Twin-e contract.

## Executable tests

Command:

```sh
actus lock --check
actus check --strict
actus test --strict
```

Result on 2026-10-23: `202 passed; 0 failed`.

The tests cover deterministic split-frame reconstruction, valid-frame decode,
unsupported-version rejection, checksum corruption, truncation, oversized
payloads, replayed sequence numbers, and preservation of the caller payload
buffer after a failed frame.

## Native zero-float evidence

Command:

```sh
actus build --strict --emit exe \
  -o /tmp/twin-e-gate-10-5-wire-native
```

Observed result:

```text
built `/tmp/twin-e-gate-10-5-wire-native` (strict)
verified generated native IR: no floating-point instructions
```

Environment: `x86_64` host; installed compiler `/home/magradze/.cargo/bin/actus`;
compiler binary SHA-256
`7ebbcd4791b139de6a3543d72645256cb7e1ef59db397c1e9f6b3d01c4f7f3dd`.
The CLI does not expose a compiler revision command, so the binary digest is
recorded as the reproducibility identifier.

Wire parsing remains allocation-free and transport-only: it does not call
modality adapters, teaching pipelines, IE mutation, or persistence.
