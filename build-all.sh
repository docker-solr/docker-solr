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
  if [ ! -e $dockerfile ]; then
    echo "No $dockerfiles; skipping"
    continue
  fi
  echo "BUILDING $dockerfile"
  fullVersion="$(grep -m1 'ENV SOLR_VERSION' "$version/Dockerfile" | cut -d' ' -f3)"
  tags=("$TAG_BASE:$version")
  if [ "$version" = "$latest" ]; then
    tags+=("$TAG_BASE:latest")
  fi
  tag_args=("${tags[*]/#/--tag=}")
  docker build --pull --rm=true $tag_args - < $dockerfile
done
