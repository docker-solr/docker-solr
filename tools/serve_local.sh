#!/usr/bin/env bash
#
# Creates an isolated DOCKER_NETWORK in which to run a small docker based webserver hosting the files
# in the 'downloads' directory on port 8083.  (See serve_local.py)
#
# Then executes the command lines args, wrapped with the following variables set...
#  - DOCKER_NETWORK="docker_solr_serve_local_network" (if name is not overriden by our ENV) 
#  - SOLR_DOWNLOAD_SERVER="http://docker_solr_serve_local_httpd:9999/" (will be resolvable in our DOCKER_NETWORK)
# Once the wrapped command finishes, the webserver container & DOCKER_NETWORK will be removed
# 
# Examples:
#    ./tools/serve_local.sh tools/build_all.sh
#    ./tools/serve_local.sh tools/build.sh 8.7
#

TOP_DIR="$(readlink -f "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/..")"

if (( $# == 0 )); then
  echo "Usage: $0 some_build_command build-args"
  exit 1
fi

PROCESS_STATUS=-1

NETWORK_STATUS=0
NETWORK_ID=''
HTTPD_NODE_STATUS=0
HTTPD_NODE_ID=''

if [[ -z "${DOCKER_NETWORK:-}" ]]; then
  DOCKER_NETWORK=docker_solr_serve_local_network
fi

function cleanup_and_exit() {
  echo "Cleaning up docker HTTPD server and network..."
  if [[ ! -z "${HTTPD_NODE_ID:-}" ]]; then
    docker stop $HTTPD_NODE_ID
    HTTPD_NODE_STATUS=$?
    if (( 0 != $HTTPD_NODE_STATUS )); then
      echo "Failed to stop local HTTP server, id: $HTTPD_NODE_ID"
      PROCESS_STATUS=$HTTPD_NODE_STATUS
    fi
  fi
  if [[ ! -z "${NETWORK_ID:-}" ]]; then
    docker network rm $DOCKER_NETWORK
    NETWORK_STATUS=$?
    if (( 0 != $NETWORK_STATUS )); then
      echo "Failed to rm docker network $DOCKER_NETWORK"
      PROCESS_STATUS=$NETWORK_STATUS
    fi
  fi
  exit $PROCESS_STATUS
}
trap cleanup_and_exit INT


NETWORK_ID=$(docker network create $DOCKER_NETWORK)
NETWORK_STATUS=$?
if (( 0 != $NETWORK_STATUS )); then
  PROCESS_STATUS=$NETWORK_STATUS
  echo "Failed to create docker network $DOCKER_NETWORK"
  cleanup_and_exit
fi

# NOTE: we choose to use network-alias rather then a name for this container, so that our
# 'host name' is isolated to the DOCKER_NETWORK.
HTTPD_NODE_ID=$(docker run --rm -d --network $DOCKER_NETWORK --network-alias docker_solr_serve_local_httpd -v $TOP_DIR/downloads:/downloads -v $TOP_DIR/tools:/tools -w / 'python:3-alpine' /tools/serve_local.py)

HTTPD_NODE_STATUS=$?
if (( 0 != $HTTPD_NODE_STATUS )); then
  PROCESS_STATUS=$HTTPD_NODE_STATUS
  echo "Failed to start local HTTP server"
  cleanup_and_exit
fi

# now run our 'inner' process...
DOCKER_NETWORK=$DOCKER_NETWORK SOLR_DOWNLOAD_SERVER="http://docker_solr_serve_local_httpd:8083/" "$@"
PROCESS_STATUS=$?

cleanup_and_exit
