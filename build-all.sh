#!/bin/bash
#
# Script to rebuild Solr images in this repository locally, and test them.
# This should probably be replaced with some bashbrew.

set -e

TAG_BASE=docker-solr/docker-solr

VARIANTS="alpine"

# Override with e.g.: export SOLR_DOWNLOAD_SERVER=http://www-eu.apache.org/dist/lucene/solr
SOLR_DOWNLOAD_SERVER=${SOLR_DOWNLOAD_SERVER:-'http://www-us.apache.org/dist/lucene/solr'}

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

function build {
  local version=$1
  local variant=$2

  if [[ -z $variant ]]; then
    build_dir="$version"
    docker_tag=$TAG_BASE:$version
  else
    build_dir="$version/$variant"
    docker_tag=$TAG_BASE:$version-$variant
  fi
  echo "BUILDING in $build_dir for $docker_tag"
  (cd $build_dir
   echo "building $docker_tag in $PWD:"
   echo "  docker build --pull --rm=true --tag="$docker_tag" --build-arg SOLR_DOWNLOAD_SERVER=$SOLR_DOWNLOAD_SERVER ."
   docker build --pull --rm=true --tag="$docker_tag" --build-arg SOLR_DOWNLOAD_SERVER=$SOLR_DOWNLOAD_SERVER .
  )
  echo "tagged $docker_tag"
}

# A simple kick-the-tires test to verify that the images
# run as containers, start Solr, and can load some data
function test_simple {
  local tag=$1
  echo "Test $tag"
  container_name='test_'$(echo $tag|tr ':/-' '_')
  echo "Running $container_name"
  docker run --name $container_name -d -v $PWD/docs/print-status.sh:/docker-entrypoint-initdb.d/print-status.sh $tag
  SLEEP_SECS=10
  echo "Sleeping $SLEEP_SECS seconds..."
  sleep $SLEEP_SECS
  echo "Checking Status"
  status=$(docker exec $container_name cat /opt/docker-solr/status)
  if ! egrep 'Solr process .* running on port 8983' <<<$status; then
    echo "Test test_simple $tag failed; solr did not start"
    exit 1
  fi
  echo "Creating core"
  docker exec -it --user=solr $container_name bin/solr create_core -c gettingstarted
  echo "Loading data"
  docker exec -it --user=solr $container_name bin/post -c gettingstarted example/exampledocs/manufacturers.xml
  sleep 1
  echo "Checking data"
  data=$(docker exec -it --user=solr $container_name wget -O - http://localhost:8983/solr/gettingstarted/select'?q=*:*')
  if ! egrep 'Round Rock' <<<$data; then
    echo "Test test_simple $tag failed; data did not load"
    exit 1
  fi
  echo "Cleaning up"
  docker kill $container_name
  sleep 2
  docker rm $container_name

  echo "Test test_simple $tag succeeded"
}

buildable=$(ls | grep -E '^[0-9]+\.[0-9]+$' | sort --version-sort)
latest=$(echo "$buildable" | tail -n 1)

docker info

function tag_latest {
  local version=$1
  if [ "$version" = "$latest" ]; then
    docker tag "$TAG_BASE:$version" "$TAG_BASE:latest"
    echo "tagged $TAG_BASE:latest"
  fi
}

function build_all {
  for version in $buildable ; do
    build $version
    for variant in $VARIANTS; do
      build $version $variant
    done
    tag_latest $version
  done
}

function build_latest {
  build $latest
  tag_latest $latest
}

function test_all {
  for version in $buildable ; do
    test_simple "$TAG_BASE:$version"
    for variant in $VARIANTS; do
      test_simple "$TAG_BASE:$version-$variant"
    done
  done
}

function test_latest {
  test_simple "$TAG_BASE:latest"
}

if [[ $# -eq 0 ]] ; then
  args="build_all"
else
  args="$@"
fi
for arg in $args; do
  case $arg in
    build_all)
      build_all
      ;;
    test_all)
      test_all
      ;;
    build_latest)
      build_latest
      ;;
    test_latest)
      test_latest
      ;;
    *)
      echo "Unknown option $arg"
      exit 1
  esac
done
