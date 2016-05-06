#!/bin/bash
#
# Script to rebuild Solr images in this repository locally, and test them.
# This should probably be replaced with some bashbrew.

set -e

TAG_BASE=docker-solr/docker-solr

# The organisation on hub.docker.com is "dockersolr".
# It should really have been "docker-solr" for consistency with the organisation
# on github but currently dashes are not allowed, see https://github.com/docker/hub-feedback/issues/373
# The hub user is "dockersolrbuilder".
TAG_PUSH_BASE=dockersolr/docker-solr

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
  docker run --name $container_name -d $tag
  SLEEP_SECS=10
  echo "Sleeping $SLEEP_SECS seconds..."
  sleep $SLEEP_SECS
  echo "Checking Solr is running"
  status=$(docker exec $container_name /opt/docker-solr/scripts/wait-for-solr.sh)
  if ! egrep 'solr is running' <<<$status; then
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

function push {
  version=$1
  # pushing to the docker registry sometimes fails, so retry
  local max_try=3
  local wait_seconds=15
  docker tag $TAG_BASE:$version $TAG_PUSH_BASE:$version
  for (( i=1; i<=$max_try; i++ )); do
    echo "Pushing $TAG_PUSH_BASE:$version (attempt $i)"
    if docker push $TAG_PUSH_BASE:$version; then
      echo "Pushed $TAG_PUSH_BASE:$version"
      return
    else
      echo "Push $TAG_PUSH_BASE:$version failed; retrying in $wait_seconds seconds"
      sleep $wait_seconds
    fi
  done
}

function push_all {
  if [[ -z "$DOCKER_EMAIL" ]]; then echo "DOCKER_EMAIL not set"; exit 1; fi
  if [[ -z "$DOCKER_USERNAME" ]]; then echo "DOCKER_USERNAME not set"; exit 1; fi
  if [[ -z "$DOCKER_PASSWORD" ]]; then echo "DOCKER_PASSWORD not set"; exit 1; fi
  docker login -e="$DOCKER_EMAIL" -u="$DOCKER_USERNAME" -p="$DOCKER_PASSWORD"
  for version in $buildable ; do
    push "$version"
    for variant in $VARIANTS; do
      push "$version-$variant"
    done
  done
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
    push_all)
      push_all
      ;;
    *)
      echo "Unknown option $arg"
      exit 1
  esac
done
