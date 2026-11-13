# ADR-0002: Atlas tree data comes from grindinggear/atlastree-export, committed per version

**Status:** Accepted
**Date:** 2026-11-13
**Deciders:** Kristoffer Forsberg

## Context

The planner must offer every atlas tree version that third-party planners like poeplanner offer. Positions must match the game exactly. Adding a new league's tree must be possible without AI help.

Grinding Gear Games publishes the official atlas tree export at `github.com/grindinggear/atlastree-export`:

- one git tag per version, `3.18.0-atlas` through `3.30.0`, including Ruthless variants
- each tag contains `data.json` and sprite assets
- the format matches the passive tree export that PoB already consumes

## Decision

- Use `atlastree-export` as the single data source.
- A stdlib-only Python 3 script under `src/Export/Atlas/` converts each tag into `src/TreeData/Atlas/<key>/tree.lua` plus the sprite files PoB needs, and regenerates `src/Data/AtlasTreeVersions.lua`.
- The generated files are committed, as PoB does for passive tree data.
- The process is documented in `docs/atlas/importing-atlas-versions.md`.

## Options Considered

### Option A: Scrape poeplanner.com
| Dimension | Assessment |
|-----------|------------|
| Accuracy | Unknown: a third-party copy of the data |
| Stability | Poor: HTML/JS changes break the scraper |
| Legal/etiquette | Questionable |

**Pros:** None that the official export doesn't also give.
**Cons:** Fragile, second-hand, and possibly against the site's terms.

### Option B: Download data at runtime from GitHub
| Dimension | Assessment |
|-----------|------------|
| Repo size | Smallest |
| Offline use | Broken |
| Reliability | Depends on GitHub at runtime |

**Pros:** New versions appear without a PoB update.
**Cons:** PoB is used offline. Network failures turn into broken tabs. Upstream avoids runtime tree downloads (see the disabled `getFile` in `PassiveTree.lua`).

### Option C: Convert official export, commit generated files (chosen)
| Dimension | Assessment |
|-----------|------------|
| Accuracy | Exact: official data |
| Repo size | ~4.5 MB per version (tree.lua + one zoom level of sprites), ~100 MB for all 23 versions |
| Reliability | Works offline, deterministic |
| Upkeep | One script run per league |

**Pros:** Matches how PoB handles passive tree data. Reviewable diffs. Repeatable by a human.
**Cons:** The repo grows with each league. Two schema generations must be supported (`skillSprites` for ≤3.21, `sprites` for newer).

## Trade-off Analysis

Committing the generated data trades repo size for reliability and parity with upstream conventions. Only one zoom level of sprites is stored, so the growth is modest.

## Consequences

- Easier: adding a league means `python3 src/Export/Atlas/import_atlas_tree.py` and a commit.
- Harder: the loader carries a legacy-schema branch.
- Revisit: if GGG stops updating the repo, add a second source behind the same converter.

## Action Items
1. [ ] Write the converter (both schemas, idempotent, single-tag and all-tags modes).
2. [ ] Import every non-RC tag. Resolve duplicate display names (`3.22.0-ruthless` vs `-ruthless-atlas`).
3. [ ] Write `docs/atlas/importing-atlas-versions.md`.
