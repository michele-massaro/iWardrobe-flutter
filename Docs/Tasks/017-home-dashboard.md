# Task 017 — Home dashboard

| | |
|---|---|
| **Phase** | 4 — Features |
| **Depends on** | 008, 009, 012, 013 |
| **Primary references** | [Functional specification](../functional-specification.md) FR-3.1 – FR-3.7 · [UI & design language](../ui-design.md) §10 (Home copy) · [Responsive design](../responsive-design.md) §5 (Home row) |

## Objective

Deliver the Home tab (F-03) — the app's landing screen with its three sections in the fixed order *Latest outfits → Favorite outfits → Favorite clothes*, per-section empty messages, and the welcoming empty state for a brand-new wardrobe. The user story: *as a user, I want a Home screen that summarizes my latest and favorite items so I land on what I care about most.*

## What the agent must deliver

### 1. `HomeViewModel` — `lib/ui/features/home/view_models/home_view_model.dart`

`ChangeNotifier`, **app scope** (Home is a shell branch and outlives tab switches — Architecture §Dependency injection, scoping rules). Subscribes to repository streams (008/009):

- `streamLatest(limit: 10)` → `latestOutfits` (FR-3.2, A-4),
- `streamFavorite()` (outfits) → `favoriteOutfits` (FR-3.3),
- `streamFavorite()` (wearables) → `favoriteWearables` (FR-3.4),
- plus `streamCount()` from both repositories → `isWardrobeEmpty`.

Exposes immutable snapshots + `isLoading`/`error`; `notifyListeners()` only when a snapshot actually changes (identity check — NFR-3). Every create/edit/delete/favorite change anywhere re-emits through these streams, so Home updates **immediately** (FR-3.7).

### 2. `HomeView` — `lib/ui/features/home/views/home_view.dart`

- **Exactly three sections, in this order** (FR-3.1):
  1. **Latest outfits** — horizontally scrolling carousel of the 10 most recently created outfits (cards ≈ 70% of screen width in compact, larger in expanded); tapping an item opens that outfit's detail page (FR-3.2).
  2. **Favorite outfits** — grid of all favorited outfits (2 columns compact / 3 medium / 4+ expanded via `MaxCrossAxisExtent`); tap → detail (FR-3.3).
  3. **Favorite clothes** — grid of all favorited wearables (same grid rule); tap → wearable detail (FR-3.4).
- **Section-level empty state (FR-3.5):** a section without items stays visible with its short, section-specific message (frozen copy, UI doc §10: "No favorite outfits yet — tap the heart on any outfit" / "No favorite clothes yet — tap the heart on any item"); other sections are unaffected.
- **Welcoming empty state (FR-3.6):** when the wardrobe contains **no outfits and no wearables**, Home shows the welcome state — frozen copy "Your wardrobe is waiting" / "Add a few pieces and compose your first look — everything stays on your device." with CTAs [Add your first wearable] → `/wearables/new` and [Compose your first outfit] → `/outfits/new`.
- **Expanded layout:** the whole page centered with `ConstrainedBox(maxWidth: 1200)` + `Center` (Responsive design doc §5).
- Uses `WardrobeCard`/`WardrobeImage`/`EmptyState` from 012/014 — no bespoke cards.

## Definition of done

**Build** (standard gate): all items pass.

**Widget test constraints** — `test/ui/features/home/` (fake repositories with controllable streams):

- [ ] **Section order:** exactly three section headers render in the order *Latest outfits, Favorite outfits, Favorite clothes* (FR-3.1).
- [ ] **Carousel:** shows the latest **10** outfits (with 15 seeded, the 5 oldest are absent); horizontal scroll; tap opens `/outfits/:id`.
- [ ] **Favorite sections:** favorited outfits/wearables appear; non-favorited do not; tap navigates to the correct detail route.
- [ ] **Per-section empty:** each section can be empty independently and keeps its short frozen message in place while the other sections render.
- [ ] **Welcome state:** shown iff both counts are zero; CTAs navigate to `/wearables/new` and `/outfits/new`; hidden as soon as any item exists.
- [ ] **Live updates (FR-3.7):** emitting a new favorite through the fake outfit stream makes the card appear without a rebuild of the whole app; unfavoriting removes it immediately (FR-9.5); a newly created outfit appears in *Latest outfits* (FR-3.2, FR-8.12).
- [ ] **Lazy grids:** grids are `GridView.builder`-based (no eager materialization).
- [ ] **Breakpoints:** 2/3/4+ columns at 375/744/1024 px; the 1200-px centered constraint at expanded.

**Functional acceptance**

- [ ] Home reads only repository streams through the ViewModel — no direct repository access in the view.
- [ ] All copy verbatim from the UI doc §10 table.

**Out of scope for this task:** the detail/form screens themselves (020–023), the sync status host row (025 — its placement is defined by the responsive doc; the slot is reserved).
