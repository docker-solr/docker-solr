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

echo "Test $TEST_DIR $tag"
container_name='test_'$(echo "$tag" | tr ':/-' '_')
echo "Cleaning up left-over containers from previous runs"
container_cleanup "$container_name"

cd "$TEST_DIR"
rm -fr initdb.d
mkdir initdb.d
cat > initdb.d/create-was-here.sh <<EOM
touch /opt/docker-solr/initdb-was-here
EOM
cat > initdb.d/ignore-me <<EOM
touch /opt/docker-solr/should-not-be
EOM

echo "Running $container_name"
docker run --name "$container_name" -d -e VERBOSE=yes -v "$PWD/initdb.d:/docker-entrypoint-initdb.d" "$tag"

wait_for_server_started "$container_name"

echo "Checking initdb"
data=$(docker exec --user=solr "$container_name" ls /opt/docker-solr/initdb-was-here)
if [[ "$data" != /opt/docker-solr/initdb-was-here ]]; then
  echo "Test $TEST_DIR $tag failed; script did not run"
  exit 1
fi
data=$(docker exec --user=solr "$container_name" ls /opt/docker-solr/should-not-be; true)
if [[ ! -z "$data" ]]; then
  echo "Test $TEST_DIR $tag failed; should-not-be was"
  exit 1
fi
echo "Checking docker logs"
if ! docker logs "$container_name" | grep 'ignoring /docker-entrypoint-initdb.d/ignore-me'; then
  echo "missing ignoring message"
  exit 1
fi

rm -fr initdb.d
container_cleanup "$container_name"

echo "Test $TEST_DIR $tag succeeded"
