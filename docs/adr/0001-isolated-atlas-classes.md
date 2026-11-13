# ADR-0001: Atlas tab uses its own classes, isolated from build calculations

**Status:** Accepted
**Date:** 2026-11-13
**Deciders:** Kristoffer Forsberg

## Context

PoB is a calculation engine. The passive tree code (`PassiveTree`, `PassiveSpec`, `PassiveTreeView`, `TreeTab`) is tightly wired into it:

- Allocating a node sets `build.buildFlag`, which triggers a full recalculation.
- `PassiveTree` runs every node stat through `ModParser`.
- `PassiveSpec` and `PassiveTreeView` read the class start, jewels, items, cluster jewels, timeless jewels, the compare spec and power reports, all through the `build` object.

The atlas tree has the same data shape as the passive tree, but it has no effect on character stats. The hard rule for this project is that nothing may change existing calculation behaviour.

## Decision

Build the Atlas tab from four new classes: `AtlasTree`, `AtlasSpec`, `AtlasTreeView` and `AtlasTab`. They reuse only generic infrastructure: UI controls, `UndoHandler`, `jsonToLua`, image loading and drawing primitives. Existing files get small additive hook-ups only (tab button, view mode, saver registration).

## Options Considered

### Option A: Reuse PassiveTree/PassiveSpec/PassiveTreeView with an "atlas mode" flag
| Dimension | Assessment |
|-----------|------------|
| Complexity | Medium: many `if atlas then` branches across ~6000 lines |
| Risk to calc logic | **High**: touches the hottest calc-adjacent code |
| Maintenance | Poor: every upstream change to these files conflicts with ours |
| Upstream-ability | Low: reviewers will reject mode flags in core classes |

**Pros:** Rendering and pathing come for free.
**Cons:** Changes behaviour of core classes, risks recalcs, and causes constant merge pain.

### Option B: Reuse them with a fake `build` object
| Dimension | Assessment |
|-----------|------------|
| Complexity | Medium |
| Risk to calc logic | Low at runtime, but fragile |
| Maintenance | Poor: breaks silently when upstream reads a new build field |

**Pros:** No edits to core classes.
**Cons:** Hidden coupling. ModParser still runs on atlas stats. Hard to reason about.

### Option C: New parallel Atlas classes (chosen)
| Dimension | Assessment |
|-----------|------------|
| Complexity | Medium: a few hundred lines of rendering/pathing duplicated in a simpler form |
| Risk to calc logic | **None by construction** |
| Maintenance | Good: upstream changes to the passive tree don't touch us |
| Upstream-ability | Good: self-contained feature, small diff in shared files |

**Pros:** Isolation is guaranteed. The code is simpler because there are no jewels, classes or ascendancies.
**Cons:** Some orbit/arc/sprite logic is duplicated from `PassiveTree`/`PassiveTreeView`.

## Trade-off Analysis

The duplicated code is geometry and drawing. It is stable and changes rarely. The risk avoided is silent calc changes in a numbers-first app, which is the project's top anti-goal. Duplication is the cheaper failure mode.

## Consequences

- Easier: proving non-interference (no calc code path references Atlas classes), and rebasing on upstream.
- Harder: if GGG changes tree geometry, both the passive and atlas renderers may need fixes.
- Revisit: if upstream ever extracts a generic "tree renderer", migrate onto it.

## Action Items
1. [x] Implement `AtlasTree`, `AtlasSpec`, `AtlasTreeView`, `AtlasTab`.
2. [x] Hook-ups in `Build.lua` (button, view mode, saver) and `Main.lua` (version list, tree cache) only.
3. [x] Non-interference spec: calc outputs identical with and without an `<Atlas>` section.
