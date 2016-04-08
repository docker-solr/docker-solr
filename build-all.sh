#!/bin/bash
#
# Script to rebuild Solr images in this repository locally.
# This should probably be replaced with some bashbrew.

set -e

TAG_BASE=docker-solr/docker-solr

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
   fullVersion="$(grep -m1 'ENV SOLR_VERSION' Dockerfile | cut -d' ' -f3)"
   docker build --pull --rm=true --tag="$docker_tag" --build-arg SOLR_DOWNLOAD_SERVER=$SOLR_DOWNLOAD_SERVER .
  )
  echo "tagged $docker_tag"
}

buildable=$(ls | grep -E '^[0-9]+\.[0-9]+$' | sort --version-sort)
latest=$(echo "$buildable" | tail -n 1)
for version in $buildable ; do
    build $version
    build $version 'alpine'
    if [ "$version" = "$latest" ]; then
        docker tag "$TAG_BASE:$version" "$TAG_BASE:latest"
        echo "tagged $TAG_BASE:latest"
    fi
done
