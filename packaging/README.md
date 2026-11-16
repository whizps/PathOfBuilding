# Building and releasing Path of Building with the Atlas tab

`./make-pob` at the repository root builds and tests everything, and can publish a release on your GitHub fork.

## What it produces

| File | What it is |
|---|---|
| `NAME.exe` | Full installer. Installs *Path of Building (Atlas)* next to the official Path of Building (default `%APPDATA%\Path of Building Atlas`). It shares builds and settings with the official version, and updates come from your fork. |
| `NAME-portable.zip` | The same program without installing. Builds are stored next to the program. |
| `NAME-patch.exe` | Adds the Atlas tab to an existing official Path of Building install. Must be re-run after every official update. |

Everything lands in `dist/NAME/` (or `dist/local-DATE-COMMIT/` for a local build), together with `release-notes.md` and a `logs/` folder.

## Usage

```bash
./make-pob                              # build and test locally, publish nothing
./make-pob pob1.0-atlas --dry-run       # build with that name, publish nothing
./make-pob pob1.0-atlas                 # build, test and publish, based on the newest official release
./make-pob pob1.0-atlas -t v2.67.2      # build, test and publish, based on official v2.67.2
./make-pob -t dev                       # build on the newest upstream dev instead of a release
./make-pob --sync                       # merge the official dev branch into yours first
./make-pob --update-atlas               # import new atlas trees from GGG first (commits them)
```

- **Release name:** `NAME` is the name of your release and of its git tag in your fork. It must be new. Your fork already contains every official tag (such as `v2.67.2`), so use your own names like `pob1.0-atlas`.
- **Base version:** `-t` picks the official Path of Building release to build on. The default is the newest one. `-t dev` builds on the newest upstream `dev` instead: the latest changes, but less tested than a release.

## Keeping up with upstream

Your Atlas work lives on the `atlas` branch, which sits on top of upstream's `dev`. The script always fetches upstream itself, so your fork's own copies of `dev` and `master` don't matter.

- `./make-pob --sync` merges upstream `dev` into `atlas` before building. If there is a conflict, the script stops so you can resolve and commit it.
- The release you build is upstream's code (a release tag, or `dev` with `-t dev`) plus your Atlas changes. Your branch only provides the Atlas part.

## What the script does

1. **Checks** the tools (`git`, `python3`, `docker`, `makensis`, `pwsh`, plus `gh` when publishing), the `origin` (official) and `fork` (yours) remotes, and that the working tree is clean when publishing.
2. **Fetches** the official repository and reports how far your branch is behind its `dev` branch. `--sync` merges it.
3. **Builds the Atlas payload** from the current commit with `packaging/build_payload.py`. That's the Atlas files plus the small hook edits, generated from your branch's diff against the official `dev`, in both of Path of Building's class styles.
4. **Tests the patch installer** (`packaging/install.ps1`) on a clean copy of the chosen official release. It installs, reinstalls and uninstalls, and checks that the official files come back byte-identical.
5. **Applies the Atlas tab** to another clean copy of that release. That copy becomes the release.
6. **Runs the tests:**
   - the full test suite on your branch
   - the full suite on the release, including the Atlas specs
   - the ModCache check from the official CI

   A failure only counts if the same test passes without the Atlas tab, so failures that already exist upstream are reported but don't stop the build.
7. **Stages the Windows files** with `packaging/stage_release.py`:
   - It regenerates `manifest.xml` with the official `update_manifest.py`.
   - It points in-app updates at your fork's `atlas-release` branch.
   - It copies exactly the files the official portable release contains.
8. **Builds** `NAME.exe` (`packaging/pob-installer.nsi`), `NAME-patch.exe` (`packaging/patch-installer.nsi`) and `NAME-portable.zip`.
9. **Publishes**, only with a `NAME` and without `--dry-run`:
   - pushes your branch
   - adds a commit with the release files to the fork's `atlas-release` branch, which serves in-app updates
   - tags it `NAME`
   - creates the GitHub release with the three files

## How updates reach your users

An installed or portable copy reads `https://raw.githubusercontent.com/<you>/PathOfBuilding/atlas-release/manifest.xml` to check for updates. Every published release updates that branch, so users get it through the normal *Update* button.

The `atlas-release` branch only ever moves forward: each release commit has the official release and the previous release as parents, so nothing is force-pushed.

## Requirements (Ubuntu / WSL)

```bash
sudo apt install git python3 nsis docker.io
sudo snap install powershell --classic
gh auth login
```

The test image (`ghcr.io/pathofbuildingcommunity/pathofbuilding-tests`) is pulled automatically. A full run takes about 10 minutes: the tests take a few minutes and the full installer about 3.

## Before publishing

Build with `--dry-run` and try `dist/NAME/NAME.exe` on Windows. Then publish with the same name, which rebuilds from the same commit.
