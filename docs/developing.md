
Developing docker-solr
======================

The [Adding a new version to docker-solr](../update.md) document describes
the typical flow for adding a new version of Solr and publishing it as an
official image.
But if you want to develop docker-solr, here is the workflow I use:

Pull the latest, and run update and build to check everything still works
as expected. If you already have the artifacts, this takes 10 minutes.

```
git pull
tools/update.sh
git diff
tools/build_all.sh
tools/test_all.sh
```

Then iterate on developing the `Dockerfile.template`, `docker-entrypoint.sh`,
scripts etc. Re-build just one container, which takes about 10 seconds:

```
tools/build_latest.sh
docker run -it -p 8983:8983 dockersolr/docker-solr:latest
```

Before checking in, verify the Dockerfile templates look correct:

```
diff -du Dockerfile.template Dockerfile-slim.template
```

Then build all again, commit an push:

```
tools/build_all.sh
tools/test_all.sh
tools/push_all.sh
git commit -a
git push
```

Then verify the Travis build in the PR.
