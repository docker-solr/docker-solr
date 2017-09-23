#!/bin/bash
#
# Set a bash prompt to avoid the `I have no name!@827a7a2a34f4:/etc$ `
if ! id -un 2>/dev/null >/dev/null ; then
  PS1="$(id -un 2>/dev/null)"'@\h$ '
fi
