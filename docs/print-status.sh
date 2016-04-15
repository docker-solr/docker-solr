#!/bin/bash
#
# A script that saves Solr's status after starting.
#
# To use this, map this file into your container's docker-entrypoint-initdb.d directory:
#
#     docker run -d -P -v $PWD/print-status.sh:/docker-entrypoint-initdb.d/print-status.sh solr

OUTPUT=/opt/docker-solr/print-status-init.log
echo "starting $0; logging to $OUTPUT"
{
    /opt/docker-solr/scripts/wait-for-solr.sh
    /opt/solr/bin/solr status > /opt/docker-solr/status

} </dev/null >$OUTPUT 2>&1 &
