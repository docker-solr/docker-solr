#!/bin/bash
#
# Push all images
#
# Usage: push_all.sh

set -euo pipefail
TOP_DIR="$(readlink -f "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/..")"
cd "$TOP_DIR"

full_version_variants=$(awk --field-separator ':' '{print $2}' "$TOP_DIR/TAGS")
for full_version_variant in $full_version_variants; do
  readarray -t tags < <(awk --field-separator ':' '$2 == "'"$full_version_variant"'" {print $3}' "$TOP_DIR/TAGS")
  echo ./tools/push.sh "$full_version_variant" "${tags[@]}"
  ./tools/push.sh "$full_version_variant" "${tags[@]}"
done
