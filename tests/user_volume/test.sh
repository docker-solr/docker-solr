#!/bin/bash
#
# A simple test of user volumes
#

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

if (( $# == 0 )); then
  echo "Usage: ${BASH_SOURCE[0]} tag"
  exit
fi

tag=$1

if [[ -n "${DEBUG:-}" ]]; then
  set -x
fi

if [[ "$(docker run -i "$tag" bash -c 'if test -d /var/solr; then echo yes; else echo no; fi' )" == "yes" ]]; then
  ./test-varsolr.sh "$tag"
else
  ./test-mycore.sh "$tag"
fi
