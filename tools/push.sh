#!/bin/bash
#
# push images to Docker hub
#
# Usage: push.sh image
# E.g.: push.sh dockersolr/docker-solr:8.2.0-slim

set -euo pipefail

if [[ -n "${DEBUG:-}" ]]; then
  set -x
fi

GITHUB_REPO='docker-solr/docker-solr'
# The organisation on hub.docker.com is "dockersolr".
# It should really have been "docker-solr" for consistency with the github organisation
# but currently dashes are not allowed, see https://github.com/docker/hub-feedback/issues/373
# The hub user is "dockersolrbuilder".
IMAGE_NAME='dockersolr/docker-solr'

function check_master {
  if [[ ${TRAVIS:-} = 'true' ]]; then
    for e in TRAVIS_BRANCH TRAVIS_COMMIT TRAVIS_PULL_REQUEST TRAVIS_PULL_REQUEST_BRANCH TRAVIS_PULL_REQUEST_SHA TRAVIS_REPO_SLUG; do
      eval "echo $e=\${$e}"
    done
    if [[ $TRAVIS_REPO_SLUG != "$GITHUB_REPO" ]]; then
      echo "Not pushing because this is not the $GITHUB_REPO repo"
      exit 0
    fi
    if [[ $TRAVIS_PULL_REQUEST != 'false' ]]; then
      echo "Not pushing because this is a pull request"
      exit 0
    elif [[ $TRAVIS_BRANCH != 'master' ]]; then
      echo "Not pushing because this is not the master branch"
      exit 0
    fi
  fi
}

function login {
  # To make it easier to use this script locally, try determine if you are already logged in.
  # I don't know how supported/permanent this is; I notice that if you use "--format '{{json .}}'"
  # this does not show up.
  if docker system info 2>&1 |grep -E '^ *Username: '; then
      echo "You appear to be already logged in"
      return
  fi
  if [[ -z "$DOCKER_USERNAME" ]]; then echo "DOCKER_USERNAME not set"; exit 1; fi
  if [[ -z "$DOCKER_PASSWORD" ]]; then echo "DOCKER_PASSWORD not set"; exit 1; fi
  docker login -u "$DOCKER_USERNAME" --password-stdin <<<"$DOCKER_PASSWORD"
}

function push {
  push_tag=$1
  # pushing to the docker registry sometimes fails, so retry
  local max_try=3
  local wait_seconds=15
  (( i=1 ))
  while true; do

    echo "Pushing $push_tag (attempt $i)"
    if docker push "$push_tag"; then
      echo "Pushed $push_tag"
      return
    else
      echo "Push $push_tag attempt $i failed"
      if (( i == max_try )); then
        echo "Failed to push $push_tag in $max_try attempts; giving up"
        exit 1
      else
        echo "retrying in $wait_seconds seconds"
        sleep "$wait_seconds"
      fi
    fi
    (( i++  ))
  done
}

image="$1"
if ! grep -E -q "^$IMAGE_NAME:" <<<"$image"; then
  echo "The image name does not start with $IMAGE_NAME"
  exit 1
fi
check_master
login
push "$1"
