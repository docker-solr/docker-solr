#!/bin/bash
#
# At docker build time, make everything group owned by root
# and make everything group writable.

set -euo pipefail

function fix_permissions {
  if [ ! -d "$1" ]; then
    return
  fi

  find -L "$1" \! -gid 0 -exec chgrp 0 {} \;
  # copy user permissions to group permissions
  find -L "$1" -perm /u+w -a \! -perm /g+w -exec chmod g+w {} \;
  find -L "$1" -perm /u+x -a \! -perm /g+x -exec chmod g+x {} \;
}

DIRS=(/opt/solr /opt/docker-solr \
    /docker-entrypoint-initdb.d /opt/mysolrhome)
for dir in "${DIRS[@]}"; do
  fix_permissions "$dir"
done
