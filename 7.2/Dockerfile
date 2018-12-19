### get, check and install solr and our scripts
FROM debian:stretch-slim as SOLR_BUILDER

# Override the solr download location with e.g.:
#   docker build -t mine --build-arg SOLR_DOWNLOAD_SERVER=http://www-eu.apache.org/dist/lucene/solr .
ARG SOLR_DOWNLOAD_SERVER

RUN apt-get update
RUN apt-get -y install wget gpg

ENV SOLR_VERSION="7.2.1"
ENV SOLR_URL="${SOLR_DOWNLOAD_SERVER:-https://archive.apache.org/dist/lucene/solr}/7.2.1/solr-7.2.1.tgz"
ENV SOLR_SHA256="1dbe8dda842d2008210c0c56d56b714713444fb4e05390bb0bcdec29cf957748"
ENV SOLR_KEY="052C5B48A480B9CEA9E218A5F98C13CFA5A135D8"

COPY builder_tools/* /builder_tools/
RUN bash /builder_tools/get-gpg-keys.sh $SOLR_KEY
RUN bash /builder_tools/get-solr.sh $SOLR_URL $SOLR_SHA256

COPY scripts /opt/docker-solr/scripts


### get and check gosu
FROM debian:stretch-slim as GOSU_BUILDER

RUN apt-get update
RUN apt-get -y install wget gpg

ENV GOSU_VERSION 1.11
ENV GOSU_KEY B42F6819007F00F88E364FD4036A9C25BF357DD4

COPY builder_tools/* /builder_tools/
RUN bash /builder_tools/get-gpg-keys.sh $GOSU_KEY
RUN bash /builder_tools/get-gosu.sh $GOSU_VERSION


### Now prepare the solr image
FROM openjdk:8-jre

LABEL maintainer="Martijn Koster \"mak-docker@greenhills.co.uk\""
LABEL repository="https://github.com/docker-solr/docker-solr"

ARG SOLR_USER="solr"
ARG SOLR_UID="8983"
ARG SOLR_GROUP="solr"
ARG SOLR_GID="8983"

ENV PATH="/opt/solr/bin:/opt/docker-solr/scripts:$PATH"

RUN set -e; \
  apt-get update; \
  apt-get -y install lsof procps wget; \
  rm -rf /var/lib/apt/lists/*; \
  groupadd -r --gid $SOLR_GID $SOLR_GROUP; \
  useradd -r --uid $SOLR_UID --gid $SOLR_GID $SOLR_USER

COPY --from=SOLR_BUILDER --chown=solr:solr /opt /opt
COPY --from=SOLR_BUILDER --chown=solr:solr /docker-entrypoint-initdb.d /docker-entrypoint-initdb.d

COPY --from=GOSU_BUILDER /usr/local/bin/gosu /usr/local/bin/gosu

EXPOSE 8983
WORKDIR /opt/solr
USER $SOLR_USER

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["solr-foreground"]
