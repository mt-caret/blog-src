#!/bin/bash

set -euo pipefail

function metadata() {
    # From https://stackoverflow.com/a/41655605
    tmp=
    trap 'rm -f "$tmp"' EXIT
    tmp=$(mktemp)
    # shellcheck disable=SC2016
    echo '$meta-json$' > "$tmp"
    # shellcheck disable=SC2016
    pandoc "$1" --template="$tmp"
}
export -f metadata

entries=$(
    find ../src -name '*.md' |
    sort -r |
    while read -r file; do 
        slug=$(basename -s .md "$file")
        entry=$(metadata "$file" | jq --compact-output '{date, title, href: "./'"$slug"'.html"}')
        echo "- $entry"
    done
)

title="blog"
echo -e "---\ntitle: $title\nposts:\n$entries\n---" |
pandoc \
 --template ../templates/index.html \
 --variable rev:"$(cat git-revision)" \
 --to=html5