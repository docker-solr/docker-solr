#!/bin/bash
#
# Usage: build_and_tesh.sh
set -euo pipefail

if [[ ! -z "${DEBUG:-}" ]]; then
  set -x
fi

TOP_DIR=$(dirname "$BASH_SOURCE")
cd "$TOP_DIR"
cat TAGS
./tools/build_all.sh
./tools/test_all.sh
