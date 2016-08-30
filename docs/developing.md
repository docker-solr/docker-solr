
Developing docker-solr
======================

The [Adding a new version to docker-solr](../update.md) document describes
the typical flow for adding a new version of Solr and publishing it as an
official image.
But if you want to develop docker-solr, here is the workflow I use:

Set an environment variable to keep the downloads in the ./downloads
directory so they do not need to be downloaded again on future
invocations:
```
export KEEP_ALL_ARTIFACTS=yes
```

Pull the latest, and run update and build to check everything still works
as expected. If you already have the artifacts, this takes 10 minutes.

```
git pull
bash update.sh [0-9]\.[0-9]
git diff
bash build-all.sh build_all test_all
```

Then iterate on developing the `Dockerfile.template`, `docker-entrypoint.sh`,
scripts etc. Re-build just one container, which takes about 10 seconds:

```
bash update.sh 6.0
bash build-all.sh build_latest
docker run -it -P docker-solr/docker-solr:latest
```

For even faster iteration, modify and build in one of the sub-directories,
call docker build yourself (copy-paste the command printed by build-all.sh)
and then later copy the changes back to the root.

Once you are happy, update the `Dockerfile-alpine.template`
to reflect the changes to the `Dockerfile` and verify with:

```
diff -du Dockerfile.template Dockerfile-alpine.template
```

Then build all again, commit an push:

```
bash update.sh [0-9]\.[0-9]
bash build_all.sh build_all test_all
git commit -a
git push
```

Then verify the Travis build in the PR.
