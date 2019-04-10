#!/bin/bash
#
# A simple test of gosu. We create a myvarsolr, and chown it
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

cd "$TEST_DIR"
rm -fr myvarsolr
mkdir myvarsolr

echo "Cleaning up left-over containers from previous runs"
container_cleanup "$container_name"

echo "Running $container_name"
docker run --user 0:0 --name "$container_name" -d -e VERBOSE=yes \
  -v "$PWD/myvarsolr:/var/solr" "$tag" \
  bash -c "chown -R solr:solr /var/solr; touch /var/solr/root_was_here; exec gosu solr:solr solr-precreate gettingstarted"

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
container_cleanup "$container_name"

# check test file was created by root
if [[ ! -f myvarsolr/root_was_here ]]; then
  echo "Missing myvarsolr/root_was_here"
  exit 1
fi
if [[ "$(stat -c %U myvarsolr/root_was_here)" != root ]]; then
  echo "myvarsolr/root_was_here is owned by $(stat -c %U myvarsolr/root_was_here)"
  exit 1
fi

# check core is created by solr
if [[ ! -f myvarsolr/data/gettingstarted/core.properties ]]; then
  echo "Missing myvarsolr/data/gettingstarted/core.properties"
  exit 1
fi
if [[ "$(stat -c %u myvarsolr/data/gettingstarted/core.properties)" != 8983 ]]; then
  echo "myvarsolr/data/gettingstarted/core.properties is owned by $(stat -c %u myvarsolr/data/gettingstarted/core.properties)"
  exit 1
fi

# chown it back
docker run --rm --user 0:0 -d -e VERBOSE=yes \
  -v "$PWD/myvarsolr:/myvarsolr" "$tag" \
  bash -c "chown -R $(id -u):$(id -g) /myvarsolr; ls -ld /myvarsolr"

rm -fr myvarsolr

echo "Test $TEST_DIR $tag succeeded"
