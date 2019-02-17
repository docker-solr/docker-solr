#!/bin/bash
set -euo pipefail
TOP_DIR="$(cd "$(dirname "$BASH_SOURCE")/.."; echo "$PWD")"
cd "$TOP_DIR/builder"
docker build -t dockersolr/builder .
