#!/bin/bash

# Custom oom handler but widely based on
# https://github.com/apache/lucene-solr/blob/master/solr/bin/oom_solr.sh

SOLR_PID=$(ps auxww | grep start.jar | grep -v grep | awk '{print $2}')
if [[ -z "$SOLR_PID" ]]; then
  echo "Couldn't find Solr process running!"
  exit
fi

NOW=$(date +"%F_%H_%M_%S")
(
echo "Running OOM killer script for process $SOLR_PID for Solr"
kill -9 "$SOLR_PID"
echo "Killed process $SOLR_PID"
) | tee "$SOLR_LOGS_DIR/solr_oom_killer-$SOLR_PORT-$NOW.log"
