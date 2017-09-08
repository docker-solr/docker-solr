#!/bin/bash
#
# Write a Travis config file

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")/.."

cat <<EOM
sudo: required

language: generic

services:
- docker

before_install:
- docker info

jobs:
  include:
EOM

build_dirs=$(find . -name Dockerfile -exec dirname {} \; | sort --version-sort --reverse)
for d in $build_dirs; do
  d=$(sed 's,^\./,,' <<<$d)
  echo '    - stage: build, test, deploy'
  # set the PROCESS variable just so that its value show up in the Travis UI
  echo '      env:'
  echo "      - PROCESS=$d"
  echo "      script: tools/build_test_push.sh $d"
done
