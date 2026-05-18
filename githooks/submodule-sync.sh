#!/bin/sh
set -e
cd "$(git rev-parse --show-toplevel)"
git submodule sync --recursive
git submodule foreach --recursive 'git fetch --prune'
git submodule update --init --recursive
