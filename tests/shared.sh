#!/bin/bash
#
# Shared functions for testing

function container_cleanup {
  local container_name=$1
  previous=$(docker ps --all --filter name="$container_name" --format '{{.ID}}' --no-trunc)
  if [[ ! -z $previous ]]; then
    container_status=$(docker inspect --format='{{.State.Status}}' "$container_name")
    if [[ $container_status == 'running' ]]; then
      echo "killing $container_name"
      docker kill "$container_name" || true
      sleep 2
    fi
    echo "removing $container_name"
    docker rm "$container_name" || true
  fi
}

function wait_for_container_and_solr {
  local container_name=$1
  while /bin/true; do
    if ! docker inspect "$container_name" >/dev/null 2>&1; then
      sleep 1
      continue;
    fi
    container_status=$(docker inspect --format='{{.State.Status}}' "$container_name")
    echo "container $container_name status: $container_status"
    if [[ $container_status == 'running' ]]; then
      break
    elif [[ $container_status == 'exited' ]]; then
      docker logs "$container_name"
      exit 1
    fi
    SLEEP_SECS=1
    echo "sleeping $SLEEP_SECS seconds..."
    sleep $SLEEP_SECS
  done

  echo "Checking Solr is running"
  status=$(docker exec "$container_name" /opt/docker-solr/scripts/wait-for-solr.sh --max-attempts 60 --wait-seconds 1)
  if ! egrep -q 'solr is running' <<<$status; then
    echo "solr did not start"
    container_cleanup "$container_name"
    exit 1
  fi
}

function wait_for_server_started {
  local container_name=$1
  echo "waiting for server start"
  while ! (docker logs "$container_name" | grep -q 'o.e.j.s.Server Started'); do
    SLEEP_SECS=2
    echo "sleeping $SLEEP_SECS seconds..."
    sleep $SLEEP_SECS
  done
  echo "server started"
  sleep 2
}
