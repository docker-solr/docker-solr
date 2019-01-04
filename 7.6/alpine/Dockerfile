### get, check and install solr and our scripts
FROM alpine:3.8 as our_alpine

RUN apk add --no-cache bash
RUN apk add --no-cache gnupg
RUN apk add --no-cache tar

RUN apk add --no-cache ca-certificates wget && \
        update-ca-certificates

FROM our_alpine as solr_builder

# Override the solr download location with e.g.:
#   docker build -t mine --build-arg SOLR_DOWNLOAD_SERVER=http://www-eu.apache.org/dist/lucene/solr .
ARG SOLR_DOWNLOAD_SERVER

ENV SOLR_VERSION="7.6.0"
ENV SOLR_URL="${SOLR_DOWNLOAD_SERVER:-https://archive.apache.org/dist/lucene/solr}/7.6.0/solr-7.6.0.tgz"
ENV SOLR_SHA256="2cb425a0b30ff153465d306803e514e53e41924d74f28d842cb3a07cace759d5"
ENV SOLR_KEY="95B01F0E78111D63D331C1A751F0CC22F625308A"

COPY builder_tools/* /builder_tools/
RUN bash /builder_tools/get-gpg-keys.sh $SOLR_KEY
RUN bash /builder_tools/get-solr.sh $SOLR_URL $SOLR_SHA256

COPY scripts /opt/docker-solr/scripts


### get and check gosu
FROM our_alpine AS gosu_builder

ENV GOSU_VERSION 1.11
ENV GOSU_KEY B42F6819007F00F88E364FD4036A9C25BF357DD4

COPY builder_tools/* /builder_tools/
RUN bash /builder_tools/get-gpg-keys.sh $GOSU_KEY
RUN bash /builder_tools/get-gosu.sh $GOSU_VERSION


### Now prepare the solr image
FROM openjdk:8-jre-alpine

LABEL maintainer="Martijn Koster \"mak-docker@greenhills.co.uk\""
LABEL repository="https://github.com/docker-solr/docker-solr"

ARG SOLR_USER="solr"
ARG SOLR_UID="8983"
ARG SOLR_GROUP="solr"
ARG SOLR_GID="8983"

ENV PATH="/opt/solr/bin:/opt/docker-solr/scripts:$PATH"

RUN set -e; \
  apk add --no-cache \
        bash \
        lsof \
        procps; \
  apk add --no-cache ca-certificates wget && \
        update-ca-certificates; \
  addgroup -S -g $SOLR_GID $SOLR_GROUP && \
  adduser -S -u $SOLR_UID -G $SOLR_GROUP $SOLR_USER

COPY --from=solr_builder --chown=solr:solr /opt /opt
COPY --from=solr_builder --chown=solr:solr /docker-entrypoint-initdb.d /docker-entrypoint-initdb.d

COPY --from=gosu_builder /usr/local/bin/gosu /usr/local/bin/gosu

EXPOSE 8983
WORKDIR /opt/solr
USER $SOLR_USER

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["solr-foreground"]