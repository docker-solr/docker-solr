#!/bin/bash
#
# A simple test of gosu. We create a mycores, and chown it
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

# mycores is not supported in images
# that have been installed by install_solr_service.sh.
# Detect that based on tag (TODO: determine this dynamically
# based on a "docker run")
if grep -q 'installer' <<<"$tag"; then
  echo "Test $TEST_DIR $tag skipped"
  exit 0
fi

source "$TEST_DIR/../shared.sh"

echo "Test $TEST_DIR $tag"
container_name='test_'$(echo "$tag" | tr ':/-' '_')

MYCORES_DIR=mycores

cd "$TEST_DIR"
if [ -d mycores ]; then
  # remove any leftovers
  docker run --rm --user 0:0 --rm \
    -v "$PWD/$MYCORES_DIR:/mycores" "$tag" \
    bash -c "rm -fr /mycores/*"
fi

rm -fr "$MYCORES_DIR"
mkdir "$MYCORES_DIR"

echo "Cleaning up left-over containers from previous runs"
container_cleanup "$container_name"

ROOT_TEST_FILENAME=root_was_here

echo "Running $container_name"
docker run --user 0:0 --name "$container_name" -d -e VERBOSE=yes \
  -v  "$PWD/$MYCORES_DIR:/opt/solr/server/solr/mycores" "$tag" \
  bash -c "chown -R solr:solr /opt/solr/server/solr/mycores; touch /opt/solr/server/solr/mycores/$ROOT_TEST_FILENAME; exec gosu solr:solr solr-precreate gettingstarted"

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
if [[ ! -f "$MYCORES_DIR/$ROOT_TEST_FILENAME" ]]; then
  echo "Missing $MYCORES_DIR/$ROOT_TEST_FILENAME"
  exit 1
fi
if [[ "$(stat -c %U "$MYCORES_DIR/$ROOT_TEST_FILENAME")" != root ]]; then
  echo "$ROOT_TEST_FILENAME is owned by $(stat -c %U "$MYCORES_DIR/$ROOT_TEST_FILENAME")"
  exit 1
fi

# check core is created by solr
if [[ ! -f "$MYCORES_DIR/gettingstarted/core.properties" ]]; then
  echo "Missing $MYCORES_DIR/gettingstarted/core.properties"
  exit 1
fi
if [[ "$(stat -c %u "$MYCORES_DIR/gettingstarted/core.properties")" != 8983 ]]; then
  echo "$MYCORES_DIR/gettingstarted/core.properties is owned by $(stat -c %u "$MYCORES_DIR/gettingstarted/core.properties")"
  exit 1
fi

# chown it back
docker run --rm --user 0:0 -d -e VERBOSE=yes \
  -v "$PWD/$MYCORES_DIR:/opt/solr/server/solr/mycores" "$tag" \
  bash -c "chown -R $(id -u):$(id -g) /opt/solr/server/solr/mycores; ls -ld /opt/solr/server/solr/mycores"

rm -fr $MYCORES_DIR

echo "Test $TEST_DIR $tag succeeded"
