# ADR-0004: Atlas share string uses the official pathofexile.com atlas tree link format

**Status:** Accepted
**Date:** 2026-11-13
**Deciders:** Kristoffer Forsberg

## Context

Each atlas tree needs an import/export string, separate from the build code, so it can be shared on its own. The community already shares atlas trees as pathofexile.com and poeplanner links.

## Decision

- Export produces `https://www.pathofexile.com/fullscreen-atlas-skill-tree/<payload>`. The payload is the passive tree v6 binary layout (class 0, ascendancy 0, node list, zero cluster nodes, variant choices as effect/node pairs), base64url-encoded, the same layout PoB uses in `PassiveSpec:EncodeURL`.
- Import accepts that URL or the bare payload. Accepting poeplanner atlas links is a nice-to-have.
- The tree version is chosen in the UI, because the payload's version field does not identify the league.

## Options Considered

### Option A: PoB-only string (compressed XML of the `<Spec>`)
| Dimension | Assessment |
|-----------|------------|
| Interop | None outside PoB |
| Completeness | Full: version, title, variants |

### Option B: Official link format (chosen)
| Dimension | Assessment |
|-----------|------------|
| Interop | Opens on pathofexile.com and is understood by community tools |
| Completeness | Nodes and variant choices, but no title or version |

## Trade-off Analysis

Interop with the official site matters more than carrying the title. The version is visible in the UI and is normally "current league".

## Consequences

- Verified: links exported by PoB open on pathofexile.com with the same allocated nodes.
- Revisit: add poeplanner import if users ask.

## Action Items
1. [x] Confirm the layout against the official site: an exported link opens on pathofexile.com with the same nodes.
2. [x] `AtlasSpec:EncodeURL` / `DecodeURL`, plus a round-trip spec.
