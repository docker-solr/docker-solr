#!/bin/bash
#
# Build a docker-solr build directory and set tags
#
# Usage: build.sh dir

set -euo pipefail
TOP_DIR="$(readlink -f "$(dirname "$(readlink -f "$BASH_SOURCE")")/..")"

build_dir=$1
cd "$TOP_DIR/$build_dir"

if [[ ! -f Dockerfile ]]; then
  echo "Run this from a build directory"
  exit 1
fi

if [[ -z "${IMAGE_NAME:-}" ]]; then
  IMAGE_NAME="docker-solr/docker-solr"
fi
full_tag="$(awk --field-separator ':' '$1 == "'"$build_dir"'" {print $2}' "$TOP_DIR/TAGS")"

if [[ ! -f "$TOP_DIR/TAGS" ]]; then
  echo "missing TAGS; run update.sh"
fi

if ! diff -r "$TOP_DIR/scripts" "scripts"; then
  echo "Updating scripts (old ones in scripts.old)"
  mv scripts scripts.old
  cp -r "$TOP_DIR/scripts" .
fi

if [ ! -z "${SOLR_DOWNLOAD_SERVER:-}" ]; then
  build_arg="--build-arg SOLR_DOWNLOAD_SERVER=$SOLR_DOWNLOAD_SERVER"
fi
cmd="docker build --pull --rm=true ${build_arg:-} --tag "$IMAGE_NAME:$full_tag" ."
echo "running: $cmd"
$cmd
extra_tags="$(awk --field-separator ':' '$1 == "'"$build_dir"'" {print $3}' "$TOP_DIR/TAGS")"
for tag in $extra_tags; do
  cmd="docker tag $IMAGE_NAME:$full_tag $IMAGE_NAME:$tag"
  echo "running: $cmd"
  $cmd
done
