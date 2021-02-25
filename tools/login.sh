#!/usr/bin/env bash
#
# logs into Docker hub
#
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

login
