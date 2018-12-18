FROM debian:stretch-slim as BUILDER
MAINTAINER  Martijn Koster "mak-docker@greenhills.co.uk"

# Override the solr download location with e.g.:
#   docker build -t mine --build-arg SOLR_DOWNLOAD_SERVER=http://www-eu.apache.org/dist/lucene/solr .
ARG SOLR_DOWNLOAD_SERVER

RUN apt-get update
RUN apt-get -y install wget gpg

ENV SOLR_VERSION="7.6.0" \
    SOLR_URL="${SOLR_DOWNLOAD_SERVER:-https://archive.apache.org/dist/lucene/solr}/7.6.0/solr-7.6.0.tgz" \
    SOLR_SHA256="2cb425a0b30ff153465d306803e514e53e41924d74f28d842cb3a07cace759d5" \
    SOLR_KEYS="95B01F0E78111D63D331C1A751F0CC22F625308A" \
    GNUPGHOME="/tmp/gnupg_home"

ENV GOSU_VERSION 1.10
ENV GOSU_KEY B42F6819007F00F88E364FD4036A9C25BF357DD4

RUN mkdir -p "$GNUPGHOME"
RUN chmod 700 "$GNUPGHOME"
RUN for key in $SOLR_KEYS $GOSU_KEY; do \
    found=''; \
    for server in \
      ha.pool.sks-keyservers.net \
      hkp://keyserver.ubuntu.com:80 \
      hkp://p80.pool.sks-keyservers.net:80 \
      pgp.mit.edu \
    ; do \
      echo "  trying $server for $key"; \
      gpg --batch --keyserver "$server" --keyserver-options timeout=10 --recv-keys "$key" && found=yes && break; \
    done; \
    test -z "$found" && echo >&2 "error: failed to fetch $key from several disparate servers -- network issues?" && exit 1; \
  done; \
  exit 0

RUN set -e; \
  dpkgArch="$(dpkg --print-architecture | awk -F- '{ print $NF }')"; \
  wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch"; \
  wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch.asc"
RUN gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu
RUN rm /usr/local/bin/gosu.asc
RUN chmod +x /usr/local/bin/gosu
RUN gosu nobody true

RUN mkdir -p /opt/solr

RUN echo "downloading $SOLR_URL"
RUN wget -nv $SOLR_URL -O /opt/solr.tgz
RUN echo "downloading $SOLR_URL.asc"
RUN wget -nv $SOLR_URL.asc -O /opt/solr.tgz.asc
RUN echo "$SOLR_SHA256 */opt/solr.tgz" | sha256sum -c -
RUN (>&2 ls -l /opt/solr.tgz /opt/solr.tgz.asc)
RUN GNUPGHOME="/tmp/gnupg_home" gpg --batch --verify /opt/solr.tgz.asc /opt/solr.tgz

RUN tar -C /opt/solr --extract --file /opt/solr.tgz --strip-components=1
RUN rm /opt/solr.tgz*
RUN rm -Rf /opt/solr/docs/
RUN mkdir -p /opt/solr/server/solr/lib /opt/solr/server/solr/mycores /opt/solr/server/logs /docker-entrypoint-initdb.d /opt/docker-solr /opt/mysolrhome
RUN sed -i -e 's/"\$(whoami)" == "root"/$(id -u) == 0/' /opt/solr/bin/solr
RUN sed -i -e 's/lsof -PniTCP:/lsof -t -PniTCP:/' /opt/solr/bin/solr
RUN sed -i -e '/-Dsolr.clustering.enabled=true/ a SOLR_OPTS="$SOLR_OPTS -Dsun.net.inetaddr.ttl=60 -Dsun.net.inetaddr.negative.ttl=60"' /opt/solr/bin/solr.in.sh

COPY scripts /opt/docker-solr/scripts

# Now prepare the solr image efficiently
FROM openjdk:11-jre-slim

ENV SOLR_USER="solr" \
    SOLR_UID="8983" \
    SOLR_GROUP="solr" \
    SOLR_GID="8983" \
    SOLR_VERSION="7.6.0" \
    PATH="/opt/solr/bin:/opt/docker-solr/scripts:$PATH"

RUN set -e; \
  apt-get update; \
  apt-get -y install lsof procps wget; \
  rm -rf /var/lib/apt/lists/*; \
  groupadd -r --gid $SOLR_GID $SOLR_GROUP; \
  useradd -r --uid $SOLR_UID --gid $SOLR_GID $SOLR_USER

COPY --from=BUILDER --chown=solr:solr /opt /opt
COPY --from=BUILDER --chown=solr:solr /usr/local/bin/gosu /usr/local/bin/gosu
COPY --from=BUILDER --chown=solr:solr /docker-entrypoint-initdb.d /docker-entrypoint-initdb.d

EXPOSE 8983
WORKDIR /opt/solr
USER $SOLR_USER

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["solr-foreground"]
