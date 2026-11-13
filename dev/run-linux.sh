#!/usr/bin/env bash
set -euo pipefail
root="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
tag="${RPOB_TAG:-v0.3.4}"
toolchain="${RPOB_TOOLCHAIN:-1.90.0}"
src="$root/dev/.rpob/src"
bin="$src/target/release/rusty-path-of-building"
if [ ! -d "$src/.git" ]; then
	git clone --depth 1 --branch "$tag" https://github.com/meehl/rusty-path-of-building "$src"
fi
if [ "$(git -C "$src" describe --tags 2>/dev/null)" != "$tag" ]; then
	git -C "$src" fetch --depth 1 origin tag "$tag"
	git -C "$src" checkout -q "$tag"
	rm -f "$bin"
fi
if [ ! -x "$bin" ]; then
	if command -v rustup >/dev/null; then
		rustup toolchain list | grep -q "^$toolchain" || rustup toolchain install "$toolchain" --profile minimal
		cargo "+$toolchain" build --release --locked --features vendored-lua --manifest-path "$src/Cargo.toml"
	else
		cargo build --release --locked --features vendored-lua --manifest-path "$src/Cargo.toml"
	fi
fi
cd "$root"
exec "$bin" poe1 "$@"
