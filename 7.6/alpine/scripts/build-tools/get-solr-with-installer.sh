#!/bin/bash
set -euo pipefail
set -x
SOLR_URL=$1
SOLR_SHA256=$2

SOLR_VERSION="$(echo "$SOLR_URL" | sed -E -e 's,^.*/,,' -e 's/solr-//' -e 's/\.tgz//' )"
SOLR_TGZ="solr-$SOLR_VERSION.tgz"

mkdir -p /opt/
cd /opt/

echo "downloading $SOLR_URL"
wget -nv "$SOLR_URL" -O "$SOLR_TGZ"
echo "downloading $SOLR_URL.asc"
wget -nv "$SOLR_URL.asc" -O "/opt/$SOLR_TGZ.asc"
echo "$SOLR_SHA256 */opt/$SOLR_TGZ" | sha256sum -c -
(>&2 ls -l "$SOLR_TGZ" "$SOLR_TGZ.asc")

export GNUPGHOME="/tmp/gnupg_home"
mkdir -p "$GNUPGHOME"
chmod 700 "$GNUPGHOME"
echo "disable-ipv6" >> "$GNUPGHOME/dirmngr.conf"

gpgconf --kill all
gpg --batch --verify "$SOLR_TGZ.asc" "$SOLR_TGZ"

# see https://lucene.apache.org/solr/guide/7_6/taking-solr-to-production.html#run-the-solr-installation-script

tar --extract --file "$SOLR_TGZ" "solr-$SOLR_VERSION/bin/install_solr_service.sh" --strip-components=2
./install_solr_service.sh "$SOLR_TGZ" -n

rm "$SOLR_TGZ" "$SOLR_TGZ.asc" install_solr_service.sh

mkdir -p /docker-entrypoint-initdb.d \
    /opt/docker-solr
# mkdir -p /opt/solr/server/solr/lib /opt/solr/server/logs /opt/mysolrhome
# mkdir -p /opt/solr/server/solr/mycores

cd /opt/solr
# work around https://issues.apache.org/jira/browse/SOLR-13087
sed -i -e "s/\"\$(whoami)\" == \"root\"/\$(id -u) == 0/" /opt/solr/bin/solr || echo "whoami change failed"

# work around https://issues.apache.org/jira/browse/SOLR-13089
sed -i -e 's/lsof -PniTCP:/lsof -t -PniTCP:/' /opt/solr/bin/solr || echo "lsof change failed"

# https://github.com/docker-solr/docker-solr/issues/199
sed -i -e "/-Dsolr.clustering.enabled=true/ a SOLR_OPTS=\"\$SOLR_OPTS -Dsun.net.inetaddr.ttl=60 -Dsun.net.inetaddr.negative.ttl=60\"" /opt/solr/bin/solr.in.sh || echo "inetaddr tll changes failed"

chown -R solr:solr /docker-entrypoint-initdb.d /opt/docker-solr
