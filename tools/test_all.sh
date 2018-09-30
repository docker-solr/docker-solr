#!/bin/bash
#
# Test all images (only the full version tag)
#
# Usage: test_all.sh

set -euo pipefail
TOP_DIR="$(readlink -f "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/..")"
cd "$TOP_DIR"

full_version_variants=$(tac "$TOP_DIR/TAGS" | awk --field-separator ':' '{print $2}')
for full_version_variant in $full_version_variants; do
  ./tests/test.sh "$full_version_variant"
done
