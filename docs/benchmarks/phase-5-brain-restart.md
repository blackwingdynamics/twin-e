# Phase 5 `.brain` Process Restart Benchmark

This benchmark uses two separate executable processes. The writer creates a
trained fabric and binding state, exits, and the reader starts with fresh empty
state before loading the same `.brain` file.

## Commands

```sh
actus build --strict --emit exe -o /tmp/twin-e-p5-restart-write.ie benchmarks/ie_text_brain_restart_write.act
actus build --strict --emit exe -o /tmp/twin-e-p5-restart-read.ie benchmarks/ie_text_brain_restart_read.act
/tmp/twin-e-p5-restart-write.ie
/tmp/twin-e-p5-restart-read.ie
```

## Recorded evidence

The writer and reader were built with the strict compiler profile and both
native artifacts reported zero floating-point instructions. The writer was
run first and exited after saving the file; the reader then started as a
separate process with fresh state and restored the saved payload, strength,
token, context, and binding flag.

```text
IE_P5_RESTART save=1 bytes=5702 process=writer
IE_P5_RESTART reload=1 recalled=1 process=reader
```

The paired process check proves restart recovery for the current fixed
fabric-and-binding snapshot. It does not yet prove tokenizer vocabulary or
merge-rule artifact persistence.

## Expected evidence

```text
IE_P5_RESTART save=1 bytes=5702 process=writer
IE_P5_RESTART reload=1 recalled=1 process=reader
```
