#!/usr/bin/env bash
#
# Usage: build_and_tesh.sh
set -euo pipefail

if [[ -n "${DEBUG:-}" ]]; then
  set -x
fi

build_dir=$1

TOP_DIR="$(dirname "${BASH_SOURCE[0]}")/.."
cd "$TOP_DIR"
./tools/build.sh "$build_dir"
relative_dir="$(sed "s,$TOP_DIR/,," <<< "$build_dir")"
full_version=$(awk --field-separator ':' '$1 == "'"$relative_dir"'" {print $2}' "$TOP_DIR/TAGS")
./tests/test.sh "dockersolr/docker-solr:$full_version"
