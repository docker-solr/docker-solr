# Releasing a new version of docker-solr

## Project introduction

This project provides Docker users with a simple way to run [Apache Solr](https://lucene.apache.org/solr/),
by maintaining the 'solr' image in the [Docker Official Images](https://github.com/docker-library/official-images).
To do this, the project uses a separate [docker-solr/docker-solr](https://github.com/docker-solr/docker-solr) Github repository,
which maintains Dockerfiles and creates a [manifest](https://github.com/docker-library/official-images/blob/master/library/solr) which the official images project then incorporates into their repository, which in turn is used by their infrastructure to build the actual images.

To release new versions, we update the files in our repository, build and test locally and in our own CI infrastructure,
then create a PR to update the official images repository. When that PR gets incorporated, new official images are produced.

Because this project is part of the official images repository and built by them, our repository is set up in a specific way
and creates specific artifacts as dictated by them, follows their guidelines, and has to work within their build infrastructure constraints.
At times this may look somewhat odd and restrictive. For example:

- we are restricted on our choice of base images
- we tend to end up with lots of duplicated changes in diffs because we have a lot of nearly-identical Dockerfiles
- we can't use multi-stage Dockerfiles
- we have to do extra verifications at build time

When the official image PR gets reviewed by their team, we occasionally get push-back on specific changes. That then
requires us to fix it in our repo, and update or replace the PR. That can be time-consuming.

## Versioning philosophy

The Solr project releases versions, e.g. 8.3.1.
In docker-solr we take those releases, and create a docker image for each supported version, which then gets tagged e.g. 'solr:8.3.1'.
To reduce the overal build time and storage requirements, we support only a subset of versions, typically the latest versions for each of the recent major versions, and minor revisions in the current major version.
For example, we currently support `8.3.1`, `8.2.0`, `8.1.1`, `8.0.0`, `7.7.2`, `7.6.0`, `7.5.0`, `6.6.6`, `5.5.5`.
We don't support Solr 4 because it's too different; if you must use Solr 4, see https://github.com/docker-solr/docker-solr4.
The reason we support older major versions is to make it easier for users with older configs or plugins to migrate to Docker. In general we recommend using the latest version, which will have the latest security and bug fixes.
The decision to remove support for old versions is somewhat ad-hoc, depending on how many versions there are, how many newer minor versions
there are, and whether there are security vulerabilities or bad bugs.

For each version we build, we create appropriate tags for version aliases.
For example, when `solr:8.3.1` is the latest version, `solr:8.3` and `solr:8` also point to that same image.
The idea is that users will typically choose to specify a `major.minor` version (like `8.3`), which will automatically pick up patch releases
(like a future `8.3.2`), but not new minor releases (like a future `8.4`) which may have new features that may cause behavioural
differences or require changes in configuration, or new major releases (like a future `9`), which maybe not backwards compatible.

The docker-solr scripts in the image, for running Solr, creating collections etc, do not have explicit versioning.
And there is no separate semantic versioning of the docker builds either. For example, if the latest version is `8.3.1`,
and we fix a bug in a docker-solr support script and release that to the official library, then that will create a new
build, with the same `8.3.1` tag. And note that _all_ images will be refreshed, so e.g. `7.7.2` and `5.5.5` will also get
the fix. It is even possible that the official image is rebuilt because the base image received a security update.
The only way to distinguish between images is to track docker image IDs, but in practice I suspect
nobody actually does that. We typically delay releasing script changes until we release a new Solr version, just to reduce
image churn and confusion; and we try hard to stay backwards compatible with any changes we make.

The above approach is not the only possible one. For example, we could create separate versioning tags similar to [Debian](https://www.debian.org/doc/debian-policy/ch-controlfields.html#version) so you get e.g. `solr-8.3.0-123` where the `123` is a packaging release. But that's not something we have provided support for, or discussed with the official images team.

The other issue with versions in Docker images is versioning of other components like the choice and version of OS in the base image, packaging variants, architecture variants, different Java implementations and their versions. We only expose a `-slim` variant tags for a stripped-down base image, beyond that we pick an implementation and version of Java appropriate to a given version of Solr, and use the most recent patch release provided by the base image to get the latest security updates.
The philosophy is that those are implementation details not relevant to "just run Solr".
This is arguably too simplistic when you consider compatibility with user-provided plugins, or a desire to try specific versions of Java to investigate bugs, or version demands set by company security policies etc. To address those you'd have to expose all possible combinations, which would lead to an explosion of complexity, and is not manageable. In those cases we recommend you create a custom image, with your own Dockerfile.


## Build and release overview

When a new Solr release is announced on the [Solr User mailing list](https://lucene.apache.org/solr/community.html#mailing-lists-irc), we aim to create a docker-solr release within a week.

To create a new release, we follow several steps:

- create a new release branch
- update the `docker-solr` repository locally, running scripts that use templates to create separate directories for each versions
- build images locally, and test them locally. You can skip this step if you just want to rely on CI
- push the branch, and verify our CI builds it
- merge the branch into `master` (via a PR if discussion is expected, or directly if not)
- in the official images repo, create a branch, update the manifest, push, and create a PR
- wait for the PR to get merged and builds to be produced
- update our repository's README

These are described in detail below.

We don't typically announce the availability of new images.


## Build environment

The build and test scripts are designed to run on a modern Linux or Mac. Windows users can use Vagrant virtual machine.
Your host needs to have `docker`, `git`, `wget`, `gpg` and `bash` >= 4 installed.
You will also need to install [bashbrew](https://github.com/docker-library/official-images/tree/master/bashbrew) such that it is on your `PATH`.

### Setting up environment on Ubuntu

```bash
sudo apt-get update
sudo apt-get -y install lsof procps curl wget gpg gawk shellcheck vim less git parallel
sudo apt-get -y install docker.io
sudo wget -nv --output-document=/usr/local/bin/bashbrew https://doi-janky.infosiftr.net/job/bashbrew/lastSuccessfulBuild/artifact/bin/bashbrew-amd64
sudo chmod a+x /usr/local/bin/bashbrew
sudo adduser $USER docker
```

### Setting up environment on macOS

Using [Homebrew](https://brew.sh/), install the necessary dependencies for macOS

Above all you need Docker :) If you don't have it you may install with `brew cask install docker`.
You also need the GNU version of some tools.

```bash
brew install gpg  # If you don't have GPG already
brew install git  # If you don't have git already
brew install coreutils wget gawk shellcheck bash parallel findutils  # Other dependencies
sudo wget -nv --output-document=/usr/local/bin/bashbrew https://doi-janky.infosiftr.net/job/bashbrew/lastSuccessfulBuild/artifact/bin/bashbrew-darwin-amd64
sudo chmod a+x /usr/local/bin/bashbrew
```

Before you start running scripts, please run an init script that puts GNU tools first in PATH. The settings only takes effect for the current Terminal window:
```bash
source tools/init_macos.sh
```

### Setting up envionment on Windows

See [vagrant/README.md](vagrant/README.md) for provisioning a builder with Vagrant and Virtualbox.

## Updating the docker-solr repository

Get the docker-solr repository. Make sure you [add your public SSH key to
your GitHub profile](https://help.github.com/en/github/authenticating-to-github/adding-a-new-ssh-key-to-your-github-account) first:

```bash
git clone git@github.com:docker-solr/docker-solr.git

cd docker-solr
```

Create a new branch to work on:

```bash
git checkout -b myrelease
```

Next we run the update script. This will discover any new versions of Solr, and creates a directory for it if needed.
This script will re-generate all the Dockerfiles, using the `Dockerfile*.template` files in the top-level directory.
So don't ever make manual changes to the Dockerfiles, as they will be overridden.

If you're in Europe, you can optionally override the download file locations for much faster downloads:

```bash
export SOLR_DOWNLOAD_SERVER="http://www-eu.apache.org/dist/lucene/solr"
export archiveUrl="https://www-eu.apache.org/dist/lucene/solr"
```

```bash
tools/update.sh
git status
```

Note: when you run this script for the first time, it will download all Solr versions it needs,
and that can take quite a while. Subsequent times it will use previously-downloaded packages.

## Make any modifications you need to the scripts

If you're modifying files in the `./scripts` directory, check if the same changes should apply
to `./scripts-before8`.

Also run `shellcheck` on all scripts: `shellcheck scripts/* scripts-before8*/ tools/*`

## Build the images

To build all the images locally, run:

```bash
tools/build_all.sh
```

This can take a long time, because the builds download the base image, and download the Solr packages again,
for each image. Subsequent builds can be faster due to Docker's layer caching.

To speed up the build by re-using all the Solr tarballs you have locally in ./downloads already, you can start a local
webserver serving these binaries and tell the build to use that server instead of the official ASF ones. First, start
a small webserver in the background, then run the build:

```bash
tools/serve_local.py &
SOLR_DOWNLOAD_SERVER="http://host.docker.internal:8083" tools/build_all.sh
wget -t 1 http://localhost:8083/quit >/dev/null 2>&1
```

Keep an eye out for "This key is not certified with a trusted signature!"; it would be good to verify the fingerprints with ones you have in your PGP keyring.
I typically commit key changes separately from version updates.

There are two scripts directories: `./scripts`, used by `solr:8` which uses the Solr installer, and `./scripts-before8` for older versions which were installed by simply untarring the distribution.
When changing scripts in one of these, remember to review the other directory to see if the same changes apply there.

To run simple automated tests against the images:

```bash
tools/test_all.sh [num-processes]
```

By default tests are run in 2 parallel processes. If you run more powerful hardware, you may want to allocate more resources to Docker and specify 5 or 10 parallel processes, e.g. `tools/test_all.sh 10`.

To manually test a container, use the normal commands from the README, using the tag:

```bash
docker container run --name solr-test -d -p 98983:8983 dockersolr/docker-solr:latest solr-demo
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

and optionally remove our local images:

```bash
docker image list dockersolr/docker-solr | awk '{print $1":"$2}' | xargs -n 1 docker image rm
```

## Commit changes to our local repository and push to Github

Now we can commit the changes to our repository.

Make sure your github configuration has your identity configured. For example (substitute your own values!):

```bash
git config --global user.email "john@example.com"
git config --global user.name "John Doe"
git config --global push.default simple
```

Check in the changes generated by the update script, and any newly added files and directories.
For example:

```bash
git status
git add 6.6
git add --all
git commit -m "Add Solr 6.6.0"
git status
git push
```

After pushing the change, the CI system will build and test the branch.
You can follow progress on https://travis-ci.org/docker-solr/docker-solr and on Github where you branch's last commit should receive a green checkmark.

If that all succeeded, you can merge your branch to master. If your changes warrant further discussion, it is worth creating a PR. If the only change is a simple bug fix or version update, you can just merge to master:

```bash
git checkout master
git merge --squash --no-commit myrelease
git commit
git push
```

## Update the official-images repository

Next we create the [manifest](https://github.com/docker-solr/official-images/blob/master/library/solr) for the Official Images repository.
Essentially this is the build artifact our repsitory created. It refers ito the commits in our repository that we pushed previously.

Still in our repository, run:

```bash
git rev-parse HEAD
```

Make note of that git SHA.

Run the `generate-stackbrew-library.sh`, and save the output:

```bash
./generate-stackbrew-library.sh | tee ../new-versions
```

This script requires https://github.com/docker-library/official-images/tree/master/bashbrew to be installed.

Now we turn to the docker-solr fork of the official-images repository.
Clone the repo, and bring it up-to-date with the latest changes from upstream:

```bash
cd ..
git clone git@github.com:docker-solr/official-images
cd official-images/
git remote add upstream https://github.com/docker-library/official-images.git
git fetch upstream
git merge upstream/master
git push
```

Now copy the manifest provided by `generate-stackbrew-library.sh` earlier:

```bash
cat ../new-versions > library/solr
git diff
```

If that all looks plausible, push to master on our fork:

```bash
git commit -m "Update Solr to 6.6.0" library/solr
git push
```

Now you can create a Pull Request at [here](https://github.com/docker-library/official-images/compare/master...docker-solr:master?expand=1).
In the comment section add a link to the [announcement email from the archives](http://mail-archives.apache.org/mod_mbox/www-announce/).
See [older examples](https://github.com/docker-library/official-images/pulls?q=is%3Apr+solr).
Check the Solr release notes for any new versions, and if there are major changes (CVE fixes, or mandatory config changes or incompatibilities), call them out in the PR description. Mention docker-solr support script changes made since the last update.

Once the PR is created, the CI system will do some sanity and security checking. The team will review the changes, and may comment in the PR. This may take a day or two. These comments need to be responded to and dealt with, by updating the PR with further commits, or closing the PR and creating a new one. Once the team is satisfied, the PR will be merged, and the images will be created.

Check [Docker hub](https://hub.docker.com/_/solr/?tab=tags) to see when the images are ready.

## The docs repository

The Docker library team maintains documentation at https://github.com/docker-solr/docs/tree/master/solr that includes current tags.
These tags will be updated automatically after our PR is merged, so there is no need for us to do anything there.

That's it!
