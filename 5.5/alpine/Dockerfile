
FROM    java:openjdk-8-jre-alpine
MAINTAINER  Martijn Koster "mak-docker@greenhills.co.uk"

RUN apk add --update \
        lsof \
        gnupg \
        tar \
        bash \
    && rm -rf /var/cache/apk/*

ENV SOLR_USER solr
ENV SOLR_UID 8983

RUN addgroup -S -g $SOLR_UID $SOLR_USER && \
  adduser -S -u $SOLR_UID -g $SOLR_USER $SOLR_USER

ENV SOLR_KEY 2C72EB1397733A551DDB60CCF119941F6E68DA61
RUN gpg --keyserver ha.pool.sks-keyservers.net --recv-keys "$SOLR_KEY"

ENV SOLR_VERSION 5.5.0
ENV SOLR_SHA256 c5fa5cb996fe1432e09bb2f6053ffbeb095436db4a77e9c6488b531db726b04d

RUN mkdir -p /opt/solr && \
  wget http://archive.apache.org/dist/lucene/solr/$SOLR_VERSION/solr-$SOLR_VERSION.tgz -O /opt/solr.tgz && \
  wget http://archive.apache.org/dist/lucene/solr/$SOLR_VERSION/solr-$SOLR_VERSION.tgz.asc -O /opt/solr.tgz.asc && \
  gpg --verify /opt/solr.tgz.asc && \
  echo "$SOLR_SHA256 */opt/solr.tgz" | sha256sum -c - && \
  tar -C /opt/solr -x -f /opt/solr.tgz --strip-components=1 && \
  rm /opt/solr.tgz* && \
  mkdir -p /opt/solr/server/solr/lib && \
  sed -i -e 's/#SOLR_PORT=8983/SOLR_PORT=8983/' /opt/solr/bin/solr.in.sh && \
  sed -i -e '/-Dsolr.clustering.enabled=true/ a SOLR_OPTS="$SOLR_OPTS -Dsun.net.inetaddr.ttl=60 -Dsun.net.inetaddr.negative.ttl=60"' /opt/solr/bin/solr.in.sh && \
  chown -R $SOLR_USER:$SOLR_USER /opt/solr

EXPOSE 8983
WORKDIR /opt/solr
USER $SOLR_USER
CMD ["/opt/solr/bin/solr", "-f"]
