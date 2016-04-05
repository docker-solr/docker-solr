#!/bin/bash
#
# Script to rebuild Solr images in this repository locally.
# This should probably be replaced with some bashbrew.

set -e

TAG_BASE=docker-solr/docker-solr

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

buildable=$(ls | grep -E '^[0-9]+\.[0-9]+$' | sort --version-sort)
latest=$(echo "$buildable" | tail -n 1)
for version in $buildable ; do
  dockerfile=$version/Dockerfile
  dockertag=$TAG_BASE:$version
  if [ ! -e $dockerfile ]; then
    echo "No $dockerfiles; skipping"
  else
    echo "BUILDING $dockerfile"
    fullVersion="$(grep -m1 'ENV SOLR_VERSION' "$dockerfile" | cut -d' ' -f3)"
    echo "Building: docker build --pull --rm=true --tag="$dockertag" - < $dockerfile"
    docker build --pull --rm=true --tag="$dockertag" - < $dockerfile
    if [ "$version" = "$latest" ]; then
      docker tag "$dockertag" "$TAG_BASE:latest"
    fi
  fi

  alpine_dockerfile=$version/alpine/Dockerfile
  alpine_dockertag=$TAG_BASE:$version-alpine
  if [ ! -e $alpine_dockerfile ]; then
    echo "No $alpine_dockerfile; skipping"
  else
    echo "BUILDING $alpine_dockerfile"
    fullVersion="$(grep -m1 'ENV SOLR_VERSION' "$alpine_dockerfile" | cut -d' ' -f3)"
    echo "Building: docker build --pull --rm=true --tag="$alpine_dockertag" - < $alpine_dockerfile"
    docker build --pull --rm=true --tag="$alpine_dockertag" - < $alpine_dockerfile
  fi
done
