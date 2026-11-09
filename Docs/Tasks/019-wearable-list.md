# Task 019 — Wearables list

| | |
|---|---|
| **Phase** | 4 — Features |
| **Depends on** | 008, 012, 013, 014 |
| **Primary references** | [Functional specification](../functional-specification.md) FR-6.1 – FR-6.11, FR-8.1, §5.6 filter matrix · [Responsive design](../responsive-design.md) §5 (Wearables list row) |

## Objective

Deliver the Wearables tab (F-06): a scrollable, newest-first grid of **all** wearables with the full filter set (name, type, color, tag), one-tap hearts, empty vs no-results states, and the add action. The user story: *as a user, I want to browse and filter every piece I own so I can find a specific item even in a large wardrobe.*

## What the agent must deliver

### 1. `WearableListViewModel` — `lib/ui/features/wearables/view_models/wearable_list_view_model.dart`

**Route-scoped** (same pattern as task 018, with `WearableRepository` from 008):

- Subscribes to `streamFiltered(_filter)`; immutable snapshots; `isLoading`/`error` first-class.
- Filter state: `WearableFilter` — `nameSubstring`, `type?` (single-select, A-5 set), `color?` (single-select, A-8), `tagIds` (multi-select OR) — with `setFilter`/`clearFilters`/`hasActiveFilters`.
- Commands: `toggleFavorite(id)` (FR-6.8), navigation to create/edit/delete routes (013).

### 2. `WearableListView` — `lib/ui/features/wearables/views/wearable_list_view.dart`

- **Presentation:** scrollable list (grid layout on wide windows — FR-6.1): 2 columns compact / 3–4 medium / 4–6 adaptive expanded (`MaxCrossAxisExtent`, Responsive design doc §5/§6).
- **Card:** `WardrobeCard` (wearable variant) — image **or type-based placeholder** when the wearable has no image (A-7, FR-6.2), name, type, heart overlay.
- **FilterBar** above the grid at every breakpoint with the **four** dimensions: name search + type + color + tag chips + *Clear filters* (FR-6.3 – FR-6.7).
- **Interaction:** heart tap toggles favorite immediately without navigation (FR-6.8); any other part of the card opens the wearable detail (FR-6.9).
- **States:** filters exclude everything → `NoResultsState` ("No clothes match" + *Clear filters*, FR-6.10); no wearables at all → `EmptyState` ("No clothes yet" + [Add your first wearable] → `/wearables/new`, FR-6.11). Visually distinct.
- **Add action (FR-8.1):** FAB compact/medium, toolbar action expanded → `/wearables/new`.
- Loading/error presentation as in task 018.

## Definition of done

**Build** (standard gate): all items pass.

**Widget test constraints** — `test/ui/features/wearables/list/` (fake `WearableRepository`):

- [ ] **Full list + order:** all seeded wearables render newest first (FR-6.1, A-3); a new one appears first (FR-8.12).
- [ ] **Card content:** image + name + type (FR-6.2); a wearable with `imagePath == null` shows the **type placeholder**, not a broken image (A-7).
- [ ] **Heart toggle:** immediate, visible, no navigation (FR-6.8).
- [ ] **Card tap:** opens `/wearables/:id` (FR-6.9).
- [ ] **Type filter:** single-select over exactly the 6 documented types (A-5); only matching wearables render.
- [ ] **Color filter:** single-select; a wearable **without** a color never matches (A-8, FR-6.5 — assert with a colorless item present).
- [ ] **Tag filter:** multi-select OR; a wearable with any selected tag matches (FR-6.6).
- [ ] **AND across dimensions:** name + type + color + tags combined narrows to the intersection (FR-6.7); *Clear filters* restores everything.
- [ ] **No results vs empty:** distinct states with the frozen copy (FR-6.10/6.11).
- [ ] **Add action:** FAB vs toolbar action by breakpoint; both open `/wearables/new` (FR-8.1).
- [ ] **Grid columns:** 2 / 3–4 / 4–6 at 375 / 744 / 1024 px.
- [ ] **State preservation:** filter + scroll survive tab switches (FR-2.3).
- [ ] **Lazy rendering:** builder-based grid.

**Functional acceptance**

- [ ] The filter matrix of functional spec §5.6 is satisfied for this page (name / color / type / tag / combination) — cross-check each row.
- [ ] The view contains no `setState` for domain state.

**Out of scope for this task:** the detail page (021), the form (022), filter evaluation (008), shared widgets (014).
