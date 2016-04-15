# Supported tags and respective `Dockerfile` links

-       [`6.0.0`, `6.6`, `6`, `latest` (*6.0/Dockerfile*)](https://github.com/docker-solr/docker-solr/blob/8521b45272527088c95744a87ad35232f593b772/6.0/Dockerfile)
-       [`5.5.0`, `5.5`, `5` (*5.5/Dockerfile*)](https://github.com/docker-solr/docker-solr/blob/8521b45272527088c95744a87ad35232f593b772/5.5/Dockerfile)
-       [`5.4.1`, `5.4` (*5.4/Dockerfile*)](https://github.com/docker-solr/docker-solr/blob/8521b45272527088c95744a87ad35232f593b772/5.4/Dockerfile)
-       [`5.3.2`, `5.3` (*5.3/Dockerfile*)](https://github.com/docker-solr/docker-solr/blob/8521b45272527088c95744a87ad35232f593b772/5.3/Dockerfile)

For each of these there are variants based on the Alpine image, .e.g `6.0-alpine`.

For more information about this image and its history, please see [the relevant manifest file (`library/solr`)](https://github.com/docker-library/official-images/blob/master/library/solr). This image is updated via pull requests to [the `docker-solr/docker-solr` GitHub repo](https://github.com/docker-solr/docker-solr).

For detailed information about the virtual/transfer sizes and individual layers of each of the above supported tags, please see [the `solr/tag-details.md` file](https://github.com/docker-library/docs/blob/master/solr/tag-details.md) in [the `docker-library/docs` GitHub repo](https://github.com/docker-library/docs).

# What is Solr?

Solr is highly reliable, scalable and fault tolerant, providing distributed indexing, replication and load-balanced querying, automated failover and recovery, centralized configuration and more. Solr powers the search and navigation features of many of the world's largest internet sites.

Learn more on [Apache Solr homepage](http://lucene.apache.org/solr/) and in the [Apache Solr Reference Guide](https://www.apache.org/dyn/closer.cgi/lucene/solr/ref-guide/).

> [wikipedia.org/wiki/Apache_Solr](https://en.wikipedia.org/wiki/Apache_Solr)

![logo](https://raw.githubusercontent.com/docker-library/docs/master/solr/logo.png)

# How to use this Docker image

To run a single Solr server:

```console
$ docker run --name my_solr -d -p 8983:8983 -t solr
```

Then with a web browser go to `http://localhost:8983/` to see the Admin Console (adjust the hostname for your docker host).

To use Solr, you need to create a "core", an index for your data. For example:

```console
$ docker exec -it --user=solr my_solr bin/solr create_core -c gettingstarted
```

In the web UI if you click on "Core Admin" you should now see the "gettingstarted" core.

If you want to load some example data:

```console
$ docker exec -it --user=solr my_solr bin/post -c gettingstarted example/exampledocs/manufacturers.xml
```

In the UI, find the "Core selector" popup menu and select the "gettingstarted" core, then select the "Query" menu item. This gives you a default search for `*:*` which returns all docs. Hit the "Execute Query" button, and you should see a few docs with data. Congratulations!

For convenience, there is a single command that starts Solr, creates a collection called "demo", and loads sample data into it:

```console
$ docker run --name solr_demo -d -P solr solr-demo
```

To learn more about Solr, see the [Apache Solr Reference Guide](https://cwiki.apache.org/confluence/display/solr/Apache+Solr+Reference+Guide).

## Creating Cores

In addition to the `docker exec` method explained above, you can create a core automatically at start time, in several ways.

If you run:

```console
$ docker run -d -P solr solr-create -c mycore
```

the container will run Solr, wait for it to start, and then run the "solr create" command with the arguments you passed.
You can combine this with mounted volumes to pass in core configuration from your host:

```console
$ docker run -d -P -v $PWD/myconfig:/myconfig solr solr-create -c mycore -d /myconfig
```

When using the `solr-create` command, Solr will log to the standard docker log (inspect with `docker logs`),
and the collection creation will happen in the background and log to `/opt/docker-solr/init.log`.

This first way closely mirrors the manual core creation steps and uses Solr's own tools to create the core,
so should be reliable. But because the core creation happens in the background it is harder to spot failures,
and there is a window where Solr is ready but the core has not yet been created.

The second way of creating a core at start time is using the `solr-precreate` command. This will create the core
in the filesystem before running Solr. You should pass it the core name, and optionally the directory to copy the
config from (this defaults to Solr's built-in "basic_configs"). For example:

```console
$ docker run -d -P solr solr-precreate mycore
$ docker run -d -P -v $PWD/myconfig:/myconfig solr solr-precreate mycore /myconfig
```
This method stores the core in an intermediate subdirectory called "mycores". This allows you to use mounted
volumes:

```console
$ mkdir mycores
$ sudo chown 8983:8983 mycores
$ docker run -d -P -v $PWD/mycores:/opt/solr/server/solr/mycores solr solr-precreate mycore
```

This second way is quicker, easier to monitor because it logs to the docker log, and can fail immediately if something is wrong.
But, because it makes assumptions about Solr's "basic_configs", future upstream changes could break that.

The third way of creating a core at startup is to use the image extension mechanism explained in the next section.

## Extending the image

The docker-solr image has an extension mechanism. At run time, before starting Solr, the container will execute scripts
in the `/docker-entrypoint-initdb.d/` directory. You can add your own scripts there either by using mounted volumes
or by using a custom Dockerfile. These scripts can for example copy a core directory with pre-loaded data for continuous
integration testing. Or they can put themselves in the background, wait for Solr to start, create a core, and then run
a sequence of REST commands for testing.

Here is a simple example. With a `print-status.sh` script like:

```console
OUTPUT=/opt/docker-solr/status.log
echo "starting $0; logging to $OUTPUT"
{
    /opt/docker-solr/scripts/wait-for-solr.sh
    /opt/solr/bin/solr status > /opt/docker-solr/status

} </dev/null >$OUTPUT 2>&1 &
```
you can run:

```console
$ docker run --name solr_status1 -d -P -v $PWD/docs/print-status.sh:/docker-entrypoint-initdb.d/print-status.sh solr
$ sleep 5
$ docker exec solr_status1 cat /opt/docker-solr/status
```

and get:

```console
Found 1 Solr nodes:

Solr process 1 running on port 8983
{
  "solr_home":"/opt/solr/server/solr",
  "version":"6.0.0 48c80f91b8e5cd9b3a9b48e6184bd53e7619e7e3 - nknize - 2016-04-01 14:41:49",
  "startTime":"2016-04-11T08:32:03.657Z",
  "uptime":"0 days, 0 hours, 0 minutes, 5 seconds",
  "memory":"34.6 MB (%7.1) of 490.7 MB"}
```

With this extension mechanism it can be useful to see the shell commands that are being executed by the `docker-entrypoint.sh`
script in the docker log. To do that, set an environment variable using Docker's `-e VERBOSE=yes`.

## Distributed Solr

You can also run a distributed Solr configuration.

The recommended and most flexible way to do that is to use Docker networking.
See the [Can I run ZooKeeper and Solr clusters under Docker](https://github.com/docker-solr/docker-solr/blob/master/Docker-FAQ.md#can-i-run-zookeeper-and-solr-clusters-under-docker) FAQ,
and [this example](docs/docker-networking.md).

You can also use legacy links, see the [Can I run ZooKeeper and Solr with Docker Links](Docker-FAQ.md#can-i-run-zookeeper-and-solr-clusters-under-docker) FAQ.

# About this repository

This repository is available on [github.com/docker-solr/docker-solr](https://github.com/docker-solr/docker-solr), and the official build is on the [Docker Hub](https://hub.docker.com/_/solr/).

This repository is based on (and replaces) `makuk66/docker-solr`, and has been sponsored by [Lucidworks](http://www.lucidworks.com/).

# License

Solr is licensed under the [Apache License, Version 2.0](https://www.apache.org/licenses/LICENSE-2.0).

This repository is also licensed under the [Apache License, Version 2.0](https://www.apache.org/licenses/LICENSE-2.0).

Copyright 2015 Martijn Koster

Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at

	      http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

# Supported Docker versions

This image has been built and tested with Docker version 1.11.

# User Feedback

## Issues

Please report issues with this docker image on this [Github project](https://github.com/docker-solr/docker-solr).

For general questions about Solr, see the [Community information](http://lucene.apache.org/solr/resources.html#community), in particular the solr-user mailing list.

## Contributing

If you want to contribute to Solr, see the [Solr Resources](http://lucene.apache.org/solr/resources.html#community).
