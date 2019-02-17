FROM debian
MAINTAINER  Martijn Koster "mak-docker@greenhills.co.uk"

ARG BASHBREW_URL=https://doi-janky.infosiftr.net/job/bashbrew/lastSuccessfulBuild/artifact/bin/bashbrew-amd64

RUN apt-get update && \
  apt-get -y install lsof procps curl wget gpg gawk shellcheck vim less git

RUN apt-get -y install apt-transport-https \
    ca-certificates \
    curl \
    gnupg-agent \
    software-properties-common

RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add - && \
    add-apt-repository \
       "deb [arch=amd64] https://download.docker.com/linux/debian \
       $(lsb_release -cs) \
       stable" && \
    apt-get update && \
    apt-get -y install docker-ce docker-ce-cli containerd.io

RUN wget -nv --output-document=/usr/local/bin/bashbrew "$BASHBREW_URL" && \
  chmod a+x /usr/local/bin/bashbrew

ADD my-bash-prompt.sh /tmp/my-bash-prompt.sh
RUN cat /tmp/my-bash-prompt.sh >> /etc/bash.bashrc
