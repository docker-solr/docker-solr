### get debian with wget
FROM debian:stretch-slim as our_debian

RUN apt-get update
RUN apt-get -y install wget gpg

COPY builder_tools/* /builder_tools/


### get, check and install solr and our scripts
FROM our_debian AS solr_builder

# Override the solr download location with e.g.:
#   docker build -t mine --build-arg SOLR_DOWNLOAD_SERVER=http://www-eu.apache.org/dist/lucene/solr .
ARG SOLR_DOWNLOAD_SERVER

ENV SOLR_VERSION="7.4.0"
ENV SOLR_URL="${SOLR_DOWNLOAD_SERVER:-https://archive.apache.org/dist/lucene/solr}/7.4.0/solr-7.4.0.tgz"
ENV SOLR_SHA256="a50eac8dece0acb5e6f0d868c7868ce8174e299752356f3424a15aa39bd64407"
ENV SOLR_KEY="E6E21FFCDCEA14C95910EA65051A0FAF76BC6507"

RUN bash /builder_tools/get-gpg-keys.sh $SOLR_KEY
RUN bash /builder_tools/get-solr.sh $SOLR_URL $SOLR_SHA256

COPY scripts /opt/docker-solr/scripts


### get and check gosu
FROM our_debian AS gosu_builder

ENV GOSU_VERSION 1.11
ENV GOSU_KEY B42F6819007F00F88E364FD4036A9C25BF357DD4

RUN bash /builder_tools/get-gpg-keys.sh $GOSU_KEY
RUN bash /builder_tools/get-gosu.sh $GOSU_VERSION


### Now prepare the solr image
FROM openjdk:11-jre-slim

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

COPY --from=solr_builder --chown=solr:solr /opt /opt
COPY --from=solr_builder --chown=solr:solr /docker-entrypoint-initdb.d /docker-entrypoint-initdb.d

COPY --from=gosu_builder /usr/local/bin/gosu /usr/local/bin/gosu

EXPOSE 8983
WORKDIR /opt/solr
USER $SOLR_USER

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["solr-foreground"]
