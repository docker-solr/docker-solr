# Source this file to prepare a mac for running scripts
hash greadlink 2>/dev/null || { echo >&2 "Required tool greadlink is not installed, please run 'brew install coreutils'"; exit 1; }
hash gfind 2>/dev/null || { echo >&2 "Required tool gfind is not installed, please run 'brew install findutils'"; exit 1; }
hash gsed 2>/dev/null || { echo >&2 "Required tool gsed is not installed, please run 'brew install gnu-sed'"; exit 1; }
if [[ ! -d /tmp/docker-solr-bin ]]; then
  mkdir -p /tmp/docker-solr-bin >/dev/null 2>&1
  ln -s /usr/local/bin/greadlink /tmp/docker-solr-bin/readlink
  ln -s /usr/local/bin/gfind /tmp/docker-solr-bin/find
  ln -s /usr/local/bin/gsed /tmp/docker-solr-bin/sed
fi
if [[ ! $PATH == *"docker-solr-bin"* ]]; then
  export PATH=/tmp/docker-solr-bin:$PATH
  echo "Configuring for macOS - adding /tmp/docker-solr-bin first in path"
fi