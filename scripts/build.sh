#!/bin/bash

set -euo pipefail

input_file=$1
output_file=$2
git_revision_file=$3

pandoc "$input_file" \
 --output "$output_file" \
 --template ../templates/post.html \
 --variable rev:"$(cat "$git_revision_file")" \
 --to=html5