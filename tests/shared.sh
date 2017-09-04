#!/bin/bash
#
# Shared functions for testing

TAG_LOCAL_BASE=docker-solr/docker-solr

function container_cleanup {
  local container_name=$1
  previous=$(docker ps --filter name="$container_name" --format '{{.ID}}' --no-trunc)
  if [[ ! -z $previous ]]; then
    echo "killing $container_name"
    docker kill "$container_name" || true
    sleep 2
    echo "removing $container_name"
    docker rm "$container_name" || true
  fi
}
