#!/bin/bash
#
# Test all images
#
# Usage: test_all_parallel.sh

set -euo pipefail
TOP_DIR="$(readlink -f "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/..")"
cd "$TOP_DIR"

build_dirs=()
while IFS= read -r line; do
    build_dirs+=($line)
done < <(awk --field-separator ':' '{print $1}' "$TOP_DIR/TAGS")

echo "testing ${#build_dirs[@]} build directories: " "${build_dirs[@]}"

LOG_NAME=test.log
find . -name "$LOG_NAME" -exec /bin/rm {} \;

if ! parallel -j 5 -i bash -c "./tests/test.sh {} >{}/$LOG_NAME 2>&1" -- "${build_dirs[@]}"; then
    failed=true
fi

for build_dir in "${build_dirs[@]}"; do
    echo "=========== Log for $build_dir ==========="
    cat "$build_dir/$LOG_NAME"
    echo
done

if [[ -n "${failed:-}" ]]; then
    echo "One or more tests failed"
    for build_dir in "${build_dirs[@]}"; do
        if ! grep -E -q 'Completed all tests' "$build_dir/$LOG_NAME"; then
            echo "See $build_dir/$LOG_NAME"
        fi
    done
    exit 1
fi
