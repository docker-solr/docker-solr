
FROM openjdk:11-jre-slim

LABEL maintainer="Martijn Koster \"mak-docker@greenhills.co.uk\""
LABEL repository="https://github.com/docker-solr/docker-solr"

ARG SOLR_VERSION="7.7.3"
ARG SOLR_SHA512="ca9200c18cc19ab723fd4d10f257e27eb81dc8bc33401ebc4eb99178faf4033a2684f0f8b12ae7b659cfeb0f4c9d9e24aaac518a4e00fd28b69854a359a666ed"
ARG SOLR_KEYS="CFCE5FBB920C3C745CEEE084C38FF5EC3FCFDB3E"
# If specified, this will override SOLR_DOWNLOAD_SERVER and all ASF mirrors. Typically used downstream for custom builds
ARG SOLR_DOWNLOAD_URL

# Override the solr download location with e.g.:
#   docker build -t mine --build-arg SOLR_DOWNLOAD_SERVER=http://www-eu.apache.org/dist/lucene/solr .
ARG SOLR_DOWNLOAD_SERVER

RUN set -ex; \
  apt-get update; \
  apt-get -y install acl dirmngr gpg lsof procps wget netcat gosu tini; \
  rm -rf /var/lib/apt/lists/*

ENV SOLR_USER="solr" \
    SOLR_UID="8983" \
    SOLR_GROUP="solr" \
    SOLR_GID="8983" \
    SOLR_CLOSER_URL="http://www.apache.org/dyn/closer.lua?filename=lucene/solr/$SOLR_VERSION/solr-$SOLR_VERSION.tgz&action=download" \
    SOLR_DIST_URL="https://www.apache.org/dist/lucene/solr/$SOLR_VERSION/solr-$SOLR_VERSION.tgz" \
    SOLR_ARCHIVE_URL="https://archive.apache.org/dist/lucene/solr/$SOLR_VERSION/solr-$SOLR_VERSION.tgz" \
    PATH="/opt/solr/bin:/opt/docker-solr/scripts:$PATH"

RUN set -ex; \
  groupadd -r --gid "$SOLR_GID" "$SOLR_GROUP"; \
  useradd -r --uid "$SOLR_UID" --gid "$SOLR_GID" "$SOLR_USER"

RUN set -ex; \
  export GNUPGHOME="/tmp/gnupg_home"; \
  mkdir -p "$GNUPGHOME"; \
  chmod 700 "$GNUPGHOME"; \
  echo "disable-ipv6" >> "$GNUPGHOME/dirmngr.conf"; \
  for key in $SOLR_KEYS; do \
    found=''; \
    for server in \
      ha.pool.sks-keyservers.net \
      hkp://keyserver.ubuntu.com:80 \
      hkp://p80.pool.sks-keyservers.net:80 \
      pgp.mit.edu \
    ; do \
      echo "  trying $server for $key"; \
      gpg --batch --keyserver "$server" --keyserver-options timeout=10 --recv-keys "$key" && found=yes && break; \
      gpg --batch --keyserver "$server" --keyserver-options timeout=10 --recv-keys "$key" && found=yes && break; \
    done; \
    test -z "$found" && echo >&2 "error: failed to fetch $key from several disparate servers -- network issues?" && exit 1; \
  done; \
  exit 0

RUN set -ex; \
  export GNUPGHOME="/tmp/gnupg_home"; \
  MAX_REDIRECTS=1; \
  if [ -n "$SOLR_DOWNLOAD_URL" ]; then \
    # If a custom URL is defined, we download from non-ASF mirror URL and allow more redirects and skip GPG step
    # This takes effect only if the SOLR_DOWNLOAD_URL build-arg is specified, typically in downstream Dockerfiles
    MAX_REDIRECTS=4; \
    SKIP_GPG_CHECK=true; \
  elif [ -n "$SOLR_DOWNLOAD_SERVER" ]; then \
    SOLR_DOWNLOAD_URL="$SOLR_DOWNLOAD_SERVER/$SOLR_VERSION/solr-$SOLR_VERSION.tgz"; \
  fi; \
  for url in $SOLR_DOWNLOAD_URL $SOLR_CLOSER_URL $SOLR_DIST_URL $SOLR_ARCHIVE_URL; do \
    if [ -f "/opt/solr-$SOLR_VERSION.tgz" ]; then break; fi; \
    echo "downloading $url"; \
    if wget -t 10 --max-redirect $MAX_REDIRECTS --retry-connrefused -nv "$url" -O "/opt/solr-$SOLR_VERSION.tgz"; then break; else rm -f "/opt/solr-$SOLR_VERSION.tgz"; fi; \
  done; \
  if [ ! -f "/opt/solr-$SOLR_VERSION.tgz" ]; then echo "failed all download attempts for solr-$SOLR_VERSION.tgz"; exit 1; fi; \
  if [ -z "$SKIP_GPG_CHECK" ]; then \
    echo "downloading $SOLR_ARCHIVE_URL.asc"; \
    wget -nv "$SOLR_ARCHIVE_URL.asc" -O "/opt/solr-$SOLR_VERSION.tgz.asc"; \
    echo "$SOLR_SHA512 */opt/solr-$SOLR_VERSION.tgz" | sha512sum -c -; \
    (>&2 ls -l "/opt/solr-$SOLR_VERSION.tgz" "/opt/solr-$SOLR_VERSION.tgz.asc"); \
    gpg --batch --verify "/opt/solr-$SOLR_VERSION.tgz.asc" "/opt/solr-$SOLR_VERSION.tgz"; \
  else \
    echo "Skipping GPG validation due to non-Apache build"; \
  fi; \
  tar -C /opt --extract --file "/opt/solr-$SOLR_VERSION.tgz"; \
  mv "/opt/solr-$SOLR_VERSION" /opt/solr; \
  rm "/opt/solr-$SOLR_VERSION.tgz"*; \
  rm -Rf /opt/solr/docs/ /opt/solr/dist/{solr-core-$SOLR_VERSION.jar,solr-solrj-$SOLR_VERSION.jar,solrj-lib,solr-test-framework-$SOLR_VERSION.jar,test-framework}; \
  mkdir -p /opt/solr/server/solr/lib /docker-entrypoint-initdb.d /opt/docker-solr; \
  mkdir -p /opt/solr/server/solr/mycores /opt/solr/server/logs /opt/mysolrhome; \
  sed -i -e "s/\"\$(whoami)\" == \"root\"/\$(id -u) == 0/" /opt/solr/bin/solr; \
  sed -i -e 's/lsof -PniTCP:/lsof -t -PniTCP:/' /opt/solr/bin/solr; \
  if [ -f "/opt/solr/contrib/prometheus-exporter/bin/solr-exporter" ]; then chmod 0755 "/opt/solr/contrib/prometheus-exporter/bin/solr-exporter"; fi; \
  chmod -R 0755 /opt/solr/server/scripts/cloud-scripts; \
  chown -R "$SOLR_USER:$SOLR_GROUP" /opt/solr /docker-entrypoint-initdb.d /opt/docker-solr; \
  chown -R "$SOLR_USER:$SOLR_GROUP" /opt/mysolrhome; \
  { command -v gpgconf; gpgconf --kill all || :; }; \
  rm -r "$GNUPGHOME"

COPY --chown=solr:solr scripts /opt/docker-solr/scripts

EXPOSE 8983
WORKDIR /opt/solr
USER $SOLR_USER

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["solr-foreground"]
