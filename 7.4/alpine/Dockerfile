
FROM openjdk:8-jre-alpine
MAINTAINER  Martijn Koster "mak-docker@greenhills.co.uk"

# Override the solr download location with e.g.:
#   docker build -t mine --build-arg SOLR_DOWNLOAD_SERVER=http://www-eu.apache.org/dist/lucene/solr .
ARG SOLR_DOWNLOAD_SERVER

RUN apk add --no-cache \
        lsof \
        gnupg \
        procps \
        tar \
        bash
RUN apk add --no-cache ca-certificates wget && \
        update-ca-certificates

ENV SOLR_USER="solr" \
    SOLR_UID="8983" \
    SOLR_GROUP="solr" \
    SOLR_GID="8983" \
    SOLR_VERSION="7.4.0" \
    SOLR_URL="${SOLR_DOWNLOAD_SERVER:-https://archive.apache.org/dist/lucene/solr}/7.4.0/solr-7.4.0.tgz" \
    SOLR_SHA256="a50eac8dece0acb5e6f0d868c7868ce8174e299752356f3424a15aa39bd64407" \
    SOLR_KEYS="E6E21FFCDCEA14C95910EA65051A0FAF76BC6507" \
    PATH="/opt/solr/bin:/opt/docker-solr/scripts:$PATH"

ENV GOSU_VERSION 1.10
ENV GOSU_KEY B42F6819007F00F88E364FD4036A9C25BF357DD4

RUN addgroup -S -g $SOLR_GID $SOLR_GROUP && \
    adduser -S -u $SOLR_UID -G $SOLR_GROUP $SOLR_USER

RUN set -e; \
  export GNUPGHOME="/tmp/gnupg_home" && \
  mkdir -p "$GNUPGHOME" && \
  chmod 700 "$GNUPGHOME" && \
  for key in $SOLR_KEYS $GOSU_KEY; do \
    found=''; \
    for server in \
      ha.pool.sks-keyservers.net \
      hkp://keyserver.ubuntu.com:80 \
      hkp://p80.pool.sks-keyservers.net:80 \
      pgp.mit.edu \
    ; do \
      echo "  trying $server for $key"; \
      gpg --keyserver "$server" --keyserver-options timeout=10 --recv-keys "$key" && found=yes && break; \
    done; \
    test -z "$found" && echo >&2 "error: failed to fetch $key from several disparate servers -- network issues?" && exit 1; \
  done; \
  exit 0

RUN set -e; \
  export GNUPGHOME="/tmp/gnupg_home" && \
  apkArch="$(apk --print-arch | sed 's/x86_64/amd64/')"; \
  wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$apkArch"; \
  wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$apkArch.asc"; \
  gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu && \
  rm /usr/local/bin/gosu.asc && \
  chmod +x /usr/local/bin/gosu && \
  gosu nobody true && \
  mkdir -p /opt/solr && \
  echo "downloading $SOLR_URL" && \
  wget -q $SOLR_URL -O /opt/solr.tgz && \
  echo "downloading $SOLR_URL.asc" && \
  wget -q $SOLR_URL.asc -O /opt/solr.tgz.asc && \
  echo "$SOLR_SHA256 */opt/solr.tgz" | sha256sum -c - && \
  (>&2 ls -l /opt/solr.tgz /opt/solr.tgz.asc) && \
  gpg --batch --verify /opt/solr.tgz.asc /opt/solr.tgz && \
  tar -C /opt/solr --extract --file /opt/solr.tgz --strip-components=1 && \
  rm /opt/solr.tgz* && \
  rm -Rf /opt/solr/docs/ && \
  mkdir -p /opt/solr/server/solr/lib /opt/solr/server/solr/mycores /opt/solr/server/logs /docker-entrypoint-initdb.d /opt/docker-solr /opt/mysolrhome && \
  sed -i -e 's/"\$(whoami)" == "root"/$(id -u) == 0/' /opt/solr/bin/solr && \
  sed -i -e 's/lsof -PniTCP:/lsof -t -PniTCP:/' /opt/solr/bin/solr && \
  sed -i -e '/-Dsolr.clustering.enabled=true/ a SOLR_OPTS="$SOLR_OPTS -Dsun.net.inetaddr.ttl=60 -Dsun.net.inetaddr.negative.ttl=60"' /opt/solr/bin/solr.in.sh && \
  chown -R $SOLR_USER:$SOLR_GROUP /opt/solr

COPY scripts /opt/docker-solr/scripts
RUN chown -R $SOLR_USER:$SOLR_GROUP /opt/docker-solr /opt/mysolrhome

EXPOSE 8983
WORKDIR /opt/solr
USER $SOLR_USER

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["solr-foreground"]
