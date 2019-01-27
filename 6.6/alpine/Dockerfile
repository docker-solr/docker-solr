
FROM openjdk:8-jre-alpine

LABEL maintainer="Martijn Koster \"mak-docker@greenhills.co.uk\""
LABEL repository="https://github.com/docker-solr/docker-solr"

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
    SOLR_VERSION="6.6.5" \
    SOLR_URL="${SOLR_DOWNLOAD_SERVER:-https://archive.apache.org/dist/lucene/solr}/6.6.5/solr-6.6.5.tgz" \
    SOLR_SHA256="fa65e922bc32d36ef65bee866095da563aa5ddd7e953798c06b6494572d51729" \
    SOLR_KEYS="2085660D9C1FCCACC4A479A3BF160FF14992A24C" \
    PATH="/opt/solr/bin:/opt/docker-solr/scripts:$PATH"

ENV GOSU_VERSION 1.11
ENV GOSU_KEY B42F6819007F00F88E364FD4036A9C25BF357DD4

RUN addgroup -S -g $SOLR_GID $SOLR_GROUP && \
    adduser -S -u $SOLR_UID -G $SOLR_GROUP $SOLR_USER

COPY --chown=solr:solr scripts /opt/docker-solr/scripts

RUN set -eu; \
  cd /opt/docker-solr/scripts/build-tools; \
  bash get-gpg-keys.sh $SOLR_KEYS; \
  bash get-solr.sh $SOLR_URL $SOLR_SHA256; \
  bash get-gpg-keys.sh $GOSU_KEY; \
  bash get-gosu.sh $GOSU_VERSION; \
  cd ..; \
  rm -fr builder-tools /tmp/gnupg_home

EXPOSE 8983
WORKDIR /opt/solr
USER $SOLR_USER

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["solr-foreground"]
