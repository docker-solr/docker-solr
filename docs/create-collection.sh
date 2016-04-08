#!/bin/bash
#
# A script that creates a core using Solr's 'create' command.
#
# To use this, map this file into your container's docker-entrypoint-initdb.d directory:
#
#     docker run -d -P -v $PWD/create-collection.sh:/docker-entrypoint-initdb.d/create-collection.sh solr
#
# Note: if all you want to do is create a core, the docker-entrypoint.sh can do that for you
# See the README.md for examples.

CORE=${CORE:-gettingstarted}
if [[ -d "/opt/solr/server/solr/$CORE" ]]; then
    echo "$CORE is already present on disk"
    exit 0
fi
OUTPUT=/opt/docker-solr/create-collection.log
echo "starting $0; logging to $OUTPUT"
{
    /opt/docker-solr/wait-for-solr.sh
    # Check if the core is already loaded.
    if wget -O - 'http://localhost:8983/solr/admin/cores' | grep '<str name="name">'$CORE'</str>'; then
        echo "$CORE is already present"
        exit 0
    fi
    echo creating $CORE core
    /opt/solr/bin/solr create -c $CORE
    echo created $CORE core
} </dev/null >$OUTPUT 2>&1 &
