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

## Update the generate-stackbrew-library.sh

Next we'll modify our `generate-stackbrew-library.sh` script to include the version.

```bash
vi generate-stackbrew-library.sh
```

and make the aliases section look like for example:

```bash
aliases=(
        [6.6]='6 latest'
)
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
our users. We want to update that to add our new version. The Dockerfile URL should point to the
specific version, not just "https://github.com/docker-solr/docker-solr/blob/master/5.4/Dockerfile".
To get the right URL, go the commits https://github.com/docker-solr/docker-solr/commits/master, find the
appropriate commit (typically the most recent one), click on the "<>" button on the right to browse
the repository at that point in the history, then navigate to the directory for the version we've
added, and click on the Dockerfile. Now copy the URL form the url-bar. It should look like
https://github.com/docker-solr/docker-solr/blob/cf53b9b7cd6d7221f9c569f2eef68350dce0d633/5.3/Dockerfile
The commit sha there should match the one we committed earlier.

The versions should be such that the 'latest' tag points to the latest version, the '5.4' tag points
to the latest 5.4, in this case 5.4.0, and the `5` tag points to the latest 5, in thise case also 5.4.0.
For example:

```bash
-       [`5.4.0`, `5.4`, `5`, `latest` (*5.4/Dockerfile*)](https://github.com/docker-solr/docker-solr/blob/3e61ef877ca9d04e7f005cd40ba726abd1f74259/5.4/Dockerfile)
-       [`5.3.1`, `5.3` (*5.3/Dockerfile*)](https://github.com/docker-solr/docker-solr/blob/80ee84f565414c4f1218d39417049049d9f2c0d1/5.3/Dockerfile)
```

Remove any versions that are end-of-life.

Then commit and push that change:

```bash
git commit -m "Update Solr to 5.4.0" README.md
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
git commit -m "Update Solr to 5.4.0" library/solr
git push
```

Now you can create a Pull Request at https://github.com/docker-library/official-images/compare/master...docker-solr:master?expand=1
In the comment section add a link to the announcement email from the archives http://mail-archives.apache.org/mod_mbox/www-announce/
See https://github.com/docker-library/official-images/pulls?q=is%3Apr+solr for older examples

## The docs repository

The Docker library team maintains documentation at https://github.com/docker-solr/docs/tree/master/solr that includes current tags.
These tags will be updated automatically after our PR is merged, so there is no need for us to do anything there.

That's it!
