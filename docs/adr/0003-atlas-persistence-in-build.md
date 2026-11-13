# ADR-0003: Atlas trees are saved as an `<Atlas>` section of the build file

**Status:** Superseded by ADR-0006
**Date:** 2026-11-13
**Deciders:** Kristoffer Forsberg

## Context

Users plan one or more atlas trees ("Breach farming", "Essence + Harvest") alongside a build, and expect them to still be there when the build is reopened. PoB already saves each tab as its own XML section through `build.savers`. A PoB build code is the compressed build XML, so anything in the build file is also in the build code.

## Decision

- Add a top-level `<Atlas activeSpec="n">` section containing one `<Spec title treeVersion nodes>` per named atlas tree, with `<Variant nodeId effect>` children for variant notables.
- `AtlasTab` is registered in `build.savers` under `"Atlas"`.
- Atlas edits set `build.modFlag` (unsaved changes) and never `build.buildFlag` (recalculation).

## Options Considered

### Option A: Separate file / global settings, not per build
| Dimension | Assessment |
|-----------|------------|
| Complexity | Medium: new storage location and lifecycle |
| User model | Atlas detached from the build it belongs to |

**Pros:** Build files stay untouched.
**Cons:** The plan doesn't travel with the build. Extra file handling on Windows and Linux.

### Option B: Section in the build file (chosen)
| Dimension | Assessment |
|-----------|------------|
| Complexity | Low: uses the existing saver mechanism |
| Compatibility | Older PoB versions ignore unknown sections |
| Side effect | Atlas trees ride along in shared build codes |

**Pros:** Zero new storage plumbing. Save/undo/modified indicators work as everywhere else.
**Cons:** Build codes get slightly longer.

## Trade-off Analysis

Embedding in the build file is the conventional PoB approach and costs only a few hundred bytes per atlas tree. Upstream PoB ignores the unknown section, so files stay compatible both ways.

## Consequences

- A build without `<Atlas>` loads with one empty atlas tree at the default version and no other change.
- The version key in `treeVersion` is persisted, so version keys must stay stable forever.
- Revisit: if build-code length becomes a complaint, add an option to strip `<Atlas>` from exported codes.

## Action Items
1. [x] `AtlasTab:Load(xml)` / `AtlasTab:Save(xml)`, plus registration in `Build.lua` savers.
2. [x] Round-trip spec: save → load gives identical specs.
3. [x] Spec: legacy build with no `<Atlas>` has unchanged calc output.
