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

major_version=$(echo "$tag" | sed -E -e 's/^.*:([0-9]+).[0-9]+.*/\1/')
if (( major_version > 7 )); then
  test_dir=tests-8
else
  test_dir=tests-before8
fi

echo "Running all tests for $tag"
find "$test_dir" -mindepth 1 -maxdepth 1 -type d | sed -E -e 's/^\.\///' > tests_to_run
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
