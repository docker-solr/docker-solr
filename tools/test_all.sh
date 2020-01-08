#!/usr/bin/env bash
#
# Test all images (only the full version tag)
#
# Usage: test_all.sh [num-processes]

set -euo pipefail
TOP_DIR="$(readlink -f "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/..")"
cd "$TOP_DIR"

if [ -z "${1:-}" ]; then
  num_processes=2
else
  num_processes=$1
fi

if [[ "$OSTYPE" == "darwin"* ]]; then
  echo Please authenticate to run sudo on macOS
  sudo ls . > /dev/null
fi
full_version_variants=$(awk --field-separator ':' '{print $2}' < "$TOP_DIR/TAGS")
rm -rf tests/logs/*.log 2>/dev/null
echo "Going to execute tests for these versions: $full_version_variants"
echo "Executing tests in parallell with $num_processes processes"
parallel --bar --halt-on-error 1 --jobs "$num_processes" ./tests/test.sh {} <<< "$full_version_variants" ">" tests/logs/test-{}.log "2>&1"
if [[ $? -ge 1 ]]; then
  echo "ERROR: Some tests failed. Please check logs in tests/logs folder"
else
  echo "SUCCESS"
fi
