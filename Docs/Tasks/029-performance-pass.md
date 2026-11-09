# Task 029 — Performance pass

| | |
|---|---|
| **Phase** | 6 — Quality & acceptance |
| **Depends on** | 017–024 |
| **Primary references** | [Functional specification](../functional-specification.md) NFR-3 (performance), FR-11 (local storage) · [iCloud sync](../icloud-sync.md) §4 (image layout) · [Architecture](../architecture.md) §Testing strategy |

## Objective

Verify (and where needed, fix) that the app stays fluid and lean on real hardware with a realistic wardrobe size — lazy rendering, correct image sizes, fast filters, smooth scrolling — closing NFR-3 (*fast, responsive, and smooth on the supported form factors*). The user story: *as a user with hundreds of items, I want the app to scroll smoothly and find items instantly, on phone as well as on Mac.*

## What the agent must do

### 1. Seed a realistic wardrobe

Add a **test/dev seeding helper** (e.g. `test/seed/wardrobe_seed.dart` or a `flutter run`-only dev tool behind a flag) that generates: **300 wearables** (mixed types, colors, tags, some without images, ~200 with real generated images), **50 outfits** (1–6 wearables each, favorited subset), across both repositories via their public API (never direct SQL) — so the seed exercises the real pipeline (image import included).

### 2. Lazy rendering audit

- Every list/grid (Home carousel + both grids, both lists, detail sub-lists, the form's wearable grid) is **builder-based** (`ListView.builder` / `GridView.builder` / slivers) — never a full `children:` materialization. Grep-audit + widget tests asserting only the visible tile count is pumped (018/019 already assert this; extend to Home 017 and the form grid 023).
- Detail pages load the 512 px thumbnails in sub-lists and the ≈ 1600 px original only on the detail's own image (012 rule) — no 1600-px file decoded in a grid tile.

### 3. Image decode & memory

- Grid/carousel tiles use the `thumbs/<kind>/<uuid>.jpg` path; detail pages use the original (path selection asserted in 012 — verify at runtime here).
- With the seeded wardrobe, a long scroll (simulate 200+ tiles) shows bounded memory growth (no unbounded `ImageProvider` accumulation — cache behavior is sane; `MemoryImage` not used for files).

### 4. Filter responsiveness

- Applying any filter (name/type/color/tag, single + combined) re-emits from the repositories with no perceptible delay (NFR-3). With the seeded wardrobe, measure: stream re-emit < 100 ms on device (profile mode). The indexed queries from 003 (`idx_wearables_name`, join indexes) must be what is used — a slow-filter fix means the query, not the UI.

### 5. Scroll performance

- On a seeded device (profile mode), scroll both lists and the Home carousel: **60 fps / no dropped frames** on supported hardware. Profile-mode frame timeline recorded in the Verification log.
- The sync pipeline running in the background (a pending sync) must not jank the UI: repository work happens off the UI path (the pipeline's file I/O + DB writes) — verify a sync run during active scrolling.

### 6. Startup

- Cold start to Home on the seeded wardrobe: the T1 sync run (010) is async — the UI is shown first; assert Home is interactive before the first sync completes (the first-launch flow of iCloud doc §12: pull imports *before* "ready", but the chrome is up).

## Definition of done

**Build** (standard gate): all items pass, including the new perf-related tests.

**Performance constraints:**

- [ ] **Seed helper:** the 300/50 seed exists, runs through the public repository API, and is deterministic (fixed RNG) — usable in tests and on-device.
- [ ] **Lazy rendering:** all lists/grids builder-based (grep audit + tests); with the seeded wardrobe, only visible tiles are pumped in each surface (asserted).
- [ ] **Image sizes:** tiles decode the 512-px thumb; details decode the original (runtime path assertion).
- [ ] **Filter latency:** < 100 ms stream re-emit with the seeded wardrobe (measured, logged).
- [ ] **Scroll:** 60 fps / no dropped frames scrolling seeded lists (profile frame timeline logged).
- [ ] **Memory:** bounded growth across a long scroll (logged measurement).
- [ ] **Background sync:** a sync run during scrolling causes no frame jank (logged).
- [ ] **Startup:** Home is interactive before the first sync completes (test/log).
- [ ] Any fix made is committed with its task reference; regressions get a test.

## Verification log (performance)

| Date | Device / mode | Measurement | Value | Pass |
|---|---|---|---|---|
| — | — | Filter re-emit (seeded) | — | ☐ |
| — | — | Scroll frames (Outfits list) | — | ☐ |
| — | — | Scroll frames (Wearables list) | — | ☐ |
| — | — | Long-scroll memory delta | — | ☐ |
| — | — | Cold start → Home interactive | — | ☐ |

## Out of scope

Profiling beyond NFR-3's bar; introducing a caching layer not in the doc; changing the sync pipeline's scheduling (010).
