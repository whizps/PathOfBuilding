#!/usr/bin/env bash
set -e
root="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
target="${1:+../spec/System/$1}"
shift || true
exec docker run --rm -e HOME=/tmp -w /workdir -v "$root":/workdir:ro \
	ghcr.io/pathofbuildingcommunity/pathofbuilding-tests:latest \
	busted --lua=luajit $target "$@"
