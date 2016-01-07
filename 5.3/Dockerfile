
FROM    java:openjdk-8-jre
MAINTAINER  Martijn Koster "mak-docker@greenhills.co.uk"

RUN apt-get update && \
  apt-get -y install lsof && \
  rm -rf /var/lib/apt/lists/*

ENV SOLR_USER solr
ENV SOLR_UID 8983

RUN groupadd -r $SOLR_USER && \
  useradd -r -u $SOLR_UID -g $SOLR_USER $SOLR_USER

ENV SOLR_KEY CFCE5FBB920C3C745CEEE084C38FF5EC3FCFDB3E
RUN gpg --keyserver ha.pool.sks-keyservers.net --recv-keys "$SOLR_KEY"

ENV SOLR_VERSION 5.3.1
ENV SOLR_SHA256 34ddcac071226acd6974a392af7671f687990aa1f9eb4b181d533ca6dca6f42d

RUN mkdir -p /opt/solr && \
  wget -nv --output-document=/opt/solr.tgz http://archive.apache.org/dist/lucene/solr/$SOLR_VERSION/solr-$SOLR_VERSION.tgz && \
  wget -nv --output-document=/opt/solr.tgz.asc http://archive.apache.org/dist/lucene/solr/$SOLR_VERSION/solr-$SOLR_VERSION.tgz.asc && \
  gpg --verify /opt/solr.tgz.asc && \
  echo "$SOLR_SHA256 */opt/solr.tgz" | sha256sum -c - && \
  tar -C /opt/solr --extract --file /opt/solr.tgz --strip-components=1 && \
  rm /opt/solr.tgz* && \
  mkdir -p /opt/solr/server/solr/lib && \
  sed -i -e 's/#SOLR_PORT=8983/SOLR_PORT=8983/' /opt/solr/bin/solr.in.sh && \
  chown -R $SOLR_USER:$SOLR_USER /opt/solr

# https://issues.apache.org/jira/browse/SOLR-8107
RUN sed --in-place -e 's/^    "$JAVA" "${SOLR_START_OPTS\[@\]}" $SOLR_ADDL_ARGS -jar start.jar "${SOLR_JETTY_CONFIG\[@\]}"/    exec "$JAVA" "${SOLR_START_OPTS[@]}" $SOLR_ADDL_ARGS -jar start.jar "${SOLR_JETTY_CONFIG[@]}"/' /opt/solr/bin/solr

EXPOSE 8983
WORKDIR /opt/solr
USER $SOLR_USER
CMD ["/opt/solr/bin/solr", "-f"]
