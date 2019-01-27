#!/bin/bash
set -euo pipefail
TOP_DIR="$(cd "$(dirname "$BASH_SOURCE")/.."; echo "$PWD")"
cd "$TOP_DIR"
docker run -it \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v "$PWD:$PWD" \
  --user "$(id -u):$(id -g)" \
  -w "$PWD" dockersolr/builder bash "$@"
