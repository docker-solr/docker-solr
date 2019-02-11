#!/bin/bash
set -euo pipefail
TOP_DIR="$(cd "$(dirname "$BASH_SOURCE")/.."; echo "$PWD")"
cd "$TOP_DIR"
docker run -it \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v "$PWD:$PWD" \
  --user "root" \
  -w "$PWD" dockersolr/builder bash "$@"
if find "$PWD" -user root >/dev/null 2>&1; then
  echo "chowning $PWD"
  sudo chown -R "$(id -u):$(id -g)" "$PWD"
fi
