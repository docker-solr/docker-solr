#!/bin/bash

set -euo pipefail

if (( $# == 0 )); then
  echo "Usage: $BASH_SOURCE tag"
  exit
fi

tag=$1

for d in $(find . -mindepth 1 -maxdepth 1 -type d); do
  if [ -f "$d/test.sh" ]; then
    echo "Starting $d/test.sh $tag"
    (cd $d; ./test.sh "$tag")
    echo "Finished $d/test.sh $tag"
    echo
  fi
done
