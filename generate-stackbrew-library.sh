#!/usr/bin/env bash
#
# Produce https://github.com/docker-library/official-images/blob/master/library/solr
# Based on https://github.com/docker-library/httpd/blob/master/generate-stackbrew-library.sh
set -eu

declare -A aliases
declare -g -A parentRepoToArches

self="$(basename "${BASH_SOURCE[0]}")"
cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"

declare -a versions
readarray -t versions < <(find . -maxdepth 1 -regex '\./[0-9]+\.[0-9]+' -printf '%f\n' | sort -rV)
latest_version="${versions[0]}"

# make a map from major version to most recent minor, eg 7->7.5
readarray -t versions_increasing < <(printf '%s\n' "${versions[@]}" | tac )
declare -A major_to_minor
for v in "${versions_increasing[@]}"; do
  major="$(sed -E 's/\..*//' <<<"$v")"
  major_to_minor[$major]=$v
done
# invert that to create aliases eg 7.5 -> 7
for major in "${!major_to_minor[@]}"; do
  aliases[${major_to_minor[$major]}]="$major"
done

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
			"$(git show HEAD:./Dockerfile | awk '
				toupper($1) == "COPY" {
					for (i = 2; i < NF; i++) {
						if ($i !~ /^--/) {
							print $i
						}
					}
				}
			')"
	)
}

getArches() {
	local repo="$1"; shift
	local officialImagesUrl='https://github.com/docker-library/official-images/raw/master/library/'

		eval "declare -g -A parentRepoToArches=( $(
		find . -path ./builder -prune -o -name 'Dockerfile' -exec awk '
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

Maintainers: The Apache Lucene/Solr Project <solr-user@lucene.apache.org> (@asfbot),
             Shalin Mangar (@shalinmangar),
             David Smiley (@dsmiley),
             Jan Høydahl (@janhoy)
GitRepo: https://github.com/docker-solr/docker-solr.git
EOH

for version in "${versions[@]}"; do
	for variant in '' slim; do
		dir="$version${variant:+/$variant}"
		[ -f "$dir/Dockerfile" ] || continue

		commit="$(dirCommit "$dir")"

    # grep the full version from the Dockerfile, eg: SOLR_VERSION="6.6.1"
		fullVersion="$(git show "$commit:$dir/Dockerfile" | \
      grep -E 'SOLR_VERSION="[^"]+"' | \
      sed -E -e 's/.*SOLR_VERSION="([^"]+)".*$/\1/')"
    if [[ -z $fullVersion ]]; then
      echo "Cannot determine full version from $dir/Dockerfile"
      exit 1
    fi
		versionAliases=(
			"$fullVersion"
			"$version"
		)

		if [[ -n "${aliases[$version]:-}" ]]; then
            versionAliases=( "${versionAliases[@]}"  "${aliases[$version]:-}" )
		fi
		if [ -z "$variant" ]; then
			variantAliases=( "${versionAliases[@]}" )
        	if [[ $version == "$latest_version" ]]; then
                variantAliases=( "${variantAliases[@]}"  "latest" )
            fi
		else
			variantAliases=( "${versionAliases[@]/%/-$variant}" )
            if [[ $version == "$latest_version" ]]; then
                    variantAliases=( "${variantAliases[@]}"  "$variant" )
             fi
		fi

		variantParent="$(awk 'toupper($1) == "FROM" { print $2 }' "$dir/Dockerfile")"
		variantArches="${parentRepoToArches[$variantParent]}"

		echo
		cat <<-EOE
			Tags: $(sed -E 's/ +/, /g' <<<"${variantAliases[@]}")
			Architectures: $(sed -E 's/ +/, /g' <<<"$variantArches")
			GitCommit: $commit
			Directory: $dir
		EOE
	done
done
