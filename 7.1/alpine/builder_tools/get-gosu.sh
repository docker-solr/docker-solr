#!/bin/bash
set -euo pipefail
gosu_version=$1
dpkgArch="$(dpkg --print-architecture | awk -F- '{ print $NF }')"
wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$gosu_version/gosu-$dpkgArch"
wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$gosu_version/gosu-$dpkgArch.asc"
gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu
rm /usr/local/bin/gosu.asc
chmod +x /usr/local/bin/gosu
gosu --version
gosu nobody true
