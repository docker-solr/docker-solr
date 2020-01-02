#!/usr/bin/env bash
#
# Write a Travis config file

cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." || exit 1

cat <<EOM
dist: xenial

sudo: required

language: generic

services:
- docker

addons:
  apt:
    packages:
      - docker-ce

before_install:
- docker info

jobs:
  include:
EOM

build_dirs=$(find . -name Dockerfile -exec dirname {} \; | sort --version-sort --reverse | sed 's,^\./,,' | grep -E '^[0-9]\.[0-9]')
for d in $build_dirs; do
  echo '    - stage: build, test, deploy'
  # set the PROCESS variable just so that its value show up in the Travis UI
  echo '      env:'
  echo "      - PROCESS=$d"
  echo "      script: tools/build_test_push.sh $d"
done
