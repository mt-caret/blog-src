#!/bin/bash

set -euo pipefail

input_file=$1
output_file=$2

pandoc "$input_file" \
 --output "$output_file" \
 --template ../templates/post.html \
 --to=html5