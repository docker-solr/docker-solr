#!/bin/bash
set -euo pipefail

SOLR_URL=$1
SOLR_SHA256=$2

mkdir -p /opt/solr
echo "downloading $SOLR_URL"
wget -nv "$SOLR_URL" -O /opt/solr.tgz
echo "downloading $SOLR_URL.asc"
wget -nv "$SOLR_URL.asc" -O /opt/solr.tgz.asc
echo "$SOLR_SHA256 */opt/solr.tgz" | sha256sum -c -
(>&2 ls -l /opt/solr.tgz /opt/solr.tgz.asc)
gpg --batch --verify /opt/solr.tgz.asc /opt/solr.tgz

tar -C /opt/solr --extract --file /opt/solr.tgz --strip-components=1
rm /opt/solr.tgz*
rm -Rf /opt/solr/docs/
mkdir -p /opt/solr/server/solr/lib /opt/solr/server/solr/mycores /opt/solr/server/logs /docker-entrypoint-initdb.d /opt/docker-solr /opt/mysolrhome

sed -i -e 's/"\$(whoami)" == "root"/$(id -u) == 0/' /opt/solr/bin/solr
sed -i -e 's/lsof -PniTCP:/lsof -t -PniTCP:/' /opt/solr/bin/solr
sed -i -e '/-Dsolr.clustering.enabled=true/ a SOLR_OPTS="$SOLR_OPTS -Dsun.net.inetaddr.ttl=60 -Dsun.net.inetaddr.negative.ttl=60"' /opt/solr/bin/solr.in.sh

