#!/bin/bash

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

if (( $# == 0 )); then
  echo "Usage: ${[BASH_SOURCE[0]]} tag"
  exit
fi

tag=$1

# if the user specified eg 7.6/slim, translate that to 7.6-slim
if [ -d "../$tag" ]; then
    tag="$(sed 's,/,-,' <<<"$tag")"
fi

if [[ -z "${IMAGE_NAME:-}" ]]; then
  IMAGE_NAME="dockersolr/docker-solr"
fi

if ! grep -q : <<<"$tag"; then
  tag="$IMAGE_NAME:$tag"
fi

MYDIR="$PWD"
echo "Running all tests for $tag"
tests_to_run=tests_to_run.$$
find . -mindepth 1 -maxdepth 1 -type d | sed -E -e 's/^\.\///' > "$tests_to_run"
while read  -r d; do
  if [ -f "$d/test.sh" ]; then
    echo "Starting $d/test.sh $tag"
    cd "$MYDIR/$d"
    ./test.sh "$tag"
    echo "Finished $d/test.sh $tag"
    echo
  fi
done < "$tests_to_run"
cd "$MYDIR"
rm "$tests_to_run"
echo "Completed all tests for $tag"
