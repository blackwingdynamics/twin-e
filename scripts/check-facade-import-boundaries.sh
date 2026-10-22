#!/usr/bin/env bash
set -euo pipefail

ACTUS_COMMAND="${ACTUS:-actus}"
FIXTURE="docs/fixtures/aie_nested_logical_import.act"

set +e
diagnostic="$(${ACTUS_COMMAND} check --strict "${FIXTURE}" 2>&1)"
status=$?
set -e

if [ "${status}" -eq 0 ]; then
    echo "nested logical import unexpectedly passed"
    exit 1
fi

if [[ "${diagnostic}" != *"error[E1101]"* || "${diagnostic}" != *"missing its canonical facade"* ]]; then
    echo "unexpected nested-import diagnostic:"
    echo "${diagnostic}"
    exit 1
fi

echo "facade import boundary rejected nested logical import as expected"
