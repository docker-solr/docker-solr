#!/bin/bash
#
set -euo pipefail

TEST_DIR="$(dirname -- "$(readlink -f "${BASH_SOURCE-$0}")")"

if (( $# == 0 )); then
  echo "Usage: ${BASH_SOURCE[0]} tag"
  exit
fi

tag=$1

if ! grep -q 'installer' <<<"$tag"; then
  echo "Test $TEST_DIR $tag skipped"
  exit 0
fi

if [[ ! -z "${DEBUG:-}" ]]; then
  set -x
fi

source "$TEST_DIR/../shared.sh"

echo "Test $TEST_DIR $tag"

container_name='test_'$(echo "$tag" | tr ':/-' '_')

DATA_VOLUME_NAME="$container_name-var_data"
docker volume create --name "$DATA_VOLUME_NAME"

LOGS_VOLUME_NAME="$container_name-var_logs"
docker volume create --name "$LOGS_VOLUME_NAME"

container_cleanup "$container_name"

echo "Running $container_name"

docker run --name "$container_name" -d \
  -v "$DATA_VOLUME_NAME:/var/solr/data" \
  -v "$LOGS_VOLUME_NAME:/var/solr/logs" \
  -d "$tag" "solr-demo"

wait_for_server_started "$container_name"

echo "Checking data"
data=$(docker exec --user=solr "$container_name" wget -O - 'http://localhost:8983/solr/demo/select?q=id%3Adell')
if ! grep -E -q 'One Dell Way Round Rock, Texas 78682' <<<"$data"; then
  echo "Test $TEST_DIR $tag failed; data did not load"
  exit 1
fi
echo "Data loaded OK"

echo "Checking data volume"
docker exec --user=solr "$container_name" ls /var/solr/data | grep -q demo
docker exec --user=solr "$container_name" ls /var/solr/data | grep -q solr.xml
docker exec --user=solr "$container_name" ls /var/solr/data | grep -q zoo.cfg
echo "Checking logs volume"
docker exec --user=solr "$container_name" ls /var/solr/logs | grep -q solr.log

container_cleanup "$container_name"

docker volume rm "$DATA_VOLUME_NAME"
docker volume rm "$LOGS_VOLUME_NAME"

echo "Test $TEST_DIR $tag succeeded"
