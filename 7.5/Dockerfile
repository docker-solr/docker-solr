
FROM openjdk:11-jre

LABEL maintainer="Martijn Koster \"mak-docker@greenhills.co.uk\""
LABEL repository="https://github.com/docker-solr/docker-solr"

# Override the solr download location with e.g.:
#   docker build -t mine --build-arg SOLR_DOWNLOAD_SERVER=http://www-eu.apache.org/dist/lucene/solr .
ARG SOLR_DOWNLOAD_SERVER

RUN apt-get update && \
  apt-get -y install lsof procps wget gpg dirmngr && \
  rm -rf /var/lib/apt/lists/*

ENV SOLR_USER="solr" \
    SOLR_UID="8983" \
    SOLR_GROUP="solr" \
    SOLR_GID="8983" \
    SOLR_VERSION="7.5.0" \
    SOLR_URL="${SOLR_DOWNLOAD_SERVER:-https://archive.apache.org/dist/lucene/solr}/7.5.0/solr-7.5.0.tgz" \
    SOLR_SHA256="eac2daffc376dd8057ee831fbfc4a1b8ee236b8ad94122e11d67fd2b242acebc" \
    SOLR_KEYS="052C5B48A480B9CEA9E218A5F98C13CFA5A135D8" \
    PATH="/opt/solr/bin:/opt/docker-solr/scripts:$PATH"

ENV GOSU_VERSION 1.11
ENV GOSU_KEY B42F6819007F00F88E364FD4036A9C25BF357DD4

RUN groupadd -r --gid $SOLR_GID $SOLR_GROUP && \
  useradd -r --uid $SOLR_UID --gid $SOLR_GID $SOLR_USER

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
