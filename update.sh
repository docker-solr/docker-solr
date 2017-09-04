#!/bin/bash
#
# Usage: bash update.sh x.y.z
#
# This script creates Dockerfiles for Solr versions.
# If you specify a partial version, like '5' or '5.3', it will determine the most recent sub version like 5.3.0.
# We record a checksum in the Dockerfile, for verification at docker build time.
# We verify the content's GPG signature here.
set -e

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

TOP=$PWD
OWNERTRUSTFILE="ownertrust.txt"
KEYSERVERS=(hkp://keyserver.ubuntu.com:80
      ha.pool.sks-keyservers.net
      pgp.mit.edu)

versions=( "$@" )
if [ ${#versions[@]} -eq 0 ]; then
    echo "Usage: bash update.sh [version ...]"
    exit 1
fi
versions=( "${versions[@]%/}" )

function write_files {
    local full_version=$1
    local variant=$2

    # get the right template and target dir for this version and variant
    short_version=$(echo "$full_version" | sed -r -e 's/^([0-9]+.[0-9]+).*/\1/')
    if [[ -z $variant ]]; then
        target_dir="$short_version"
        template=Dockerfile.template
    else
        target_dir="$short_version/$variant"
        template=Dockerfile-$variant.template
    fi

    echo "generating $target_dir"
    mkdir -p "$target_dir"
    <"$template" sed -r \
      -e 's/^(ENV SOLR_VERSION) .*/\1 '"$full_version"'/' \
      -e 's/^(ENV SOLR_SHA256) .*/\1 '"$SHA256"'/' \
      -e 's/^(ENV SOLR_KEYS) .*/\1 '"$KEYS"'/' \
      > "$target_dir/Dockerfile"
    cp -r scripts "$target_dir"
}

function load_keys {
    echo "loading keys"
    export GNUPGHOME="$PWD/.gnupg"
    if [ -d "$GNUPGHOME" ]; then
      echo "using existing .gnupg"
    fi
    # we have a local record with key:owner lines
    while IFS=: read key owner; do
        if gpg --list-keys "$key"  >/dev/null 2>&1; then
          echo "already have key $key"
          continue
        fi
        for keyserver in "${KEYSERVERS[@]}"; do
          echo "fetching key $key from the keyserver $keyserver"
          if gpg --keyserver "$keyserver" --keyserver-options timeout=10 --recv-keys "$key"; then
            break
          else
            echo "failed to get key $key from keyserver $keyserver"
          fi
        done
        if ! gpg --list-keys "$key"  >/dev/null 2>&1; then
          echo "failed to get key $key from any server"
          exit 1
        fi
    done < known_keys.txt
    # create ownertrust to make the warning go away
    true > $OWNERTRUSTFILE
    while IFS=: read key owner; do
        echo "$key:6:" >> $OWNERTRUSTFILE
    done < known_keys.txt
    gpg --import-ownertrust $OWNERTRUSTFILE

    echo
}
load_keys

function download_solr  {
    local full_version=$1
    output="solr-$full_version.tgz"
    if [ -f "$output" ]; then
        return
    fi
    partial_url=$full_version/solr-$full_version.tgz
    download_urls=()
    if [[ ! -z "$SOLR_DOWNLOAD_SERVER" ]]; then
        download_urls+=("$SOLR_DOWNLOAD_SERVER/$partial_url")
    fi
    download_urls+=("$archiveUrl/$partial_url")
    for download_url in "${download_urls[@]}"; do
        echo "Fetching $download_url"
        if wget -nv --output-document="$output" "$download_url"; then
            download_url_used="$download_url"
        else
            echo "Failed to fetch $download_url"
        fi
    done
    if [[ -z "$download_url_used" ]]; then
        echo "Failed to fetch Solr for $full_version"
        exit 1
    fi
}

function verify_checksum {
    local full_version=$1
    local checksum_type=$2
    local checksum_file="solr-$full_version.tgz.$checksum_type"
    local url="$archiveUrl/$full_version/$checksum_file"
    if [ ! -f "$checksum_file" ]; then
        wget -nv --output-document="$checksum_file" "$url"
    fi
    echo "verifying $checksum_type checksum"
    case $checksum_type in
      md5)
        md5sum -c "$checksum_file"
        ;;
      sha1)
        sha1sum -c "$checksum_file"
        ;;
      *)
        echo "unknown checksum type $checksum_type"
        exit 1
        ;;
    esac
}

function verify_signature {
  local full_version=$1

  # get the PGP signature
  if [ ! -f "solr-$full_version.tgz.asc" ]; then
      wget -nv --output-document="solr-$full_version.tgz.asc" "$archiveUrl/$full_version/solr-$full_version.tgz.asc"
  fi

  # verify the signature matches our content
  echo "verifying GPG signature"
  if 5>gpg.status gpg --status-fd 5 --batch --verify "solr-$full_version.tgz.asc" "solr-$full_version.tgz" 2>&1 > gpg.out; then
    # signature verified. set KEYS for write_files
    KEYS=$(awk 'BEGIN { ORS=" "} $1 == "[GNUPG:]" && $2 == "VALIDSIG" { print $3 }' gpg.status|sed '-e s/ $//')
  else
    echo "signature verification failed!"
    if egrep '\[GNUPG:\] NO_PUBKEY' gpg.status; then
      # there was at least one missing key. Help the admin by fetching it from the keyservers
      missing_keys=$(egrep '\[GNUPG:\] NO_PUBKEY' gpg.status|sed -e 's/\[GNUPG:\] NO_PUBKEY //'|sort|uniq)
      for missing_key in $missing_keys; do
        echo "looks like a unknown key was used: $missing_key"
        fingerprint=""
        for keyserver in "${KEYSERVERS[@]}"; do
          if 5>gpg-import.status gpg --keyserver "$keyserver" --keyserver-options verbose,timeout=10 --recv-key "$missing_key"; then
            fingerprint=$(gpg --fingerprint -k "$missing_key" |grep fingerprint|sed -e 's/^.* = //' -e 's/ //g')
            owner=$(gpg --with-colons -k "$fingerprint" |egrep '^pub'| cut -d : -f 10)
            echo "$fingerprint:$owner" >> "$TOP/known_keys.txt"
            break
          else
            if egrep '\[GNUPG:\] NO_DATA' gpg-import.status; then
              echo "and that key appears not to exist on keyserver $keyserver"
            else
              echo "failed to get the key from $keyserver"
            fi
            cat gpg-import.status
          fi
        done
        if [[ -z "$fingerprint" ]]; then
          echo "Failed to retrieve key $missing_key from the keyservers; take extra care verifying, and if it checks out you may need to upload it"
          exit 1
        fi
      done
      git diff "$TOP/known_keys.txt"
      echo "verify that those keys are valid:"
      echo "- see https://httpd.apache.org/dev/verification.html"
      echo "- check your own keyring: gpg --list-sigs --list-options show-uid-validity --fingerprint xxx"
      echo "- committer Fingerprints may be found on http://people.apache.org/committer-index.html"
      echo "- KEYS files are available below https://dist.apache.org/repos/dist/release/lucene/solr/"
      echo "Once confirmed: git commit -m 'Added new key' known_keys.txt"
      echo "Then re-run update.sh"
      echo "If not confirmed: GNUPGHOME='$GNUPGHOME' gpg --delete-key '$missing_key'; git checkout $TOP/known_keys.txt"
    else
      # failed for another reason, like BADSIG
      cat gpg.status
    fi
    exit 1
  fi
}

# Download the checksums/keys from the archive
# You can override this by e.g.: export archiveUrl='http://www-eu.apache.org/dist/lucene/solr'
archiveUrl=${archiveUrl:-'https://archive.apache.org/dist/lucene/solr'}
# Note that the Dockerfile templates have their own defaults and override mechanism. See update.sh.

DOWNLOADS=downloads

upstream_versions='upstream-versions'
curl -sSL "$archiveUrl" | sed -r -e 's,.*<a href="(([0-9])+\.([0-9])+\.([0-9])+)/">.*,\1,' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | sort --version-sort > "$upstream_versions"

mkdir -p "$DOWNLOADS"
for version in "${versions[@]}"; do
    full_version="$(grep "^$version" "$upstream_versions" | tail -n 1)"
    if [[ -z $full_version ]]; then
        echo "Cannot find $version in $archiveUrl"
        exit 1
    fi
    echo "preparing $full_version"

    cd "$DOWNLOADS"
    download_solr "$full_version"

    # The Solr release process publish MD5 and SHA1 checksum files. Check those first so we get a clear
    # early failure for incomplete downloads, and avoid scary-sounding PGP mismatches
    verify_checksum "$full_version" md5
    verify_checksum "$full_version" sha1

    verify_signature "$full_version"

    # We will record a stronger SHA256, for write_files
    SHA256=$(sha256sum "solr-$full_version.tgz" | awk '{print $1}')

    if [ -z "$KEEP_ALL_ARTIFACTS" ]; then
        rm "solr-$full_version.tgz.asc" "solr-$full_version.tgz.sha1" "solr-$full_version.tgz.md5"
        if [ -z "$KEEP_SOLR_ARTIFACT" ]; then
            rm "solr-$full_version.tgz"
        fi
    fi

    cd "$TOP"

    write_files "$full_version"
    write_files "$full_version" 'alpine'
    write_files "$full_version" 'slim'
    echo
done

if [ -f "$OWNERTRUSTFILE" ]; then rm "$OWNERTRUSTFILE"; fi
if [ -f "$upstream_versions" ]; then rm "$upstream_versions"; fi
