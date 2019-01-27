#!/bin/bash

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

if (( $# == 0 )); then
  echo "Usage: ${[BASH_SOURCE[0]]} tag"
  exit
fi

if [[ -z "${IMAGE_NAME:-}" ]]; then
  IMAGE_NAME="dockersolr/docker-solr"
fi

tag=$1
if ! grep -q : <<<"$tag"; then
  tag="$IMAGE_NAME:$tag"
fi

echo "Running all tests for $tag"
find . -mindepth 1 -maxdepth 1 -type d | sed -E -e 's/^\.\///' > tests_to_run
while read  -r d; do
  if [ -f "$d/test.sh" ]; then
    echo "Starting $d/test.sh $tag"
    (cd "$d"; ./test.sh "$tag")
    echo "Finished $d/test.sh $tag"
    echo
  fi
done < tests_to_run
rm tests_to_run
echo "Completed all tests for $tag"
