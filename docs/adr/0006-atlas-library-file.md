# ADR-0006: Atlas trees are stored in a per-user atlas library file

**Status:** Accepted (supersedes ADR-0003)
**Date:** 2026-11-13
**Deciders:** Kristoffer Forsberg

## Context

ADR-0003 stored atlas trees inside each build file. In practice this didn't match how players think about the atlas:

- **The atlas is per account.** In-game, the atlas passive tree belongs to the account, not to a character. Players plan one or a few atlas strategies and use them with many builds. Per-build storage meant recreating or copying the same atlas tree in every build.
- **Atlas trees disappeared with the build.** Opening another build showed an empty atlas, and a new build started from scratch.
- **Atlas work could be lost.** An atlas change only reached disk when the build was saved, and an atlas edit marked the build as unsaved even though nothing in the build changed.
- **Older PoB versions drop the data.** Any PoB that doesn't know the `<Atlas>` section drops it on save.

PoB already keeps per-user data that isn't tied to a build (`Settings.xml`, shared items) in the user folder (`main.userPath`, normally `Documents\Path of Building`). That folder survives program updates and reinstalls, the same way the Builds folder does.

## Decision

- Atlas trees live in an atlas library file, `AtlasTrees.xml`, in `main.userPath`, next to `Settings.xml`.
- `AtlasLibrary` loads it once, the first time any build is opened, and holds the list of atlas trees and the active one.
- The Atlas tab shows the library in every build. Every change is written to disk right away, with no save step and no effect on the build's unsaved state.
- Build files no longer get an `<Atlas>` section. A build that has one, from the earlier format, has its atlas trees imported into the library when it is opened. Atlas trees already in the library (same title, version and nodes) and empty ones are skipped. `<Atlas>` is registered as a load-only legacy section.
- Atlas trees are shared with the Export / Import link (ADR-0004), not through build codes.

## Options Considered

### Option A: Keep atlas trees in build files (ADR-0003)
| Dimension | Assessment |
|-----------|------------|
| Matches the game | No: the atlas is per account |
| Persistence | Only when the build is saved; lost if another PoB version re-saves the build |
| Sharing | Comes along in build codes |

### Option B: Library file in the user folder (chosen)
| Dimension | Assessment |
|-----------|------------|
| Matches the game | Yes |
| Persistence | Immediate, survives updates and reinstalls |
| Build files | Untouched, so build codes are as small as before |
| Sharing | Link only |

### Option C: Both (library plus a copy in each build)
| Dimension | Assessment |
|-----------|------------|
| Complexity | High: two sources of truth and conflict resolution |

Rejected.

## Trade-off Analysis

Losing the "atlas trees come along in the build code" behaviour is the main cost. It's outweighed by matching the game's per-account atlas, never losing atlas work, and leaving build files exactly as upstream PoB writes them. That also removes all atlas-related risk from saving and loading builds.

## Consequences

- `Build.lua` needs fewer hooks: no saver registration, no unsaved-flag or `ResetModFlags` hooks, and only a load-only legacy section.
- The library is shared by all builds. Switching builds keeps the selected atlas tree.
- In dev mode, `main.userPath` is the script folder, so `AtlasTrees.xml` is git-ignored.
- Revisit: an option to attach a specific atlas tree to a build, if users ask for per-build atlas trees.

## Action Items
1. [x] `AtlasLibrary` (load, save, import from older build files).
2. [x] `AtlasTab` uses the library and saves on every change.
3. [x] `<Atlas>` becomes a load-only legacy section; saver and unsaved hooks removed.
4. [x] Specs: library round trip, import from build without duplicates, build files contain no `<Atlas>`.
