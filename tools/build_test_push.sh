#!/bin/bash
#
set -euo pipefail

if [[ ! -z "${DEBUG:-}" ]]; then
  set -x
fi

TOP_DIR="$(readlink -f "$(dirname "$(readlink -f "$BASH_SOURCE")")/..")"
cd "$TOP_DIR"

build_dir="$1"
if [[ ! -f "$build_dir/Dockerfile" ]]; then
  echo "$build_dir does not appear to be build directory"
  exit 1
fi

parent="$(grep '^FROM' "$build_dir/Dockerfile" | sed -E 's/^.*FROM *//')"
echo "pulling $parent"
docker pull "$parent" >/dev/null 2>&1

./tools/build.sh "$build_dir"
full_version=$(awk --field-separator ':' '$1 == "'"$build_dir"'" {print $2}' "$TOP_DIR/TAGS")
./tests/test.sh "$full_version"
tags=($(awk --field-separator ':' '$1 == "'"$build_dir"'" {print $3}' "$TOP_DIR/TAGS"))
/tools/push.sh "$full_version" "${tags[@]}"
