# Adding a new version to docker-solr

To add a new version to https://github.com/docker-solr you need to make several changes.
See the https://github.com/docker-solr/official-images documentation for some high-level overview.

## Updating the docker-solr repository

First, we need to modify our https://github.com/docker-solr/docker-solr repository for the new version.
To do that, you need a linux host that runs Docker.
I like to use a docker container that we use for internal builds, that has pre-requisites pre-installed and is known to work, and our developers have locally already. But any Linux should work.

```
docker run --name docker-solr-builder -d -P lucidworks/fusion-builder:openjdk-8

ssh -A -l jenkins -p $(docker port docker-solr-builder 22/tcp | sed 's/.*://') localhost
```

First, get the repository:

```
git clone git@github.com:docker-solr/docker-solr.git

cd docker-solr
```

Run the script that creates a directory for the new version, downloads solr to checksum, and creates a Dockerfile:

```
bash update.sh 5.4.0

ls 5.4
```

## Test the new Dockerfile

To test the Dockerfile locally I configure my environment to point to a Docker host, and run a script:

```
export DOCKER_HOST=tcp://cylon.lan:2375

./build-all.sh
```

Keep an eye out for "This key is not certified with a trusted signature!"; it would be good to verify the fingerprints with ones you have in your PGP keyring.

This will have created the images:

```
docker images | grep docker-solr
```

Now for each of the resulting images, start a container to test:

```
docker run --name solr-test -d -P docker-solr/docker-solr:5.4
```

Get the URL of the Solr running on it:

```
echo "http://$(echo $DOCKER_HOST | sed -e 's,tcp://,,' -e 's,:.*,,'):$(docker port solr-test 8983/tcp| sed 's/^.*://')/"
```

and check that URL in your browser, paying particular attention to the `solr-impl` in the administration interface, which lists the Solr version, and check for errors under "Logging".

If that looks in order, then clean up the container:

```
docker kill solr-test
docker rm solr-test
```

and remove our local images:

```
docker images | grep docker-solr/docker-solr | awk '{print $1 ":" $2}' | xargs -n 1 docker rmi
```

## Update the generate-stackbrew-library.sh

Next we'll modify our `generate-stackbrew-library.sh` script to include the version.

```
vi generate-stackbrew-library.sh
```
and make the aliases section look like for example:
```
aliases=(
        [5.4]='5 latest'
)
```

Then run it, and save the output:

```
bash generate-stackbrew-library.sh | tee ../new-versions
```

## Commit changes to our fork

Now we can commit the changes to our repository.

First identify myself:

```
git config --global user.email "mak-github@greenhills.co.uk"
git config --global user.name "Martijn Koster"
```	

Check in the changes:

```
git add 5.4/Dockerfile generate-stackbrew-library.sh
git commit -m "Add Solr 5.4.0" 
git push
git rev-parse HEAD
```

Make note of that git SHA.

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

Commit and push that change.

That is our repository updated.

## Update the official-images repository

Now we need to tell the Docker library team about this new version so they can make an official build,
by updating the versions in https://github.com/docker-solr/official-images/blob/master/library/solr
and submitting a Pull Request. We can just make the change on the master branch in our fork.
We'll use the output provided by `generate-stackbrew-library.sh` earlier:

```
cd
git clone https://github.com/docker-solr/official-images
cd official-images/
cat ../new-versions > library/solr 
git diff
```

If that all looks plausible, push to master on our fork:

```
git commit -m "Update Solr to 5.4.0" library/solr
```

TODO: is it desirable to include more detail like the release highlights from the announcement email on http://mail-archives.apache.org/mod_mbox/lucene-solr-user/?

Now you can create a Pull Request at https://github.com/docker-library/official-images/compare/master...docker-solr:master?expand=1

## Update the docs repository

The Docker library team maintains documentation at https://github.com/docker-solr/docs/tree/master/solr that includes tags, which will need updating.
TODO: I'm not sure if we're supposed to create a PR to update the tags, or if this happens in an automated fashion after the official-images change above.
Here is how to do it. First get the repo:

```
cd
git clone https://github.com/docker-solr/docs
cd docs
ls solr
```

You'll see there are various components that can be used to generate the `README.md`.
To update:

```
bash update.sh solr
git diff
```

This should show the required changes.

```
git commit -m "Update Solr to 5.4.0" solr/README.md
git push
```

Then create a Pull Request on https://github.com/docker-library/docs/compare/master...docker-solr:docs?expand=1

That's it!
