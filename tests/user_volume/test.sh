#!/bin/bash
#
set -euo pipefail

TEST_DIR="$(dirname -- "${BASH_SOURCE-$0}")"

if (( $# == 0 )); then
  echo "Usage: $BASH_SOURCE tag"
  exit
fi

tag=$1

if [[ ! -z "${DEBUG:-}" ]]; then
  set -x
fi

source "$TEST_DIR/../shared.sh"

echo "Test $tag"
container_name='test_'$(echo "$tag" | tr ':/-' '_')
echo "Cleaning up left-over containers from previous runs"
container_cleanup "$container_name"

# create a core by hand:
rm -fr myconf
mkdir myconf
docker run \
  -v "$PWD/myconf:/myconf" \
  --user "$(id -u):$(id -g)" \
  --rm "$tag" bash -c 'cp -r /opt/solr/server/solr/configsets/data_driven_schema_configs/conf/* /myconf/'
find myconf
if [ ! f myconf/solrconfig.xml ]; then
  find myconf
  echo "ERROR: no solrconfig.xml"
  exit 1
fi

# create a directory for the core
rm -fr mycore
mkdir mycore
touch mycore/core.properties

rm -fr mylogs
mkdir mylogs

echo "Running $container_name"
docker run \
  -v "$PWD/mycore:/opt/solr/server/solr/mycore" \
  -v "$PWD/myconf:/opt/solr/server/solr/mycore/conf:ro" \
  -v "$PWD/mylogs:/opt/solr/server/logs" \
  --user "$(id -u):$(id -g)" \
  --name "$container_name" \
  -d "$tag"

SLEEP_SECS=5
echo "Sleeping $SLEEP_SECS seconds..."
sleep $SLEEP_SECS
container_status=$(docker inspect --format='{{.State.Status}}' "$container_name")
echo "container $container_name status: $container_status"
if [[ $container_status == 'exited' ]]; then
  docker logs "$container_name"
  exit 1
fi

SLEEP_SECS=10
echo "Sleeping $SLEEP_SECS seconds..."
sleep $SLEEP_SECS
echo "Checking Solr is running"
status=$(docker exec "$container_name" /opt/docker-solr/scripts/wait-for-solr.sh)
if ! egrep -q 'solr is running' <<<$status; then
  echo "Test test_simple $tag failed; solr did not start"
  container_cleanup "$container_name"
  exit 1
fi
sleep 5
echo "Loading data"
docker exec --user=solr "$container_name" bin/post -c mycore example/exampledocs/manufacturers.xml
sleep 1
echo "Checking data"
data=$(docker exec --user=solr "$container_name" wget -q -O - 'http://localhost:8983/solr/mycore/select?q=address_s%3ARound Rock')
if ! egrep -q 'One Dell Way Round Rock, Texas 78682' <<<$data; then
  echo "Test test_simple $tag failed; data did not load"
  exit 1
fi
container_cleanup "$container_name"

rm -fr myconf mycore mylogs

echo "Test test_simple $tag succeeded"
