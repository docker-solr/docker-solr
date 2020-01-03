#!/usr/bin/env bash
#
# Test all images (only the full version tag)
#
# Usage: test_all.sh

set -euo pipefail
TOP_DIR="$(readlink -f "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/..")"
cd "$TOP_DIR"

if [[ "$OSTYPE" == "darwin"* ]]; then
  echo Need to authenticate as root to run tests on MacOS
  sudo ls . > /dev/null
fi
full_version_variants=$(awk --field-separator ':' '{print $2}' < "$TOP_DIR/TAGS")
rm -rf tests/logs/*
echo Going to execute tests for these versions: $full_version_variants
echo Executing tests in parallell using 4 CPU cores per job
parallel --bar --halt-on-error 1 --jobs 25% ./tests/test.sh {} <<< "$full_version_variants" ">" tests/logs/test-{}.log "2>&1"
if [[ $? -ge 1 ]]; then
  echo "ERROR: Some tests failed. Please check logs in tests/logs folder"
else
  echo "SUCCESS"
fi