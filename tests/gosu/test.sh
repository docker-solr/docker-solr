#!/bin/bash
#
# A simple test of gosu. We create a mycores, and chown it
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

cd "$TEST_DIR"
rm -fr mycores
mkdir mycores

echo "Cleaning up left-over containers from previous runs"
container_cleanup "$container_name"

echo "Running $container_name"
docker run --user 0:0 --name "$container_name" -d -e VERBOSE=yes \
  -v  "$PWD/mycores:/opt/solr/server/solr/mycores" "$tag" \
  bash -c "chown -R solr:solr /opt/solr/server/solr/mycores; touch /opt/solr/server/solr/mycores/root_was_here; exec gosu solr:solr solr-precreate gettingstarted"

wait_for_server_started "$container_name"

echo "Loading data"
docker exec --user=solr "$container_name" bin/post -c gettingstarted example/exampledocs/manufacturers.xml
sleep 1
echo "Checking data"
data=$(docker exec --user=solr "$container_name" wget -q -O - 'http://localhost:8983/solr/gettingstarted/select?q=id%3Adell')
if ! egrep -q 'One Dell Way Round Rock, Texas 78682' <<<$data; then
  echo "Test $TEST_DIR $tag failed; data did not load"
  exit 1
fi
container_cleanup "$container_name"

# check test file was created by root
if [[ ! -f mycores/root_was_here ]]; then
  echo "Missing mycores/root_was_here"
  exit 1
fi
if [[ "$(stat -c %U mycores/root_was_here)" != root ]]; then
  echo "tmp/f is owned by $(stat -c %U mycores/root_was_here)"
  exit 1
fi

# check core is created by solr
if [[ ! -f mycores/gettingstarted/core.properties ]]; then
  echo "Missing mycores/gettingstarted/core.properties"
  exit 1
fi
if [[ "$(stat -c %u mycores/gettingstarted/core.properties)" != 8983 ]]; then
  echo "mycores/gettingstarted/core.properties is owned by $(stat -c %u mycores/gettingstarted/core.properties)"
  exit 1
fi

# chown it back
docker run --rm --user 0:0 -d -e VERBOSE=yes \
  -v "$PWD/mycores:/opt/solr/server/solr/mycores" "$tag" \
  bash -c "chown -R $(id -u):$(id -g) /opt/solr/server/solr/mycores; ls -ld /opt/solr/server/solr/mycores"

rm -fr mycores

echo "Test $TEST_DIR $tag succeeded"
