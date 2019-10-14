#!/bin/bash
#
# A helper script to wait for ZooKeeper
#
# This script waits for a ZooKeeper master to appear.
# It repeatedly looks up the name passed as argument
# in the DNS using getent, and then connects to the
# ZooKeeper admin port and uses the 'srvr' command to
# obtain the server's status.
# You can use this in a Kubernetes init container to
# delay Solr pods starting until the ZooKeeper service
# has settled down. Or you could explicitly run this in
# the Solr container before exec'ing Solr.
#
# Inspired by https://github.com/helm/charts/blob/9eba7b1c80990233a68dce48f4a8fe0baf9b7fa5/incubator/solr/templates/statefulset.yaml#L60
#
# Usage: wait-for-zookeeper.sh [--max-attempts count] [--wait-seconds seconds] zookeeper-service-name

set -euo pipefail

SCRIPT="$0"

if [[ "${VERBOSE:-}" == "yes" ]]; then
    set -x
fi

function usage {
  echo "$1"
  echo "Usage: $SCRIPT [--max-attempts count] [--wait-seconds seconds ] zookeeper-service-name"
  exit 1
}

TMP_HOSTS="/tmp/hosts.$$"
TMP_STATUS="/tmp/status.$$"

function cleanup {
    rm -f $TMP_HOSTS $TMP_STATUS
}

trap cleanup EXIT

function check_zookeeper {
    local host=$1
    if ! echo srvr | nc "$host" 2181 > $TMP_STATUS; then
        echo "Failed to get status from $host"
        return
    fi
    if [ ! -s $TMP_STATUS ]; then
        echo "No data from $ip"
        return
    fi
    if grep -q 'not currently serving requests' $TMP_STATUS; then
        echo "Node $ip is not currently serving requests"
        return
    fi
    mode=$(grep "Mode: " $TMP_STATUS | sed 's/Mode: //');
    if [ -z "$mode" ]; then
        echo "Cannot determine mode from:"
        cat $TMP_STATUS
        return
    fi
    echo "Node $ip is a $mode"
    if [ "$mode" = "leader" ] || [ "$mode" = "standalone" ]; then
        echo "Done"
        exit 0
    fi
}

max_attempts=120
wait_seconds=2
while (( $# > 0 )); do
  case "$1" in
   --help)
     cat <<EOM
Usage: $SCRIPT [options] zookeeper-service-name

Options:
  --max-attempts count: number of attempts to check Solr is up. Default: $max_attempts
  --wait-seconds seconds: number of seconds to wait between attempts. Default: $wait_seconds
EOM
     exit 0
     ;;

   --max-attempts)
     max_attempts="$2";
     shift 2;
     ;;

   --wait-seconds)
     wait_seconds="$2";
     shift 2;
     ;;

   *)
    if [ -n "${lookup:-}" ]; then
      usage "Cannot specify multiple zookeeper service names"
    fi
    lookup=$1;
    shift;
    break;
    ;;

  esac
done

grep -q -E '^[0-9]+$' <<<"$max_attempts" || usage "--max-attempts $max_attempts: not a number"
if (( max_attempts == 0 )); then
  echo "The --max-attempts argument should be >0"
  exit 1
fi
grep -q -E '^[0-9]+$' <<<"$wait_seconds" || usage "--wait-seconds $wait_seconds: not a number"

if [ -z "${lookup:-}" ]; then
  lookup=solr-zookeeper-headless
fi

echo "Looking up '$lookup'"
((attempts_left=max_attempts))
while (( attempts_left > 0 )); do
  if getent hosts "$lookup" > $TMP_HOSTS; then
    while read -r ip host ; do
      check_zookeeper "$ip"
    done <$TMP_HOSTS
  else
    echo "Cannot find $lookup yet"
  fi
  (( attempts_left-- ))
  if (( attempts_left == 0 )); then
    echo "Still no master found; giving up"
    exit 1
  fi
  sleep "$wait_seconds"
done
