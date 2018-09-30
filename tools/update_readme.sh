#!/bin/bash
#
# Update the README
set -eou pipefail
cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.."
outfile="readme-tmp$$"
head -n 2 README.md > "$outfile"
tac TAGS | while read -r line; do
  dir=$(awk --field-separator ':' '{ print $1}' <<<"$line")
  full_version=$(awk --field-separator ':' '{ print $2}' <<<"$line")
  tags=$(awk --field-separator ':' '{ print $3}' <<<"$line")
  commit=$(git log -n 1 --pretty=format:%H -- "$dir/Dockerfile")
  out="- [\`$full_version\`"
  for tag in $tags; do
    out="$out, \`$tag\`"
  done
  out="$out (*$dir/Dockerfile*)](https://github.com/docker-solr/docker-solr/blob/$commit/$dir/Dockerfile)"
  printf '%s\n' "$out" >> "$outfile"
done
printf '\n' >> "$outfile"
grep -A 10000 '^For more information' README.md >> "$outfile"
mv "$outfile" README.md