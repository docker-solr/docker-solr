FROM debian
MAINTAINER  Martijn Koster "mak-docker@greenhills.co.uk"

ENV DOCKER_VERSION=17.06.2-ce

RUN apt-get update && \
  apt-get -y install lsof procps curl wget gpg gawk shellcheck vim less git && \
  rm -rf /var/lib/apt/lists/*

RUN URL=https://download.docker.com/linux/static/stable/x86_64/docker-${DOCKER_VERSION}.tgz && \
  echo "Downloading $URL" && \
  wget -nv "--output-document=/tmp/docker-${DOCKER_VERSION}.tgz" "$URL" && \
  tar -C /usr/local/bin --extract --file "/tmp/docker-$DOCKER_VERSION.tgz" --strip-components=1 && \
  rm /tmp/docker-$DOCKER_VERSION.tgz

ADD my-bash-prompt.sh /tmp/my-bash-prompt.sh
RUN cat /tmp/my-bash-prompt.sh >> /etc/bash.bashrc
