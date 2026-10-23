# Phase 5 Vocabulary Process Restart Benchmark

This benchmark uses two separate strict native processes. The writer saves a
fabric, binding state, and one bounded BPE merge artifact. The reader starts
with empty state, loads the `.brain` file, and verifies that `AB` is encoded
as the restored merged token `256`.

## Commands

```sh
actus build --strict --emit exe \
  -o /tmp/twin-e-p5-vocab-restart-write.ie \
  benchmarks/ie_text_brain_vocabulary_restart_write.act
actus build --strict --emit exe \
  -o /tmp/twin-e-p5-vocab-restart-read.ie \
  benchmarks/ie_text_brain_vocabulary_restart_read.act
/tmp/twin-e-p5-vocab-restart-write.ie
/tmp/twin-e-p5-vocab-restart-read.ie
```

## Recorded result

```text
IE_P5_VOCAB_RESTART save=1 bytes=11106 process=writer
IE_P5_VOCAB_RESTART reload=1 recalled=1 merged_decode=1 process=reader
```

Both executables were built with strict native IR verification and reported no
floating-point instructions. The reader verified the restored vocabulary
metadata, merge rule, merged token record, fabric state, and binding state.
