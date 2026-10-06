#!/bin/sh

set -eu

demo_binary="/tmp/twin-e-human-brain-demo.aie"

actus build --strict --emit exe \
  -o "$demo_binary" \
  benchmarks/aie_human_brain_demo.act

"$demo_binary" | while IFS= read -r line; do
    printf '%s\n' "$line"
    sleep 0.35
done
