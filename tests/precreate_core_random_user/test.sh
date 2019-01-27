#!/bin/bash
#
set -euo pipefail

TEST_DIR="$(dirname -- "$(readlink -f "${BASH_SOURCE-$0}")")"

if (( $# == 0 )); then
  echo "Usage: ${BASH_SOURCE[0]} tag"
  exit
fi

tag=$1

if ! grep -q 'openshift' <<<"$tag"; then
  echo "Test $TEST_DIR $tag skipped"
  exit 0
fi

if [[ ! -z "${DEBUG:-}" ]]; then
  set -x
fi

source "$TEST_DIR/../shared.sh"

echo "Test $TEST_DIR $tag"
container_name='test_'$(echo "$tag" | tr ':/-' '_')
echo "Cleaning up left-over containers from previous runs"
container_cleanup "$container_name"
echo "Running $container_name"
docker run --name "$container_name" -d --user 1000600000:0 "$tag" solr-create -c gettingstarted

wait_for_server_started "$container_name"

echo "Loading data"
docker exec --user=solr "$container_name" bin/post -c gettingstarted example/exampledocs/manufacturers.xml
sleep 1
echo "Checking data"
data=$(docker exec --user=solr "$container_name" wget -q -O - 'http://localhost:8983/solr/gettingstarted/select?q=id%3Adell')
if ! grep -E -q 'One Dell Way Round Rock, Texas 78682' <<<"$data"; then
  echo "Test $TEST_DIR $tag failed; data did not load"
  exit 1
fi
echo "Checking file ownership"
readme_uid="$(docker exec -i "$container_name" stat -c %u README.txt)"
if (( $readme_uid != 8983 )); then
  echo "bad readme_uid: $readme_uid"
  exit 1
fi
readme_gid="$(docker exec -i "$container_name" stat -c %g README.txt)"
if [[ $readme_gid -ne 0 ]]; then
  echo "bad readme_gid: $readme_gid"
  exit 1
fi
core_uid="$(docker exec -i "$container_name" stat -c %u server/solr/gettingstarted/core.properties)"
if [[ $core_uid -ne 1000600000 ]]; then
  echo "bad core_uid: $core_uid"
  exit 1
fi
core_gid="$(docker exec -i "$container_name" stat -c %g server/solr/gettingstarted/core.properties)"
if [[ $core_gid -ne 0 ]]; then
  echo "bad core_gid: $core_uid"
  exit 1
fi

container_cleanup "$container_name"

echo "Test $TEST_DIR $tag succeeded"
