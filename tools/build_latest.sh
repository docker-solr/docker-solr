#!/usr/bin/env bash
#
# Build just the latest version
#
# Usage: build_latest.sh

set -euo pipefail
if [[ "$OSTYPE" == "darwin"* ]]; then alias readlink=greadlink; shopt -s expand_aliases; fi
TOP_DIR="$(readlink -f "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/..")"
cd "$TOP_DIR"

latest_dir=$(awk --field-separator ':' '$3 ~ / latest$/ {print $1}' "$TOP_DIR/TAGS")
tools/build.sh "$latest_dir"
