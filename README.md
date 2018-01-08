# Apache Solr™ Centos Docker images

This is a fork of the [docker-solr](https://github.com/docker-solr/docker-solr) repo adding
a CentOS based Dockerfile of Apache Solr. You'll find the CentOS based Apache Solr™  image on
[Docker Hub](https://hub.docker.com/r/shopping24/docker-solr-centos/).

## Running the image

```console
$ docker run -d -p 8983:8983 -t shopping24/docker-solr-centos:latest
```

## Supported tags and `Dockerfile` links

- [`7.2.0`, `7.2`, `7`, `latest` (*7.2/centos/Dockerfile*)](https://github.com/shopping24/docker-solr-centos/blob/master/7.2/centos/Dockerfile)
- [`7.1.0`, `7.1` (*7.1/slim/Dockerfile*)](https://github.com/docker-solr/shopping24/blob/master/7.1/slim/Dockerfile)
- [`6.6.2`, `6.6`, `6` (*6.6/slim/Dockerfile*)](https://github.com/shopping24/docker-solr/blob/master/6.6/slim/Dockerfile)
- [`5.5.5`, `5.5`, `5` (*5.5/slim/Dockerfile*)](https://github.com/shopping24/docker-solr/blob/master/5.5/slim/Dockerfile)

## Documentation, Features & Extension Points

This is a fully compatible clone of the awesome [docker-solr](https://github.com/docker-solr/docker-solr) image, 
which boasts handy extension points to run and customize Solr. Please see [their documentation on how to run this 
image](https://github.com/shopping24/docker-solr/blob/master/README.md#how-to-use-this-docker-image). 

## About this repository

This repository is based on [docker-solr](https://github.com/docker-solr/docker-solr) and
originates in [this pull request](https://github.com/docker-solr/docker-solr/pull/160).

# License

Solr is licensed under the [Apache License, Version 2.0](https://www.apache.org/licenses/LICENSE-2.0).
This repository is also licensed under the [Apache License, Version 2.0](https://www.apache.org/licenses/LICENSE-2.0).

Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at

	      http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

# User Feedback

Please report issues with this docker image on this [Github project](https://github.com/shopping24/docker-solr).
