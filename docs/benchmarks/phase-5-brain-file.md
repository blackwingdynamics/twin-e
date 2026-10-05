# Phase 5 Combined `.brain` File Benchmark

This benchmark exercises the first P5.1 implementation slice. It writes one
combined `.brain` file containing the fixed fabric and TokenBinding sections,
clears both in-memory values, loads the file, and verifies that the values and
compatibility metadata return.

## Command

```sh
actus build --strict --emit exe -o /tmp/twin-e-p5-brain.aie benchmarks/aie_text_brain_file.act
/tmp/twin-e-p5-brain.aie
```

## Expected evidence shape

```text
AIE_P5_BRAIN roundtrip=1 bytes=5702 fabric=1 bindings=1 compatibility=1
```

The benchmark is an in-process save/clear/load round trip. It does not yet
close the restart acceptance gate because the process is not restarted between
the save and load operations. Corruption rejection, unchanged-state failure
behavior, and a separate process restart fixture remain open in P5.1.

## Recorded evidence

Command:

```text
actus build --strict --emit exe -o /tmp/twin-e-p5-brain.aie benchmarks/aie_text_brain_file.act
/tmp/twin-e-p5-brain.aie
```

Result:

```text
built `/tmp/twin-e-p5-brain.aie` (strict)
verified generated native IR: no floating-point instructions
AIE_P5_BRAIN roundtrip=1 bytes=5702 fabric=1 bindings=1 compatibility=1
```

Recorded source base: `601080e`.

Actus binary SHA-256:

```text
827fa0a8b43fdbf8562872459048037e82017484055a5a71e4d03a8890d9168b
```
