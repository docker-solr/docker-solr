#!/bin/bash
#
# Shared functions for testing

function container_cleanup {
  local container_name=$1
  previous=$(docker inspect "$container_name" --format '{{.ID}}' || true)
  if [[ -n $previous ]]; then
    container_status=$(docker inspect --format='{{.State.Status}}' "$previous")
    if [[ $container_status == 'running' ]]; then
      echo "killing $previous"
      docker kill "$previous" || true
      sleep 2
    fi
    echo "removing $previous"
    docker rm "$previous" || true
  fi
}

function wait_for_container_and_solr {
  local container_name=$1
  TIMEOUT_SECONDS=$(( 5 * 60 ))
  started=$(date +%s)
  while /bin/true; do
    if (( $(date +%s) > started + TIMEOUT_SECONDS )); then
      echo "giving up after $TIMEOUT_SECONDS seconds"
      exit 1
    fi
    if ! docker inspect "$container_name" >/dev/null 2>&1; then
      sleep 1
      continue;
    fi
    container_status=$(docker inspect --format='{{.State.Status}}' "$container_name")
    if [[ $container_status == 'running' ]]; then
      break
    elif [[ $container_status == 'exited' ]]; then
      echo "container $container_name status: $container_status"
      docker logs "$container_name"
      exit 1
    else
      echo "container $container_name status: $container_status"
    fi
    printf '.'
    SLEEP_SECS=1
    sleep $SLEEP_SECS
  done

  printf '\nChecking Solr is running\n'
  status=$(docker exec "$container_name" /opt/docker-solr/scripts/wait-for-solr.sh --max-attempts 60 --wait-seconds 1)
  if ! grep -E -q 'solr is running' <<<"$status"; then
    echo "solr did not start"
    container_cleanup "$container_name"
    exit 1
  fi
}

function wait_for_server_started {
  local container_name=$1
  echo "waiting for server start"
  TIMEOUT_SECONDS=$(( 5 * 60 ))
  started=$(date +%s)
  while true; do
    log="tmp-${container_name}.log"
    docker logs "$container_name" > "$log" 2>&1
    if grep -E -q '(o\.e\.j\.s\.Server Started|Started SocketConnector)' "$log" ; then
      break
    fi

    container_status=$(docker inspect --format='{{.State.Status}}' "$container_name")
    if [[ $container_status == 'exited' ]]; then
      echo "container exited"
      exit 1
    fi

    if (( $(date +%s) > started + TIMEOUT_SECONDS )); then
      echo "giving up after $TIMEOUT_SECONDS seconds"
      exit 1
    fi
    printf '.'
    SLEEP_SECS=2
    sleep $SLEEP_SECS
  done
  printf '\nserver started\n'
  rm "$log"
  sleep 4
}
