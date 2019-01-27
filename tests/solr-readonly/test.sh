#!/bin/bash
#
set -euo pipefail

TEST_DIR="$(dirname -- "$(readlink -f "${BASH_SOURCE-$0}")")"

if (( $# == 0 )); then
  echo "Usage: ${BASH_SOURCE[0]} tag"
  exit
fi

tag=$1

if [[ ! -z "${DEBUG:-}" ]]; then
  set -x
fi

# this test only works in images
# that have been installed by install_solr_service.sh.
# Detect that based on tag (TODO: determine this dynamically
# based on a "docker run")
if ! grep -q 'installer' <<<"$tag"; then
  echo "Test $TEST_DIR $tag skipped"
  exit 0
fi

source "$TEST_DIR/../shared.sh"

echo "Test $TEST_DIR $tag"
container_name='test_'$(echo "$tag" | tr ':/-' '_')
echo "Cleaning up left-over containers from previous runs"
container_cleanup "$container_name"
echo "Running $container_name"
docker run --name "$container_name" -d "$tag" bash -c "chmod a-w -R /opt/solr; solr-demo"

wait_for_server_started "$container_name"

echo "Checking data"
data=$(docker exec --user=solr "$container_name" wget -q -O - 'http://localhost:8983/solr/demo/select?q=id%3Adell')
if ! grep -E -q 'One Dell Way Round Rock, Texas 78682' <<<"$data"; then
  echo "Test $TEST_DIR $tag failed; data did not load"
  exit 1
fi
container_cleanup "$container_name"

echo "Test $TEST_DIR $tag succeeded"
