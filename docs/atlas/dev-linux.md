# Running the fork on Linux / WSL

PoB's official runtime (SimpleGraphic) only runs on Windows. For development on Linux, including WSL2 on Windows 11, we use [Rusty Path of Building](https://github.com/meehl/rusty-path-of-building). It's a native runtime that also powers the Flathub PoB package. When started from a folder that contains `src/Launch.lua`, it runs that checkout directly, so your local changes are what you see.

## One-time setup

1. Install Rust via rustup: <https://rustup.rs>.
2. Install a C toolchain plus the libraries the build links against:
   ```bash
   sudo apt install build-essential pkg-config libssl-dev libfontconfig1-dev
   ```
3. WSL only: you need WSLg, which is included in Windows 11. Check that `echo $DISPLAY $WAYLAND_DISPLAY` prints something.

## Run

```bash
dev/run-linux.sh
```

The first run does two things:
- clones Rusty Path of Building (pinned tag `v0.3.4`) into `dev/.rpob/src`, and installs the pinned Rust toolchain (1.91.0) next to your default one if it is missing
- builds it with `cargo build --release --features vendored-lua`, which takes a few minutes

Later runs start immediately. `dev/.rpob/` is git-ignored.

To test the Atlas tab:

1. Create or open a build.
2. Click **Atlas** (third row of the left-hand buttons, after Party and Compare).
3. Check that hovering a node shows the path, clicking allocates, and the right panel lists the stats.
4. Switch versions with the **Version** dropdown.

## Tests

Headless tests run in PoB's official test container, so you only need Docker:

```bash
dev/test.sh                          # whole default suite
dev/test.sh TestAtlasTab_spec.lua    # one spec file from spec/System
```

## Updating the runtime

To use a newer Rusty Path of Building release, set `RPOB_TAG`:

```bash
RPOB_TAG=v0.3.5 dev/run-linux.sh
```

To make the new tag the default, change the `tag` default in `dev/run-linux.sh`.

## Notes

- Rendering can differ slightly from the Windows runtime. Always do a final check on Windows before release.
- User data such as settings and builds is stored next to the checkout (`src/Settings.xml`, `src/Builds/`), the same as a Windows dev install. Both paths are git-ignored.
