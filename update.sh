#!/bin/bash
#
# Usage: bash update.sh x.y.z
#
# This script runs to create a Dockerfile for a new solr version.
# If you specify a partial version, like '5' or '5.3', it will determine the most recent sub version like 5.3.0.
# We record a checksum in the Dockerfile, for verification at docker build time.
# We verifies the content's GPG signature here. Note that this imports keys to your keychain.
set -e

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

template=Dockerfile.template
alpine_template=Dockerfile-alpine.template
versions=( "$@" )
if [ ${#versions[@]} -eq 0 ]; then
	echo "Usage: bash update.sh [version ...]"
	exit 1
fi
versions=( "${versions[@]%/}" )

# Download solr from a mirror.
# You can override this by e.g.: export mirrorUrl='http://www-eu.apache.org/dist/lucene/solr'
mirrorUrl=${mirrorUrl:-'http://www-us.apache.org/dist/lucene/solr'}
# Download the checksums/keys from the archive (temporarily isabled because the archive is down for the next 3 days)
# You can override this by e.g.: export mirrorUrl='http://www-eu.apache.org/dist/lucene/solr'
#archiveUrl=${archiveUrl:-'https://archive.apache.org/dist/lucene/solr'}
archiveUrl=${archiveUrl:-'http://www-us.apache.org/dist/lucene/solr'}
# Note that the Dockerfile templates have their own defaults and override mechanism. See update.sh.

upstream_versions='upstream-versions'
curl -sSL $archiveUrl | sed -r -e 's,.*<a href="(([0-9])+\.([0-9])+\.([0-9])+)/">.*,\1,' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | sort --version-sort > "$upstream_versions"

for version in "${versions[@]}"; do
	fullVersion="$(grep "^$version" "$upstream_versions" | tail -n 1)"
	(
		set -x

		# get the tgz, so we can checksum it, and verify the signature
		if [ ! -f solr-$fullVersion.tgz ]; then
			wget -nv --output-document=solr-$fullVersion.tgz $mirrorUrl/$fullVersion/solr-$fullVersion.tgz
		fi

		# The Solr release process publish MD5 and SHA1 checksum files. Check those first so we get a clear
		# early failure for incomplete downloads, and avoid scary-sounding PGP mismatches
		if [ ! -f solr-$fullVersion.tgz.sha1 ]; then
			wget -nv --output-document=solr-$fullVersion.tgz.sha1 $archiveUrl/$fullVersion/solr-$fullVersion.tgz.sha1
		fi
		sha1sum -c solr-$fullVersion.tgz.sha1
		if [ ! -f solr-$fullVersion.tgz.md5 ]; then
			wget -nv --output-document=solr-$fullVersion.tgz.md5 $archiveUrl/$fullVersion/solr-$fullVersion.tgz.md5
		fi
		md5sum -c solr-$fullVersion.tgz.md5

		# We'll record a stronger SHA256
		SHA256=$(sha256sum solr-$fullVersion.tgz | awk '{print $1}')

		# get the PGP signature
		if [ ! -f solr-$fullVersion.tgz.asc ]; then
			wget -nv --output-document=solr-$fullVersion.tgz.asc $archiveUrl/$fullVersion/solr-$fullVersion.tgz.asc
		fi

		# Get the code signing keys
		# Per http://www.apache.org/dyn/closer.html and Hoss's message on
		# http://stackoverflow.com/questions/32539810/apache-lucene-5-3-0-release-keys-missing-key-3fcfdb3e
		wget -nv --output-document KEYS https://www.apache.org/dist/lucene/java/$fullVersion/KEYS
		gpg --import KEYS

		# and for some extra verification we check the key on the keyserver too:
		KEY=$(gpg --status-fd 1 --verify solr-$fullVersion.tgz.asc 2>&1 | awk '$1 == "[GNUPG:]" && ($2 == "BADSIG" || $2 == "VALIDSIG") { print $3; exit }')
		gpg --keyserver pgpkeys.mit.edu --recv-key "$KEY"

		# verify the signature matches our content
		gpg --verify solr-$fullVersion.tgz.asc
		# get the full fingerprint (since we only get the "long id" if it was BADSIG before)
		KEY=$(gpg --status-fd 1 --verify solr-$fullVersion.tgz.asc 2>&1 | awk '$1 == "[GNUPG:]" && $2 == "VALIDSIG" { print $3; exit }')

		if [ -z "$KEEP_ALL_ARTIFACTS" ]; then
			rm solr-$fullVersion.tgz.asc solr-$fullVersion.tgz.sha1 solr-$fullVersion.tgz.md5
			if [ -z "$KEEP_SOLR_ARTIFACT" ]; then
				rm solr-$fullVersion.tgz
			fi
		fi

		# write the Dockerfile in a directory named after the major.minor portion of the version number
		short_version=$(echo $fullVersion | sed -r -e 's/^([0-9]+.[0-9]+).*/\1/')
		mkdir -p "$short_version"
		cp $template "$short_version/Dockerfile"
		sed -r -i -e 's/^(ENV SOLR_VERSION) .*/\1 '"$fullVersion"'/' "$short_version/Dockerfile"
		sed -r -i -e 's/^(ENV SOLR_SHA256) .*/\1 '"$SHA256"'/' "$short_version/Dockerfile"
		sed -r -i -e 's/^(ENV SOLR_KEY) .*/\1 '"$KEY"'/' "$short_version/Dockerfile"

		# create the alpine variant
		alpine_dir="$short_version/alpine"
		mkdir -p "$alpine_dir"
		cp $alpine_template "$alpine_dir/Dockerfile"
		sed -r -i -e 's/^(ENV SOLR_VERSION) .*/\1 '"$fullVersion"'/' "$alpine_dir/Dockerfile"
		sed -r -i -e 's/^(ENV SOLR_SHA256) .*/\1 '"$SHA256"'/' "$alpine_dir/Dockerfile"
		sed -r -i -e 's/^(ENV SOLR_KEY) .*/\1 '"$KEY"'/' "$alpine_dir/Dockerfile"
	)
done

if [ -f KEYS ]; then rm KEYS; fi
if [ -f "$upstream_versions" ]; then rm "$upstream_versions"; fi
