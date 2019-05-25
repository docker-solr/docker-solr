#!/bin/bash
# Report which FROM lines in Dockerfiles rely on tags that no longer exist
set -euo pipefail
cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.."
wget -q -O openjdk-tags.tmp https://raw.githubusercontent.com/docker-library/official-images/master/library/openjdk
grep -E '^(Tags|SharedTags): ' openjdk-tags.tmp | sed -E 's/^(Tags|SharedTags): //' | sed 's/,/ /g' | sed -E 's/ +/ /g' | tr '[:space:]' '\n' | sort  | uniq > openjdk-tags
grep -E '^FROM openjdk:' ./*/Dockerfile ./*/*/Dockerfile | sed 's/^.*:FROM openjdk://' | sort | uniq > solr-from
comm -2 -3 solr-from openjdk-tags | sort | uniq > bad-froms
if [ -s bad-froms ]; then
  echo "bad FROMs spotted:"
  rm -f bad-files
  while read -r tag; do
    grep -E "^FROM openjdk:$tag" ./*/Dockerfile ./*/*/Dockerfile >> bad-files
  done < bad-froms
  sort bad-files
  result=fail
else
  result=ok
fi
rm -f openjdk-tags.tmp openjdk-tags solr-from bad-froms bad-files
if [[ $result == fail ]]; then
  exit 1
fi
