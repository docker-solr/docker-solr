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

cd "$TEST_DIR"

DATA_DIR_NAME="var_data.$$"
LOGS_DIR_NAME="var_logs.$$"

for d in $DATA_DIR_NAME $LOGS_DIR_NAME; do
  if [ -d $d ]; then
    docker run --user 0:0 --rm \
      -v "$PWD/$d:/d" \
      bash -c "chown -R $(id -u):$(id -g) /d"
    rm -fr "$d"
  fi
  mkdir "$d"
  docker run --user 0:0 --rm \
    -v "$PWD/$d:/d" \
    bash -c "chown -R 8983:8983 /d"
done

container_cleanup "$container_name"

echo "Running $container_name"

docker run --name "$container_name" -d \
  -v "$PWD/$DATA_DIR_NAME:/var/solr/data" \
  -v "$PWD/$LOGS_DIR_NAME:/var/solr/logs" \
  -d "$tag" "solr-demo"

wait_for_server_started "$container_name"

echo "Checking data"
data=$(docker exec --user=solr "$container_name" wget -O - 'http://localhost:8983/solr/demo/select?q=id%3Adell')
if ! grep -E -q 'One Dell Way Round Rock, Texas 78682' <<<"$data"; then
  echo "Test $TEST_DIR $tag failed; data did not load"
  exit 1
fi
echo "Data loaded OK"

container_cleanup "$container_name"

echo "Checking data dir"
find "$DATA_DIR_NAME" -name demo -print | grep -q demo
find "$DATA_DIR_NAME" -name solr.xml -print | grep -q solr.xml
find "$DATA_DIR_NAME" -name zoo.cfg -print | grep -q zoo.cfg
echo "Checking logs dir"
find "$LOGS_DIR_NAME" -name solr.log -print | grep -q solr.log

docker run --user 0:0 --rm \
  -v "$PWD/$DATA_DIR_NAME:/data" \
  -v "$PWD/$LOGS_DIR_NAME:/logs" \
  bash -c "chown -R $(id -u):$(id -g) /data /logs"

rm -r "$DATA_DIR_NAME" "$LOGS_DIR_NAME"

echo "Test $TEST_DIR $tag succeeded"
