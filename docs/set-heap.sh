#!/bin/bash
set -e
cp /opt/solr/bin/solr.in.sh /opt/solr/bin/solr.in.sh.orig
sed -e 's/SOLR_HEAP=".*"/SOLR_HEAP="1024m"/' </opt/solr/bin/solr.in.sh.orig >/opt/solr/bin/solr.in.sh
grep '^SOLR_HEAP=' /opt/solr/bin/solr.in.sh
