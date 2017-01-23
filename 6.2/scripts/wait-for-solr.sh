#!/bin/bash
#
# A helper script to wait for solr
#
# Usage: wait-for-solr.sh [ max_try [ wait_seconds ] ]

set -e

if [[ "$VERBOSE" = "yes" ]]; then
    set -x
fi

function usage {
  echo $@
  echo "$0 [ max_try [ wait_seconds ] ]"
  exit 1
}

max_try=$1
if [[ -z $max_try ]]; then
  max_try=12
else
  grep -q -E '^[0-9]+$' <<<$max_try || usage "$max_try is not a number"
fi
wait_seconds=$2
if [[ -z $wait_seconds ]]; then
  wait_seconds=5
else
  grep -q -E '^[0-9]+$' <<<$wait_seconds || usage "$wait_seconds is not a number"
fi
let i=1
until wget -q -O - http://localhost:8983 | grep -q -i solr; do
  echo "solr is not running yet"
  if (( $i == $max_try )); then
    echo "solr is still not running; giving up"
    exit 1
  fi
  let "i++"
  sleep $wait_seconds
done
echo "solr is running"
