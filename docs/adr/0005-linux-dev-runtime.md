# ADR-0005: Run the fork on Linux with rusty-path-of-building for development

**Status:** Accepted
**Date:** 2026-11-13
**Deciders:** Kristoffer Forsberg

## Context

The fork targets Windows users, but development happens on Linux (WSL2 with WSLg). PoB's official runtime, SimpleGraphic, is Windows-only. We need a quick way to launch the working copy on Linux and click through the Atlas tab.

## Decision

- Use **rusty-path-of-building**, the native runtime behind the Flathub PoB package. When it is started from a directory containing `src/Launch.lua`, it runs that checkout directly.
- `dev/run-linux.sh` builds it from source on first use (`cargo build --release`, pinned tag) into a git-ignored folder, then launches it from the repo root.
- Windows uses the stock SimpleGraphic runtime.

## Options Considered

### Option A: Wine + bundled `runtime-win32.zip`
| Dimension | Assessment |
|-----------|------------|
| Fidelity | Exact Windows runtime |
| Setup | Wine is not installed. Graphics under WSLg via Wine is often flaky |

### Option B: rusty-path-of-building (chosen)
| Dimension | Assessment |
|-----------|------------|
| Fidelity | High: same Lua code, different renderer |
| Setup | Rust toolchain is already present. One build, about a minute |
| Maintenance | Pin a tag; bump when PoB needs newer runtime APIs |

### Option C: Headless only (busted via Docker)
| Dimension | Assessment |
|-----------|------------|
| Fidelity | Logic only, no UI |

Kept as a complement for automated specs, not as the dev launcher.

## Trade-off Analysis

rusty-pob is native and fast, and is what Linux PoB users actually run. Rendering differences from SimpleGraphic are possible, so a final manual check on Windows is required before any release.

## Consequences

- Easier: edit Lua, run `dev/run-linux.sh`, test.
- Harder: we can only use rendering APIs that both runtimes implement.
- Revisit: if rusty-pob lags behind a SimpleGraphic API that PoB starts using, bump the pinned tag.

## Action Items
1. [ ] `dev/run-linux.sh` plus `docs/atlas/dev-linux.md`.
2. [ ] Verify a window opens under WSLg and the Atlas tab renders.
3. [ ] Final manual pass on Windows.
