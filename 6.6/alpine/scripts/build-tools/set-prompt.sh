#!/bin/bash
#
# At docker build time, set the bash prompt to either the username
# if known, or the user id, so it does not show the 'I have no name!'

set -euo pipefail

cat >> /etc/bash.bashrc <<'EOM'
# Added by docker-solr
PS1="$(id -un 2> /dev/null)"'@\h:\w\$ '
EOM
