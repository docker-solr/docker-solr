#!/bin/bash
#
set -euo pipefail

TEST_DIR="$(dirname -- "$(readlink -f "${BASH_SOURCE-$0}")")"

if (( $# == 0 )); then
  echo "Usage: ${BASH_SOURCE[0]} tag"
  exit
fi

tag=$1

if [[ -n "${DEBUG:-}" ]]; then
  set -x
fi

source "$TEST_DIR/../../shared.sh"

echo "Test $TEST_DIR $tag"

container_name='test_'$(echo "$tag" | tr ':/-' '_')

VOLUME_NAME="$container_name-solrhome"
docker volume create --name "$VOLUME_NAME"

container_cleanup "$container_name"

echo "Running $container_name"

docker run --name "$container_name" -d -v "$VOLUME_NAME:/opt/mysolrhome" -e SOLR_HOME=/opt/mysolrhome -e INIT_SOLR_HOME=yes -d "$tag" "solr-demo"

wait_for_server_started "$container_name"

echo "Checking data"
data=$(docker exec --user=solr "$container_name" wget -O - 'http://localhost:8983/solr/demo/select?q=id%3Adell')
if ! grep -E -q 'One Dell Way Round Rock, Texas 78682' <<<"$data"; then
  echo "Test $TEST_DIR $tag failed; data did not load"
  exit 1
fi
echo "Data loaded OK"

container_cleanup "$container_name"

docker volume rm "$VOLUME_NAME"

echo "Test $TEST_DIR $tag succeeded"
