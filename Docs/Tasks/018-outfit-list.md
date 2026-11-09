# Task 018 — Outfits list

| | |
|---|---|
| **Phase** | 4 — Features |
| **Depends on** | 009, 012, 013, 014 |
| **Primary references** | [Functional specification](../functional-specification.md) FR-4.1 – FR-4.11, FR-8.1 · [Architecture](../architecture.md) §State management (the `OutfitListViewModel` + `OutfitListView` examples) · [Responsive design](../responsive-design.md) §5 (Outfits list row) |

## Objective

Deliver the Outfits tab (F-04): a scrollable, newest-first grid of **all** outfits with the shared filter bar, one-tap favorite hearts, the empty vs no-results states, and the primary add action. The user story: *as a user, I want to browse and filter all my saved looks so I can find — or create — the outfit I need.*

## What the agent must deliver

### 1. `OutfitListViewModel` — `lib/ui/features/outfits/view_models/outfit_list_view_model.dart`

**Route-scoped** (created in the route's `builder`, disposed on pop — task 013). The Architecture doc §State management contains the reference implementation — implement it faithfully:

- Subscribes to `OutfitRepository.streamFiltered(_filter)`; keeps immutable snapshots.
- Filter state: `OutfitFilter` (task 002) with `setFilter` (cancels + re-subscribes — FR-4.6), `clearFilters()`, `hasActiveFilters`.
- `isLoading`, `error` are first-class state (identity-checked `notifyListeners`).
- Commands: `toggleFavorite(id)` (FR-4.8), `create()`/`edit(id)`/`delete(id)` navigation commands (routes from 013).

### 2. `OutfitListView` — `lib/ui/features/outfits/views/outfit_list_view.dart`

- **Presentation:** scrollable grid of **all** outfits, newest first (FR-4.1): 2 columns compact / 3 medium / 4–6 adaptive expanded via `SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 260, childAspectRatio: 0.78)` (Responsive design doc §5/§6).
- **Card:** `WardrobeCard` (outfit variant) — 4:5 image, name, heart overlay (FR-4.2); heart tap toggles favorite immediately with visible feedback, **no navigation** (FR-4.8); any other part of the card opens the detail page (FR-4.9).
- **FilterBar** (task 014) above the grid at every breakpoint: name search + color + tag chips + *Clear filters* (FR-4.3 – FR-4.7).
- **States:** active filters exclude every outfit → `NoResultsState` (names the active filters, offers *Clear filters* — FR-4.10); wardrobe has no outfits at all → `EmptyState` with [Create your first outfit] → `/outfits/new` (FR-4.11). Visually distinct (FR-4.10/4.11).
- **Add action (FR-8.1):** floating action button on compact/medium; equivalent toolbar action on expanded — same command, same route `/outfits/new`.
- Loading: `CenteredLoader` (or equivalent neutral state) while `isLoading`; error: section shows a retry affordance (one bad row never crashes the app).

## Definition of done

**Build** (standard gate): all items pass.

**Widget test constraints** — `test/ui/features/outfits/list/` (fake `OutfitRepository`):

- [ ] **Full list + order:** all seeded outfits render, newest first (FR-4.1, A-3); a newly created outfit appears **first** (FR-8.12).
- [ ] **Card content:** image + name + heart per card (FR-4.2).
- [ ] **Heart toggle:** tapping the heart flips the favorite (callback to repository) with immediate visual feedback and **no** route change (FR-4.8).
- [ ] **Card tap:** tapping anywhere except the heart navigates to `/outfits/:id` (FR-4.9).
- [ ] **Filters:** selecting color narrows to matching outfits (derived — repository-level, fake returns the filtered set); adding a tag narrows further (AND across dimensions); *Clear filters* restores the full list (FR-4.3 – FR-4.7).
- [ ] **No results vs empty:** with active filters and zero matches → `NoResultsState` with the active filters named + *Clear filters*; with zero outfits and no filters → `EmptyState` with the create CTA; the two states are distinguishable in the tree (FR-4.10/4.11).
- [ ] **Add action:** FAB present at 375 px, toolbar action at 1024 px; both open `/outfits/new` (FR-8.1).
- [ ] **Grid columns:** 2 / 3 / 4–6 columns at 375 / 744 / 1024 px (adaptive delegate, not hard-coded counts).
- [ ] **State preservation:** switching away and back (via the shell) restores the active filter + scroll position (FR-2.3 — through the branch stack).
- [ ] **Lazy rendering:** the grid is builder-based; with a large fake wardrobe only visible tiles are pumped.

**Functional acceptance**

- [ ] The view contains no `setState` for domain state; the ViewModel is the only conversation partner.
- [ ] Filter state survives tab switches (branch scope, not widget scope).

**Out of scope for this task:** the detail page (020), the form (023), filter *evaluation* (009), the shared widgets (014 — consumed, not modified).
