
Docker Solr FAQ
===============


How do I persist Solr data and config?
--------------------------------------

Your data is persisted already, in your container's filesystem.
If you `docker run`, add data to Solr, then `docker stop` and later
`docker start`, then your data is still there.

Equally, if you `docker commit` your container, you can later create a new
container from that image, and that will have your data in it.

But usually when people ask this question, what they are after is a way
to store Solr data and config in a separate [Docker Volume](https://docs.docker.com/userguide/dockervolumes/).
That is explained in the next two questions.


How can I mount a host directory as a data volume?
--------------------------------------------------

This is useful if you want to inspect or modify the data in the Docker host
when the container is not running, and later easily run new containers against that data.
This is indeed possible, but there are a few gotchas.

Solr stores its core data in the `server/solr` directory, in sub-directories
for each core. The `server/solr` directory also contains configuration files
that are part of the Solr distribution.
Now, if we mounted volumes for each core individually, then that would
interfere with Solr trying to create those directories. If instead we make
the whole directory a volume, then we need to provide those configuration files
in our volume. For example:

```
# create a directory to store the server/solr directory
$ mkdir /home/docker-volumes/mysolr1

# make sure its host owner matches the container's solr user
$ sudo chown 999:999 /home/docker-volumes/mysolr1

# copy the solr directory from a temporary container to the volume
$ docker run -it --rm -v /home/docker-volumes/mysolr1:/target solr cp -r server/solr /target/

# pass the solr directory to a new container running solr
$ SOLR_CONTAINER=$(docker run -d -P -v /home/docker-volumes/mysolr1/solr:/opt/solr/server/solr solr)

# create a new core
$ docker exec -it --user=solr $SOLR_CONTAINER bin/solr create_core -c gettingstarted

# check the volume on the host:
$ ls /home/docker-volumes/mysolr1/solr/
configsets  gettingstarted  README.txt  solr.xml  zoo.cfg
```

Note that if you add or modify files in that directory from the host, you must `chown 999:999` them.

How can I use a Data Volume Container?
--------------------------------------

You can avoid the concerns about UID mismatches above, by using data volumes only from containers.
You can create a container with a volume, then point future containers at that same volume.
This can be handy if you want to modify the solr image, for example if you want to add a program.
By separating the data and the code, you can change the code and re-use the data.

But there are pitfalls:

- if you remove the container that owns the volume, then you lose your data.
  Docker does not even warn you that a running container is dependent on it.
- if you point multiple solr containers at the same volume, you will have multiple instances
  write to the same files, which will undoubtedly lead to corruption
- if you do want to remove that volume, you must do `docker rm -v containername`;
  if you forget the `-v` there will be a dangling volume which you can not easily clean up.

Here is an example:

```
# create a container with a volume on the path that solr uses to store data.
docker create -v /opt/solr/server/solr --name mysolr1data solr /bin/true

# pass the volume to a new container running solr
SOLR_CONTAINER=$(docker run -d -P --volumes-from=mysolr1data solr)

# create a new core
$ docker exec -it --user=solr $SOLR_CONTAINER bin/solr create_core -c gettingstarted

# make a change to the config, using the config API
docker exec -it --user=solr $SOLR_CONTAINER curl http://localhost:8983/solr/gettingstarted/config -H 'Content-type:application/json' -d'{
    "set-property" : {"query.filterCache.autowarmCount":1000},
    "unset-property" :"query.filterCache.size"}'

# verify the change took effect
docker exec -it --user=solr $SOLR_CONTAINER curl http://localhost:8983/solr/gettingstarted/config/overlay?omitHeader=true

# stop the solr container
docker exec -it --user=solr $SOLR_CONTAINER bash -c 'cd server; java -DSTOP.PORT=7983 -DSTOP.KEY=solrrocks -jar start.jar --stop'

# create a new container
SOLR_CONTAINER=$(docker run -d -P --volumes-from=mysolr1data solr)

# check our core is still there:
docker exec -it --user=solr $SOLR_CONTAINER ls server/solr/gettingstarted

# check the config modification is still there:
docker exec -it --user=solr $SOLR_CONTAINER curl http://localhost:8983/solr/gettingstarted/config/overlay?omitHeader=true
```
