# Task 021 — Wearable detail

| | |
|---|---|
| **Phase** | 4 — Features |
| **Depends on** | 008, 012, 013 |
| **Primary references** | [Functional specification](../functional-specification.md) FR-7.1 – FR-7.5 · [UI & design language](../ui-design.md) §5.1, §5.7, §10 · [Responsive design](../responsive-design.md) §5 (Wearable detail row), §6 (two-pane) |

## Objective

Deliver the wearable detail page (F-07): the picture (or type placeholder) as the dominant element, every attribute, tags, dates, favorite toggling, and the edit/delete entry points. The user story: *as a user, I want to open a piece of clothing and see its photo and all details, so I can review, update, or remove it.*

## What the agent must deliver

### 1. `WearableDetailViewModel` — `lib/ui/features/wearables/view_models/wearable_detail_view_model.dart`

**Route-scoped**. Subscribes to `WearableRepository.streamById(id)` (008) → immutable `Wearable?` snapshot (with tags). `null` → gracefully handle a wearable deleted elsewhere (pop / "no longer exists" — the page must never crash). Commands: `toggleFavorite()` (FR-7.4), `edit()`, `delete()` (confirmation is task 024).

### 2. `WearableDetailView` — `lib/ui/features/wearables/views/wearable_detail_view.dart`

- **Image:** `WardrobeImage` (wearable kind), 4:5, at the top, **dominant** (FR-7.1). No image → `WearableTypePlaceholder` of the item's type (A-7, FR-7.1) — a "no photo yet" state, never a broken-image box.
- **Fields (FR-7.2):** name; **type always** (A-5); color **only when set** (A-8 — a colorless wearable shows no color row); size, brand, material, notes — each **only when set**; **tags as chips** (when present).
- **Dates:** created + updated always visible, local timezone formatting (FR-7.3).
- **Favorite:** one-tap heart, immediate, no navigation (FR-7.4, FR-9.3) — the shared `FavoriteHeart`.
- **Actions:** Edit → `/wearables/:id/edit` (task 022), Delete → confirmation (task 024); back → previous screen with state intact (FR-7.5, FR-2.4).
- **Layout:** compact/medium → single column, full-width image; expanded → two-pane — image + details left (`maxWidth: 520`), attribute list right (Responsive design doc §5/§6).

## Definition of done

**Build** (standard gate): all items pass.

**Widget test constraints** — `test/ui/features/wearables/detail/` (fake `WearableRepository`):

- [ ] **Image dominant:** the photo (or placeholder) renders at the top in 4:5 and dominates the page (FR-7.1).
- [ ] **Placeholder:** a wearable with `imagePath == null` shows the type placeholder for its type (A-7).
- [ ] **All fields:** a fully-populated wearable shows name, type, color, size, brand, material, notes, tags (chips), created + updated (FR-7.2).
- [ ] **Optional fields hidden when unset:** each of color/size/brand/material/notes/tags absent → the row absent (A-8); type is never hidden.
- [ ] **Tags:** every tag renders as a chip (multi-tag).
- [ ] **Dates:** local-timezone rendering from fixed UTC inputs (FR-7.3).
- [ ] **Heart:** immediate toggle via the repository command (FR-7.4).
- [ ] **Edit/Delete:** Edit pushes `/wearables/:id/edit`; Delete triggers the confirmation callback.
- [ ] **Deleted elsewhere:** `streamById` → `null` → graceful handling (no crash).
- [ ] **Breakpoints:** single column at 375; two-pane at 1024.
- [ ] **Back:** popping returns with the list state intact (FR-7.5).

**Functional acceptance**

- [ ] The view contains no `setState` for domain state; no repository access outside the ViewModel.
- [ ] Favorite toggled here reflects on Home and in the list immediately (stream-driven — test through the fake repository's stream emission).

**Out of scope for this task:** the delete dialog (024), the form (022), filter behavior (019/008).
