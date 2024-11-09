#!/bin/bash

set -euo pipefail

dune clean
dune build @runtest @default
rm -rf deploy/*
cp -r _build/default/site/* deploy/
rm -f deploy/dune*
rm -f deploy/static/dune*