#!/bin/bash
#
# Usage: bash update.sh x.y.z
#
# This script runs to create a Dockerfile for a new Solr version.
# If you specify a partial version, like '5' or '5.3', it will determine the most recent sub version like 5.3.0.
# We record a checksum in the Dockerfile, for verification at docker build time.
# We verify the content's GPG signature here. Note that this imports keys to your keychain.
set -e

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

GPG_KEYSERVER=${GPG_KEYSERVER:-hkp://pool.sks-keyservers.net}

versions=( "$@" )
if [ ${#versions[@]} -eq 0 ]; then
    echo "Usage: bash update.sh [version ...]"
    exit 1
fi
versions=( "${versions[@]%/}" )

function write_files {
    local full_version=$1
    local variant=$2

    short_version=$(echo $full_version | sed -r -e 's/^([0-9]+.[0-9]+).*/\1/')
    if [[ -z $variant ]]; then
        target_dir="$short_version"
        template=Dockerfile.template
    else
        target_dir="$short_version/$variant"
        template=Dockerfile-$variant.template
    fi

    mkdir -p "$target_dir"
    cp $template "$target_dir/Dockerfile"
    cp -r scripts "$target_dir"
    sed -r -i -e 's/^(ENV SOLR_VERSION) .*/\1 '"$full_version"'/' "$target_dir/Dockerfile"
    sed -r -i -e 's/^(ENV SOLR_SHA256) .*/\1 '"$SHA256"'/' "$target_dir/Dockerfile"
    sed -r -i -e 's/^(ENV SOLR_KEY) .*/\1 '"$KEY"'/' "$target_dir/Dockerfile"
}

# Download the checksums/keys from the archive
# You can override this by e.g.: export archiveUrl='http://www-eu.apache.org/dist/lucene/solr'
archiveUrl=${archiveUrl:-'https://archive.apache.org/dist/lucene/solr'}
# Note that the Dockerfile templates have their own defaults and override mechanism. See update.sh.

DOWNLOADS=downloads

upstream_versions='upstream-versions'
curl -sSL $archiveUrl | sed -r -e 's,.*<a href="(([0-9])+\.([0-9])+\.([0-9])+)/">.*,\1,' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | sort --version-sort > "$upstream_versions"

mkdir -p $DOWNLOADS
for version in "${versions[@]}"; do
    full_version="$(grep "^$version" "$upstream_versions" | tail -n 1)"
    if [[ -z $full_version ]]; then
        echo "Cannot find $version in $archiveUrl"
        exit 1
    fi
    (
        set -x

        cd $DOWNLOADS

        # get the tgz, so we can checksum it, and verify the signature
        output=solr-$full_version.tgz
        partial_url=$full_version/solr-$full_version.tgz
        download_urls=()
        if [[ ! -z "$SOLR_DOWNLOAD_SERVER" ]]; then
            download_urls+=("$SOLR_DOWNLOAD_SERVER/$partial_url")
        fi
        download_urls+=("$archiveUrl/$partial_url")
        for download_url in $download_urls; do
            echo "Fetching $download_url"
            if wget -nv --output-document=$output $download_url; then
                download_url_used=$download_url
            else
                echo "Could not fetch $download_url"
            fi
        done
        if [[ -z "$download_url_used" ]]; then
            exit 1
        fi

        # The Solr release process publish MD5 and SHA1 checksum files. Check those first so we get a clear
        # early failure for incomplete downloads, and avoid scary-sounding PGP mismatches
        if [ ! -f solr-$full_version.tgz.sha1 ]; then
            wget -nv --output-document=solr-$full_version.tgz.sha1 $archiveUrl/$full_version/solr-$full_version.tgz.sha1
        fi
        sha1sum -c solr-$full_version.tgz.sha1
        if [ ! -f solr-$full_version.tgz.md5 ]; then
            wget -nv --output-document=solr-$full_version.tgz.md5 $archiveUrl/$full_version/solr-$full_version.tgz.md5
        fi
        md5sum -c solr-$full_version.tgz.md5

        # We will record a stronger SHA256
        SHA256=$(sha256sum solr-$full_version.tgz | awk '{print $1}')

        # get the PGP signature
        if [ ! -f solr-$full_version.tgz.asc ]; then
            wget -nv --output-document=solr-$full_version.tgz.asc $archiveUrl/$full_version/solr-$full_version.tgz.asc
        fi

        # Get the code signing keys
        # Per http://www.apache.org/dyn/closer.html and a message from Hoss on
        # http://stackoverflow.com/questions/32539810/apache-lucene-5-3-0-release-keys-missing-key-3fcfdb3e
        wget -nv --output-document KEYS $archiveUrl/$full_version/KEYS
        gpg --import KEYS

        # and for some extra verification we check the key on the keyserver too:
        KEY=$(gpg --status-fd 1 --batch --verify solr-$full_version.tgz.asc solr-$full_version.tgz 2>&1 | awk '$1 == "[GNUPG:]" && ($2 == "BADSIG" || $2 == "VALIDSIG") { print $3; exit }')
        gpg --keyserver "$GPG_KEYSERVER" --recv-key "$KEY" || {
            echo "Failed to get the key from the key server"
            exit 1
        }

        # verify the signature matches our content
        gpg --batch --verify solr-$full_version.tgz.asc solr-$full_version.tgz
        # get the full fingerprint (since we only get the "long id" if it was BADSIG before)
        KEY=$(gpg --status-fd 1 --batch --verify solr-$full_version.tgz.asc solr-$full_version.tgz 2>&1 | awk '$1 == "[GNUPG:]" && $2 == "VALIDSIG" { print $3; exit }')

        if [ -z "$KEEP_ALL_ARTIFACTS" ]; then
            rm solr-$full_version.tgz.asc solr-$full_version.tgz.sha1 solr-$full_version.tgz.md5
            if [ -z "$KEEP_SOLR_ARTIFACT" ]; then
                rm solr-$full_version.tgz
            fi
        fi

        cd ..

        write_files $full_version
        write_files $full_version 'alpine'
    )
done

if [ -f $DOWNLOADS/KEYS ]; then rm $DOWNLOADS/KEYS; fi
if [ -f "$upstream_versions" ]; then rm "$upstream_versions"; fi
