# Task 020 — Outfit detail

| | |
|---|---|
| **Phase** | 4 — Features |
| **Depends on** | 009, 012, 013 |
| **Primary references** | [Functional specification](../functional-specification.md) FR-5.1 – FR-5.7 · [UI & design language](../ui-design.md) §10 · [Responsive design](../responsive-design.md) §5 (Outfit detail row), §6 (two-pane) |

## Objective

Deliver the outfit detail page (F-05): the large image, all fields, creation/update dates, the complete list of composing wearables, favorite toggling, and the entry points to edit and delete. The user story: *as a user, I want to open an outfit and see its photo, details, and every piece it contains, so I can review, adjust, or delete it.*

## What the agent must deliver

### 1. `OutfitDetailViewModel` — `lib/ui/features/outfits/view_models/outfit_detail_view_model.dart`

**Route-scoped** (created with the `:id` route, disposed on pop). Subscribes to `OutfitRepository.streamById(id)` (009) → immutable `OutfitWithWearables?` snapshot (`null` → the outfit was deleted elsewhere; the page must handle it gracefully). Commands: `toggleFavorite()` (FR-5.6), `edit()`, `delete()` (navigation/confirmation — the dialog itself is task 024).

### 2. `OutfitDetailView` — `lib/ui/features/outfits/views/outfit_detail_view.dart`

- **Image:** large, at the top, **4:5**, `WardrobeImage` (outfit kind — an outfit always has one, A-7; if the file is missing, the neutral mark). The picture is the **dominant** element (FR-5.1).
- **Fields (FR-5.2):** name; description, occasion, season (displayed **only when set** — "All seasons" renders as "All seasons"), notes; created date and updated date **always** visible, formatted for the local timezone (the data stays UTC).
- **Composing wearables (FR-5.4):** a list of **all** wearables in the outfit — thumbnail (or placeholder), name, type, chevron; **tap → that wearable's detail page** (nested navigation within the same branch — task 013's routes); returning pops back to this outfit.
- **Favorite:** one-tap heart, immediate, no navigation (FR-5.6, FR-9.3) — same `FavoriteHeart` as everywhere.
- **Actions:** Edit → `/outfits/:id/edit` (task 023), Delete → the confirmation flow (task 024). The back gesture/`context.pop()` returns to the **same active tab** with the list state intact (FR-5.5, FR-2.4).
- **Layout (Responsive design doc §5):** compact/medium → single column, full-width image; **expanded → two-pane** — image + details in the left column (`maxWidth: 520`), the composing-wearables list in the right panel.

## Definition of done

**Build** (standard gate): all items pass.

**Widget test constraints** — `test/ui/features/outfits/detail/` (fake `OutfitRepository`):

- [ ] **All fields:** a fully-populated outfit renders image, name, description, occasion, season, notes, created date, updated date (FR-5.2).
- [ ] **Optional fields hidden when unset:** an outfit without description/occasion/season/notes shows none of them (FR-5.2).
- [ ] **Image:** renders at the top in 4:5; it is the dominant element (assert relative size/order).
- [ ] **Composing wearables:** the list contains **every** composing wearable with thumbnail/placeholder, name, type, chevron (FR-5.4); tapping one navigates to `/wearables/:id`.
- [ ] **Nested navigation:** after navigating to a composing wearable's detail, popping returns to this outfit's detail (same route, state intact).
- [ ] **Heart:** toggle fires the repository command; the heart reflects the new state immediately (FR-5.6).
- [ ] **Edit/Delete:** Edit pushes `/outfits/:id/edit`; Delete triggers the confirmation callback (task 024 supplies the dialog; here the wiring must call it).
- [ ] **Deletion elsewhere:** `streamById` emitting `null` (outfit deleted by another device / elsewhere) → the page pops or shows a graceful "no longer exists" state — no crash (FR-5.7).
- [ ] **Dates:** created/updated render in local timezone format (assert with a fixed UTC input).
- [ ] **Breakpoints:** single column at 375 px; two-pane (520 left column + right panel) at 1024 px.
- [ ] **Back:** popping returns to the Outfits branch with its state intact (FR-5.5).

**Functional acceptance**

- [ ] No direct repository access in the view; the ViewModel is the only data source.
- [ ] The page observes the live stream — a favorite toggle from the wearable side or an edit from the form reflects without manual refresh.

**Out of scope for this task:** the delete dialog (024), the edit form (023), sync application (010).
