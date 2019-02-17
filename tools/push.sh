#!/bin/bash
#
# push images to Docker hub
#
# Usage: push.sh [ tags ]

set -euo pipefail

if [[ -n "${DEBUG:-}" ]]; then
  set -x
fi

function check_master {
  if [[ ${TRAVIS:-} = 'true' ]]; then
    for e in TRAVIS_BRANCH TRAVIS_COMMIT TRAVIS_PULL_REQUEST TRAVIS_PULL_REQUEST_BRANCH TRAVIS_PULL_REQUEST_SHA TRAVIS_REPO_SLUG; do
      eval "echo $e=\${$e}"
    done
    if [[ $TRAVIS_REPO_SLUG != 'dockersolr/docker-solr' ]]; then
      echo "Not pushing because this is not the dockersolr/docker-solr repo"
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
  if [[ -z "$DOCKER_USERNAME" ]]; then echo "DOCKER_USERNAME not set"; exit 1; fi
  if [[ -z "$DOCKER_PASSWORD" ]]; then echo "DOCKER_PASSWORD not set"; exit 1; fi
  docker login -u="$DOCKER_USERNAME" -p="$DOCKER_PASSWORD"
}

function push {
  tag=$1
  # The organisation on hub.docker.com is "dockersolr".
  # It should really have been "docker-solr" for consistency with the organisation
  # on github but currently dashes are not allowed, see https://github.com/docker/hub-feedback/issues/373
  # The hub user is "dockersolrbuilder".
  if grep -E -q '^dockersolr/docker-solr:' <<<"$tag"; then
    push_tag="$tag"
  else
    push_tag="dockersolr/docker-solr:$tag"
  fi
  # pushing to the docker registry sometimes fails, so retry
  local max_try=3
  local wait_seconds=15
  (( i=1 ))
  while true; do

    echo "Tagging $tag $push_tag"
    docker tag "$tag" "$push_tag"

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

check_master
login
for tag in "$@"; do
  push "$tag"
done
