#!/bin/sh
# Full submodule sync: fetch upstream refs, then checkout recorded SHAs.
# Run manually after clone or when bumping vendored extensions — not on every checkout.
set -e
cd "$(git rev-parse --show-toplevel)"
git submodule sync --recursive
git submodule foreach --recursive 'git fetch --prune'
git submodule update --init --recursive
