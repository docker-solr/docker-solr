#!/bin/bash
#
# A helper script to wait for solr
set -x
until $(wget -O - http://localhost:8983 | grep -q -i solr); do
  echo "solr is not running yet"
  sleep 5
done
echo "solr is running"
