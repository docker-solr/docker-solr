#!/bin/bash
set -e

declare -A aliases
aliases=(
        [6.0]='6 latest'
)

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

versions=( */ )
versions=( "${versions[@]%/}" )
url='git://github.com/docker-solr/docker-solr'

echo '# maintainer: Martijn Koster <mak-github@greenhills.co.uk> (@makuk66)'
echo '# maintainer: Shalin Mangar <shalin@apache.org> (@shalinmangar)'

for version in "${versions[@]}"; do
        if [ ! -f "$version/Dockerfile" ]; then
          continue
        fi

	commit="$(git log -1 --format='format:%H' -- "$version")"
	fullVersion="$(grep -m1 'ENV SOLR_VERSION' "$version/Dockerfile" | cut -d' ' -f3)"
	
	versionAliases=()
	while [ "$fullVersion" != "$version" -a "${fullVersion%[.-]*}" != "$fullVersion" ]; do
		versionAliases+=( $fullVersion )
		fullVersion="${fullVersion%[.-]*}"
	done
	versionAliases+=( $version ${aliases[$version]} )
	
	echo
	for va in "${versionAliases[@]}"; do
		echo "$va: ${url}@${commit} $version"
	done

	for variant in alpine; do
		commit="$(git log -1 --format='format:%H' -- "$version/$variant")"
		echo
		for va in "${versionAliases[@]}"; do
			if [ "$va" = 'latest' ]; then
				va="$variant"
			else
				va="$va-$variant"
			fi
			echo "$va: ${url}@${commit} $version/$variant"
		done
	done
done
