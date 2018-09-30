# Adding a new version to docker-solr

To add a new version to [the docker-solr repository](https://github.com/docker-solr) you need to make several changes.
See the [official-images](https://github.com/docker-solr/official-images) documentation for some high-level overview.

## Updating the docker-solr repository

First, we need to modify our https://github.com/docker-solr/docker-solr repository for the new version.
To do that, you need a Linux host that runs Docker, and has `git`, `wget` and `gpg` installed.

First, get the repository:

```bash
git clone git@github.com:docker-solr/docker-solr.git

cd docker-solr
```

If you're in Europe, you can override the download file locations for much faster downloads:

```bash
export SOLR_DOWNLOAD_SERVER="http://www-eu.apache.org/dist/lucene/solr"
export archiveUrl="https://www-eu.apache.org/dist/lucene/solr"
```

Run the script that creates a directory for the new version, downloads solr to checksum, and creates a Dockerfile:

```bash
tools/update.sh
git status
```

## Test the new Dockerfile

To test the Dockerfile locally:

```bash
tools/build_all.sh
```

Keep an eye out for "This key is not certified with a trusted signature!"; it would be good to verify the fingerprints with ones you have in your PGP keyring.

To run simple automated tests against the images:

```bash
tools/test_all.sh
```

To manually test a container:

```bash
docker container run --name solr-test -d -p 98983:8983 docker-solr/docker-solr:latest solr-demo
```

Check the logs for startup messages:

```bash
docker container logs solr-test
```

Get the URL of the Solr running on it:

```bash
echo "http://localhost:$(docker port solr-test 8983/tcp| sed 's/^.*://')/"
```

and check that URL in your browser, paying particular attention to the `solr-impl` in the administration interface, which lists the Solr version.
Check for errors under "Logging".

If that looks in order, then clean up the container:

```bash
docker container kill solr-test
docker container rm solr-test
```

and remove our local images:

```bash
docker image list docker-solr/docker-solr | awk '{print $1":"$2}' | xargs -n 1 docker image rm
```

## Commit changes to our local repository

Now we can commit the changes to our repository.

First identify myself:

```bash
git config --global user.email "mak-github@greenhills.co.uk"
git config --global user.name "Martijn Koster"
git config --global push.default simple
```

Check in the changes:

```bash
git status
git add 6.6
git add -A
git commit -m "Add Solr 6.6.0"
git push
git rev-parse HEAD
```

Make note of that git SHA.

Now that this has been committed, we can run the `generate-stackbrew-library.sh`, and save the output:

```bash
./generate-stackbrew-library.sh | tee ../new-versions
```

This requires https://github.com/docker-library/official-images/tree/master/bashbrew to be installed.

## Update our README

Our repository has a README https://github.com/docker-solr/docker-solr/blob/master/README.md which shows
supported tags. This is not consumed by the Docker library team, but is there for the convenience of
our users to update this section, run:

```
tools/update_readme.sh
git diff README.md
```

Then commit and push that change:

```bash
git commit -m "Update README for Solr 6.6.0" README.md
git push
```

That is our repository updated.

## Check the automated build

The check-in will trigger an automated build on https://travis-ci.org/docker-solr/docker-solr.
Verify that that succeeds.

## Update the official-images repository

Now we need to tell the Docker library team about this new version so they can make an official build,
by updating the versions in https://github.com/docker-solr/official-images/blob/master/library/solr
and submitting a Pull Request. We can just make the change on the master branch in our fork.

First we'll sync our fork:

```bash
cd
git clone git@github.com:docker-solr/official-images
cd official-images/
git remote add upstream https://github.com/docker-library/official-images.git
git fetch upstream
git merge upstream/master
git push
```

We'll use the output provided by `generate-stackbrew-library.sh` earlier:

```bash
cat ../new-versions > library/solr 
git diff
```

If that all looks plausible, push to master on our fork:

```bash
git commit -m "Update Solr to 6.6.0" library/solr
git push
```

Now you can create a Pull Request at https://github.com/docker-library/official-images/compare/master...docker-solr:master?expand=1
In the comment section add a link to the announcement email from the archives http://mail-archives.apache.org/mod_mbox/www-announce/
See https://github.com/docker-library/official-images/pulls?q=is%3Apr+solr for older examples

## The docs repository

The Docker library team maintains documentation at https://github.com/docker-solr/docs/tree/master/solr that includes current tags.
These tags will be updated automatically after our PR is merged, so there is no need for us to do anything there.

That's it!
