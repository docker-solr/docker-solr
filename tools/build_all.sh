#!/bin/bash
#
# Build all images
#
# Usage: build_all.sh

set -euo pipefail
TOP_DIR="$(readlink -f "$(dirname "$(readlink -f "$BASH_SOURCE")")/..")"
cd "$TOP_DIR"

build_dirs=$(awk --field-separator ':' '{print $1}' "$TOP_DIR/TAGS")
for d in $build_dirs; do
  tools/build.sh "$d"
done
echo "all docker-solr images:"
docker images | awk '$1 ~ /docker-solr/ { print $3" "$1":"$2 }'  | sort --version-sort --key 2
