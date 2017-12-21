#!/bin/bash
#
# Based on https://github.com/docker-library/httpd/blob/master/generate-stackbrew-library.sh
set -eu

declare -A aliases=(
    [7.2]='7 latest'
    [6.6]='6'
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

getArches() {
	local repo="$1"; shift
	local officialImagesUrl='https://github.com/docker-library/official-images/raw/master/library/'

		eval "declare -g -A parentRepoToArches=( $(
		find -path ./builder -prune -o -name 'Dockerfile' -exec awk '
				toupper($1) == "FROM" && $2 !~ /^('"$repo"'|scratch|microsoft\/[^:]+)(:|$)/ {
					print "'"$officialImagesUrl"'" $2
				}
			' '{}' + \
			| sort -u \
			| xargs bashbrew cat --format '[{{ .RepoName }}:{{ .TagName }}]="{{ join " " .TagEntry.Architectures }}"'
	) )"
}
getArches 'solr'

cat <<-EOH
# this file is generated via https://github.com/docker-solr/docker-solr/blob/$(fileCommit "$self")/$self

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
	for variant in '' alpine slim; do
		dir="$version${variant:+/$variant}"
		[ -f "$dir/Dockerfile" ] || continue

		commit="$(dirCommit "$dir")"

    # grep the full version from the Dockerfile, eg: SOLR_VERSION="6.6.1"
		fullVersion="$(git show "$commit":"$dir/Dockerfile" | \
      egrep 'SOLR_VERSION="[^"]+"' | \
      sed -E -e 's/.*SOLR_VERSION="([^"]+)".*$/\1/')"
    if [[ -z $fullVersion ]]; then
      echo "Cannot determine full version from $dir/Dockerfile"
      exit 1
    fi
		versionAliases=(
			$fullVersion
			$version
			${aliases[$version]:-}
		)

		if [ -z "$variant" ]; then
			variantAliases=( "${versionAliases[@]}" )
		else
			variantAliases=( "${versionAliases[@]/%/-$variant}" )
			variantAliases=( "${variantAliases[@]//latest-/}" )
		fi

		variantParent="$(awk 'toupper($1) == "FROM" { print $2 }' "$dir/Dockerfile")"
		variantArches="${parentRepoToArches[$variantParent]}"

		echo
		cat <<-EOE
			Tags: $(join ', ' "${variantAliases[@]}")
			Architectures: $(join ', ' $variantArches)
			GitCommit: $commit
			Directory: $dir
		EOE
	done
done
