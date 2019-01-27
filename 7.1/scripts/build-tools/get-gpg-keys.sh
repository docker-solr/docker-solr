#!/bin/bash
set -euo pipefail

export GNUPGHOME="/tmp/gnupg_home"
mkdir -p "$GNUPGHOME"
chmod 700 "$GNUPGHOME"

echo "disable-ipv6" >>  "$GNUPGHOME/dirmngr.conf"

for key in "${@}"; do
    found=''
    for server in \
      ha.pool.sks-keyservers.net \
      hkp://keyserver.ubuntu.com:80 \
      hkp://p80.pool.sks-keyservers.net:80 \
      pgp.mit.edu \
    ; do
      echo "  trying $server for $key"
      gpg --batch --keyserver "$server" --keyserver-options timeout=10 --recv-keys "$key" && found=yes && break
      gpg --batch --keyserver "$server" --keyserver-options timeout=10 --recv-keys "$key" && found=yes && break
    done
    test -z "$found" && echo >&2 "error: failed to fetch $key from several disparate servers -- network issues?" && exit 1
done
exit 0

