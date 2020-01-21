#!/usr/bin/env bash
#
# Build a docker-solr build directory and set tags
#
# Usage: build.sh dir

set -euo pipefail
TOP_DIR="$(readlink -f "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/..")"

if (( $# != 1 )); then
  echo "Usage: $0 build-dir"
  exit 1
fi

build_dir=$1
echo "build.sh $build_dir"

if [[ ! -f "$build_dir/Dockerfile" ]]; then
  echo "$build_dir is not a build directory"
  exit 1
fi
build_dir="$(readlink -f "$build_dir")"
relative_dir="$(sed -e "s,$TOP_DIR/,," <<< "$build_dir")"
cd "$build_dir"

if [[ -z "${IMAGE_NAME:-}" ]]; then
  IMAGE_NAME="dockersolr/docker-solr"
fi
full_tag="$(awk --field-separator ':' '$1 == "'"$relative_dir"'" {print $2}' "$TOP_DIR/TAGS")"

if [[ ! -f "$TOP_DIR/TAGS" ]]; then
  echo "missing TAGS; run update.sh"
fi

echo "Updating scripts"
major_version=$(echo "$full_tag" | sed -E -e 's/^([0-9]+).[0-9]+.*/\1/')
rm -fr scripts
if (( major_version < 8 )); then
  cp -r "$TOP_DIR/scripts-before8" scripts
else
  cp -r "$TOP_DIR/scripts" .
fi

build_arg=""
if [ -n "${SOLR_DOWNLOAD_SERVER:-}" ]; then
  build_arg="--build-arg SOLR_DOWNLOAD_SERVER=$SOLR_DOWNLOAD_SERVER"
fi
if [ -n "${SOLR_DOWNLOAD_URL:-}" ]; then
  build_arg="$build_arg --build-arg SOLR_DOWNLOAD_URL=$SOLR_DOWNLOAD_URL"
fi
if [ -n "${SOLR_VERSION:-}" ]; then
  build_arg="$build_arg --build-arg SOLR_VERSION=$SOLR_VERSION"
fi
if [ -n "${SOLR_SHA512:-}" ]; then
  build_arg="$build_arg --build-arg SOLR_SHA512=$SOLR_SHA512"
fi
if [ "${NOCACHE:-no}" == 'yes' ]; then
  nocache_arg="--no-cache"
fi
cmd="docker build --network=host --pull --rm=true ${build_arg:-} ${nocache_arg:-} --tag "$IMAGE_NAME:$full_tag" ."
echo "running: $cmd"
$cmd
extra_tags="$(awk --field-separator ':' '$1 == "'"$relative_dir"'" {print $3}' "$TOP_DIR/TAGS")"
for tag in $extra_tags; do
  cmd="docker tag $IMAGE_NAME:$full_tag $IMAGE_NAME:$tag"
  echo "running: $cmd"
  $cmd
done
