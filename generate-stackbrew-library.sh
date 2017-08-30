#!/bin/bash
#
# Based on https://github.com/docker-library/elasticsearch/blob/master/generate-stackbrew-library.sh
set -eu

declare -A aliases=(
    [6.6]='6 latest'
    [5.5]='5'
)

self="$(basename "$BASH_SOURCE")"
cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"
extglob_old=$(shopt -p extglob||true)
shopt -s extglob

versions=( +([0-9])\.+([0-9])/ )
eval "$extglob_old"

versions=( "${versions[@]%/}" )

# sort version numbers with highest first
IFS=$'\n'; versions=( $(echo "${versions[*]}" | sort -rV) ); unset IFS

# get the most recent commit which modified any of "$@"
fileCommit() {
	git log -1 --format='format:%H' HEAD -- "$@"
}

# get the most recent commit which modified "$1/Dockerfile" or any file COPY'd from "$1/Dockerfile"
dirCommit() {
	local dir="$1"; shift
	(
		cd "$dir"
		fileCommit \
			Dockerfile \
			$(git show HEAD:./Dockerfile | awk '
				toupper($1) == "COPY" {
					for (i = 2; i < NF; i++) {
						print $i
					}
				}
			')
	)
}

cat <<-EOH
# this file is generated via https://github.com/docker-library/solr/blob/$(fileCommit "$self")/$self

Maintainers: Martijn Koster <mak-github@greenhills.co.uk> (@makuk66),
             Shalin Mangar <shalin@apache.org> (@shalinmangar)
GitRepo: https://github.com/docker-solr/docker-solr.git
EOH

# prints "$2$1$3$1...$N"
join() {
	local sep="$1"; shift
	local out; printf -v out "${sep//%/%%}%s" "$@"
	echo "${out#$sep}"
}

for version in "${versions[@]}"; do
	commit="$(dirCommit "$version")"

	fullVersion="$(git show "$commit":"$version/Dockerfile" | awk '$1 == "ENV" && $2 == "SOLR_VERSION" { gsub(/~/, "-", $3); print $3; exit }')"

	rcVersion="${version%-rc}"

	versionAliases=()
	while [ "$fullVersion" != "$rcVersion" -a "${fullVersion%[.-]*}" != "$fullVersion" ]; do
		versionAliases+=( $fullVersion )
		fullVersion="${fullVersion%[.-]*}"
	done
	versionAliases+=(
		$rcVersion
		${aliases[$version]:-}
	)

	echo
	cat <<-EOE
		Tags: $(join ', ' "${versionAliases[@]}")
		Architectures: amd64, arm32v5, arm32v7, arm64v8, i386, ppc64le, s390x
		GitCommit: $commit
		Directory: $version
	EOE

	for variant in alpine; do
		[ -f "$version/$variant/Dockerfile" ] || continue

		commit="$(dirCommit "$version/$variant")"

		variantAliases=( "${versionAliases[@]/%/-$variant}" )
		variantAliases=( "${variantAliases[@]//latest-/}" )

		echo
		cat <<-EOE
			Tags: $(join ', ' "${variantAliases[@]}")
			GitCommit: $commit
			Directory: $version/$variant
		EOE
	done
done
