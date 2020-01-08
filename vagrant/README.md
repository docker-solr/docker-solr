This directory contains a [Vagrantfile](Vagrantfile) for building docker-solr.

Pre-requisites: [VirtualBox](https://www.virtualbox.org/wiki/Downloads) and [Vagrant](https://www.vagrantup.com/downloads.html).

```bash
vagrant up
vagrant ssh -c "git clone https://github.com/docker-solr/docker-solr.git && \
  cd docker-solr && \
  ./tools/update.sh && \
  ./tools/build_all.sh && \
  ./tools/test_all.sh"
```
