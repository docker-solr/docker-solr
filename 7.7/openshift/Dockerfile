
FROM openjdk:11-jre

LABEL maintainer="Martijn Koster \"mak-docker@greenhills.co.uk\""
LABEL repository="https://github.com/docker-solr/docker-solr"

# Override the solr download location with e.g.:
#   docker build -t mine --build-arg SOLR_DOWNLOAD_SERVER=http://www-eu.apache.org/dist/lucene/solr .
ARG SOLR_DOWNLOAD_SERVER

ARG SOLR_USER="solr"
ARG SOLR_UID="8983"
ARG SOLR_GROUP="solr"
ARG SOLR_GID="8983"

ARG SOLR_VERSION="7.7.0"
ARG SOLR_URL="${SOLR_DOWNLOAD_SERVER:-https://archive.apache.org/dist/lucene/solr}/7.7.0/solr-7.7.0.tgz"
ARG SOLR_SHA256="ad9eaa29449701fcabad497cc5f0506f8a8f76da714dc4a5429a549fcac24dc7"
ARG SOLR_KEYS="052C5B48A480B9CEA9E218A5F98C13CFA5A135D8"

ARG GOSU_VERSION=1.11
ARG GOSU_KEY=B42F6819007F00F88E364FD4036A9C25BF357DD4

ENV PATH="/opt/solr/bin:/opt/docker-solr/scripts:$PATH"

RUN apt-get update && \
  apt-get -y install lsof procps wget gpg dirmngr && \
  rm -rf /var/lib/apt/lists/*

RUN groupadd -r --gid $SOLR_GID $SOLR_GROUP && \
  useradd -r --uid $SOLR_UID --gid $SOLR_GID $SOLR_USER

COPY --chown=solr:0 scripts /opt/docker-solr/scripts

RUN set -eu; \
  cd /opt/docker-solr/scripts/build-tools; \
  bash get-gpg-keys.sh $SOLR_KEYS; \
  bash get-solr.sh $SOLR_URL $SOLR_SHA256; \
  bash get-gpg-keys.sh $GOSU_KEY; \
  bash get-gosu.sh $GOSU_VERSION; \
  bash root-group-permissions.sh; \
  bash set-prompt.sh; \
  cd ..; \
  rm -fr builder-tools

EXPOSE 8983
WORKDIR /opt/solr
USER $SOLR_UID

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["solr-foreground"]
