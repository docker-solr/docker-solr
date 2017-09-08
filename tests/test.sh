#!/bin/bash

set -euo pipefail

cd "$(dirname "$BASH_SOURCE")"

if (( $# == 0 )); then
  echo "Usage: $BASH_SOURCE tag"
  exit
fi

if [[ -z "${IMAGE_NAME:-}" ]]; then
  IMAGE_NAME="docker-solr/docker-solr"
fi

tag=$1
if ! grep -q : <<<$tag; then
  tag="$IMAGE_NAME:$tag"
fi

find . -mindepth 1 -maxdepth 1 -type d > tests_to_run
while read  -r d; do
  if [ -f "$d/test.sh" ]; then
    echo "Starting $d/test.sh $tag"
    (cd "$d"; ./test.sh "$tag")
    echo "Finished $d/test.sh $tag"
    echo
  fi
done < tests_to_run
rm tests_to_run
