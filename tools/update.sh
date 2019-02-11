#!/bin/bash
#
# Usage: bash update.sh x.y.z
#
# This script creates Dockerfiles for Solr versions.
# If you specify a partial version, like '5.3', it will determine the most recent sub version like 5.3.0.
# We record a checksum in the Dockerfile, for verification at docker build time.
# We verify the content's GPG signature here.
# We also write a TAGS file with the docker tags for the image.
set -euo pipefail

cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.."

TOP_DIR=$PWD
OWNERTRUSTFILE="ownertrust.txt"
KEYSERVERS=(hkp://keyserver.ubuntu.com:80
      ha.pool.sks-keyservers.net
      pgp.mit.edu)

if (( $# == 0 )); then
  readarray -t x_y_dirs < <(find . -maxdepth 1 -print | sed 's,^\./,,' | \
            grep -E '^[0-9]+\.[0-9]+$' | sort --version-sort)
  set -- "${x_y_dirs[@]}"
  all_dirs=true
else
  all_dirs=false
fi

versions=( "$@" )
versions=( "${versions[@]%/}" )

function write_files {
    local full_version=$1
    local variant=${2:-}

    short_version=$(echo "$full_version" | sed -r -e 's/^([0-9]+.[0-9]+).*/\1/')

    # get the right template and target dir for this version and variant
    if [[ -z $variant ]]; then
        dash_variant=""
        target_dir="$short_version"
        template=Dockerfile.template
    else
        dash_variant="-$variant"
        target_dir="$short_version/$variant"
        template=Dockerfile-$variant.template
    fi

    extra_tags="$short_version$dash_variant"

    for v in $latest_major_versions; do
        if [[ $v == "$full_version" ]]; then
            major_version=$(echo "$full_version" | sed -r -e 's/^([0-9]+).*/\1/')
            extra_tags="$extra_tags $major_version$dash_variant"
        fi
    done
    if [[ $full_version == "$latest_version" ]]; then
        extra_tags="$extra_tags latest$dash_variant"
    fi

    if [[ "$dash_variant" = "-alpine" ]]; then
        # No Java 11 on Alpine; see https://github.com/docker-library/openjdk/issues/177
        FROM=openjdk:8-jre-alpine
    else
        major_version=$(echo "$full_version" | sed -r -e 's/^([0-9]+).[0-9]+.*/\1/')
        minor_version=$(echo "$full_version" | sed -r -e 's/^[0-9]+.([0-9]+).*/\1/')
        # Use Java 9 for Solr >= 7.3
        if (( major_version == 7 && minor_version >= 3 )) || (( major_version > 7)); then
            FROM=openjdk:11-jre$dash_variant
        else
            FROM=openjdk:8-jre$dash_variant
        fi
    fi

    echo "generating $target_dir"
    mkdir -p "$target_dir"
    <"$template" sed -r \
      -e "s/FROM \\\$REPLACE_FROM/FROM $FROM/g" \
      -e "s/\\\$REPLACE_SOLR_VERSION/$full_version/g" \
      -e "s/\\\$REPLACE_SOLR_SHA256/$SHA256/g" \
      -e "s/\\\$REPLACE_SOLR_KEYS/$KEYS/g" \
      > "$target_dir/Dockerfile"
    cp -r scripts "$target_dir"

    if [[ "$all_dirs" == "true" ]]; then
      # The TAGS file will list build_dir:full_version:tags
      # Other scripts in ./tools/ will parse the TAGS file.
      # This is only for local/Travis use; the official library does not use the TAGS file.
      echo "$target_dir:$full_version$dash_variant:$(tr '\n' ' ' <<<"$extra_tags" | sed 's/ $//')" >> "$TOP_DIR/TAGS"
    fi
}

function load_keys {
    echo "loading keys"
    export GNUPGHOME="$TOP_DIR/.gnupg"
    if [ -d "$GNUPGHOME" ]; then
      rm -fr "$GNUPGHOME"
    fi
    # we have a local record with key:owner lines
    while IFS=: read -r key owner; do
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
    while IFS=: read -r key owner; do
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
    if [[ -n "${SOLR_DOWNLOAD_SERVER:-}" ]]; then
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
    if [[ -z "${download_url_used:-}" ]]; then
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
      sha1)
        sha1sum -c "$checksum_file"
        ;;
      sha512)
        sha512sum -c "$checksum_file"
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
    if grep -E '\[GNUPG:\] NO_PUBKEY' gpg.status; then
      # there was at least one missing key. Help the admin by fetching it from the keyservers
      missing_keys=$(grep -E '\[GNUPG:\] NO_PUBKEY' gpg.status|sed -e 's/\[GNUPG:\] NO_PUBKEY //'|sort|uniq)
      for missing_key in $missing_keys; do
        echo "looks like a unknown key was used: $missing_key"
        fingerprint=""
        for keyserver in "${KEYSERVERS[@]}"; do
          echo "trying keyserver $keyserver"
          if 5>gpg-import.status gpg --keyserver "$keyserver" --keyserver-options timeout=10 --recv-key "$missing_key"; then
            fingerprint=$(gpg --fingerprint -k "$missing_key" | grep -E -A 1 '^pub'| tail -n 1|sed -e 's/^.* = //' -e 's/ //g')
            if [[ -z $fingerprint ]]; then
              echo "Could not get fingerprint for $missing_key"
            else
              owner=$(gpg --export "$missing_key" | gpg --list-packets | grep -E '^:user ID packet'| cut -d : -f 3 | sed -e 's/^ //' -e 's/"//g')
              if [[ -z $owner ]]; then
                echo "Could not get owner for $missing_key"
              else
                echo "$fingerprint:$owner" >> "$TOP_DIR/known_keys.txt"
                break
              fi
            fi
          else
            if grep -E '\[GNUPG:\] NO_DATA' gpg-import.status; then
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
      git diff "$TOP_DIR/known_keys.txt"
      echo "verify that those keys are valid:"
      echo "- see https://httpd.apache.org/dev/verification.html"
      echo "- check your own keyring: gpg --list-sigs --list-options show-uid-validity --fingerprint xxx"
      echo "- committer Fingerprints may be found on http://people.apache.org/committer-index.html"
      echo "- KEYS files are available below https://dist.apache.org/repos/dist/release/lucene/solr/"
      echo "Once confirmed: git commit -m 'Added new key' known_keys.txt"
      echo "Then re-run update.sh"
      echo "If not confirmed: GNUPGHOME='$GNUPGHOME' gpg --delete-key '$missing_key'; git checkout $TOP_DIR/known_keys.txt"
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

# To ignore a specific version, for when it's not on the mirrors yet, or bad
#sed -i '/6.6.1/d' "$upstream_versions"

mkdir -p "$DOWNLOADS"

latest_major_versions="$(tac<"$upstream_versions" |sed -E 's/^((([0-9]+)\.[0-9]+)\.[0-9]+)$/\1 \3/'|uniq -f 1|cut -d ' ' -f 1)"
latest_version="$(head -n 1 <<<"$latest_major_versions")"
latest_major="$(sed -E 's/^([0-9]+)\.[0-9]+.*$/\1/' <<<"$latest_version")"
latest_minor="$(sed -E 's/^[0-9]+\.([0-9]+).*$/\1/' <<<"$latest_version")"
latest_major_minor="$latest_major.$latest_minor"
if [[ ! -d "$latest_major_minor" ]]; then
  echo "The latest version of Solr is $latest_version but we have no $latest_major_minor directory; creating"
  echo
  mkdir "$latest_major_minor"
  versions+=("$latest_major_minor")
fi

if [[ "$all_dirs" == "true" ]]; then
  :>TAGS
fi
for version in "${versions[@]}"; do
    full_version="$(grep "^$version" "$upstream_versions" | tail -n 1)"
    if [[ -z $full_version ]]; then
        echo "Cannot find $version in $archiveUrl"
        exit 1
    fi
    echo "preparing $full_version"

    cd "$DOWNLOADS"
    download_solr "$full_version"

    # The Solr release process publish checksum files. Check those first so we get a clear
    # early failure for incomplete downloads, and avoid scary-sounding PGP mismatches
    this_major="$(sed -E 's/^([0-9]+)\.[0-9]+.*$/\1/' <<<"$full_version")"
    this_minor="$(sed -E 's/^[0-9]+\.([0-9]+).*$/\1/' <<<"$full_version")"
    if (( this_major == 7 && this_minor >= 4 )) || (( this_major > 7 )); then
        verify_checksum "$full_version" sha512
    else
        verify_checksum "$full_version" sha1
    fi

    verify_signature "$full_version"

    # We will record a stronger SHA256, for write_files
    SHA256=$(sha256sum "solr-$full_version.tgz" | awk '{print $1}')

    cd "$TOP_DIR"

    write_files "$full_version"
    write_files "$full_version" 'alpine'
    write_files "$full_version" 'slim'
    echo
done

if [ -f "$OWNERTRUSTFILE" ]; then rm "$OWNERTRUSTFILE"; fi
if [ -f "$upstream_versions" ]; then rm "$upstream_versions"; fi

tools/write_travis.sh > .travis.yml

if [[ "$all_dirs" == "false" ]]; then
  echo "WARNING: TAGS was not updated, because directories were specified"
  echo "To update tags, run: ./tools/$(basename "${BASH_SOURCE[0]}")"
fi
