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

container_cleanup "$container_name"

echo "Running $container_name"
if [ -d mysolrhome ]; then
  docker run --rm -v "$PWD/mysolrhome:/mysolrhome" "$tag" bash -c "rm -fr /mysolrhome/*"
  rm -fr mysolrhome
fi

mkdir mysolrhome
chmod a+w mysolrhome
docker run --name "$container_name" -d -v "$PWD/mysolrhome:/mysolrhome" -e SOLR_HOME=/mysolrhome -e INIT_SOLR_HOME=yes -d "$tag" "solr-demo"

wait_for_server_started "$container_name"

echo "Checking data"
data=$(docker exec --user=solr "$container_name" wget -O - 'http://localhost:8983/solr/demo/select?q=address_s%3ARound%20Rock')
if ! egrep -q 'One Dell Way Round Rock, Texas 78682' <<<$data; then
  echo "Test test_simple $tag failed; data did not load"
  exit 1
fi
echo "Data loaded OK"

container_cleanup "$container_name"

docker run --rm -v "$PWD/mysolrhome:/mysolrhome" "$tag" bash -c "rm -fr /mysolrhome/*"
rmdir mysolrhome

echo "Test $BASH_SOURCE $tag succeeded"
