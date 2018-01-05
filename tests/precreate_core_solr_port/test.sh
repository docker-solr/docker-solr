#!/bin/bash
#
set -euo pipefail

TEST_DIR="$(dirname -- $(readlink -f "${BASH_SOURCE-$0}"))"

if (( $# == 0 )); then
  echo "Usage: $BASH_SOURCE tag"
  exit
fi

tag=$1

if [[ ! -z "${DEBUG:-}" ]]; then
  set -x
fi

source "$TEST_DIR/../shared.sh"

MY_SOLR_PORT=7777

echo "Test $TEST_DIR $tag"
container_name='test_'$(echo "$tag" | tr ':/-' '_')
echo "Cleaning up left-over containers from previous runs"
container_cleanup "$container_name"
echo "Running $container_name"
docker run --name "$container_name" -d -e VERBOSE=yes -e SOLR_PORT="$MY_SOLR_PORT" "$tag" solr-precreate gettingstarted

wait_for_server_started "$container_name"

echo "Loading data"
docker exec --user=solr "$container_name" bin/post -port "$MY_SOLR_PORT" -c gettingstarted example/exampledocs/manufacturers.xml
sleep 1
echo "Checking data"
data=$(docker exec --user=solr "$container_name" wget -q -O - "http://localhost:$MY_SOLR_PORT/solr/gettingstarted/select?q=id%3Adell")
if ! egrep -q 'One Dell Way Round Rock, Texas 78682' <<<$data; then
  echo "Test $TEST_DIR $tag failed; data did not load"
  exit 1
fi
container_cleanup "$container_name"

echo "Test $TEST_DIR $tag succeeded"