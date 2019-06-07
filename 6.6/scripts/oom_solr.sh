#!/bin/bash

# This is just a wrapper to make it actually work in the start script - because
# the whitespaces of belows call cause havoc otherwise:
#. /opt/solr/bin/oom_solr.sh ${SOLR_PORT:-8983} /opt/solr/server/logs

SOLR_LOGS_DIR=/opt/solr/server/logs
SOLR_PID=`ps auxww | grep start.jar | grep -v grep | awk '{print $2}'`
if [[ -z "$SOLR_PID" ]]; then
  echo "Couldn't find Solr process running!"
  exit
fi

NOW=$(date +"%F_%H_%M_%S")
(
echo "Running OOM killer script for process $SOLR_PID for Solr"
kill -9 $SOLR_PID
echo "Killed process $SOLR_PID"
) | tee $SOLR_LOGS_DIR/solr_oom_killer-$SOLR_PORT-$NOW.log
