#!/bin/bash
#
# Build all images
#
# Usage: build_all.sh

set -euo pipefail
TOP_DIR="$(readlink -f "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/..")"
cd "$TOP_DIR"

build_dirs=$(awk --field-separator ':' '{print $1}' "$TOP_DIR/TAGS")
for d in $build_dirs; do
  tools/build.sh "$d"
done
echo "all dockersolr images:"
docker images | awk '$1 ~ /dockersolr/ { print $3" "$1":"$2 }'  | sort --version-sort --key 2
