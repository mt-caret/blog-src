#!/bin/bash
# From https://stackoverflow.com/a/70805078
tmp=
trap 'rm -f "$tmp"' EXIT
tmp=$(mktemp)
# shellcheck disable=SC2016
echo '$highlighting-css$' > "$tmp"
# shellcheck disable=SC2016
echo '`test`{.c}' | pandoc --metadata title='-' --highlight-style=haddock --template="$tmp"