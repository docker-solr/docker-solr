#!/usr/bin/env bash
#
set -euo pipefail

if [[ -n "${DEBUG:-}" ]]; then
  set -x
fi

TOP_DIR="$(readlink -f "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/..")"
IMAGE_NAME="dockersolr/docker-solr"
if (( $# != 1 )); then
  echo "Usage: $0 build-dir"
  exit 1
fi

build_dir="$1"
if [[ ! -f "$build_dir/Dockerfile" ]]; then
  echo "$build_dir does not appear to be a build directory"
  exit 1
fi
build_dir="$(readlink -f "$build_dir")"
relative_dir="$(sed "s,$TOP_DIR/,," <<< "$build_dir")"

parent="$(grep '^FROM' "$build_dir/Dockerfile" | sed -E 's/^.*FROM *//')"
echo "pulling $parent"
docker pull "$parent" >/dev/null 2>&1

"$TOP_DIR/tools/build.sh" "$build_dir"
full_version=$(awk --field-separator ':' '$1 == "'"$relative_dir"'" {print $2}' "$TOP_DIR/TAGS")
"$TOP_DIR/tests/test.sh" "$full_version"
read -r -a tags < <(awk --field-separator ':' '$1 == "'"$relative_dir"'" {print $3}' "$TOP_DIR/TAGS")
"$TOP_DIR/tools/push.sh" "$IMAGE_NAME:$full_version"
for tag in "${tags[@]}"; do
    "$TOP_DIR/tools/push.sh" "$IMAGE_NAME:$tag"
done
