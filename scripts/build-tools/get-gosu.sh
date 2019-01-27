#!/bin/bash
set -euo pipefail
gosu_version=$1
if [ -f /sbin/apk ]; then
    dpkgArch="$(apk --print-arch | sed 's/x86_64/amd64/' | sed 's/aarch64/arm64/')"
elif [ -f /usr/bin/dpkg ]; then
    dpkgArch="$(dpkg --print-architecture | awk -F- '{ print $NF }')"
else
    echo "What OS is this?"
    exit 1
fi
wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$gosu_version/gosu-$dpkgArch"
wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$gosu_version/gosu-$dpkgArch.asc"
export GNUPGHOME="/tmp/gnupg_home"
gpgconf --kill all
gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu
rm /usr/local/bin/gosu.asc
chmod +x /usr/local/bin/gosu
gosu --version
gosu nobody true
