# Task 023 — Outfit form (create & edit)

| | |
|---|---|
| **Phase** | 4 — Features |
| **Depends on** | 009, 013, 015 |
| **Primary references** | [Functional specification](../functional-specification.md) FR-8.2, FR-8.4, FR-8.5, FR-8.6, FR-8.12, A-6, A-7, A-9 · [UI & design language](../ui-design.md) §5.8, §10 (validation copy) |

## Objective

Deliver the add/edit outfit form (F-08): photo (**required**), name, the **multi-select wearable grid** at its heart, occasion/season/notes, inline validation, and the repository round-trip. The user story: *as a user, I want to compose a named look from my existing pieces — with its photo — or edit an existing one, so my favorite combinations are saved.*

## What the agent must deliver

### 1. `OutfitFormViewModel` — `lib/ui/features/outfits/view_models/outfit_form_view_model.dart`

**Route-scoped** (the `:id/edit` route seeds the draft from the existing outfit). Owns the mutable `OutfitDraft` (task 002):

- Fields: `name` (**required**), `sourceImagePath` (**required** — A-7), `wearableIds` (**required, ≥ 1** — A-6), `description?`, `occasion?`, `season?` (A-9 set, optional), `notes?`.
- `validate()` → missing-requirement set; **cannot submit** while incomplete (FR-8.4).
- `submit()`: create → `OutfitRepository.create(draft)`; edit → `update(updated)` (image **replaceable, never removed** — FR-8.6) + `setOutfitWearables` when the composition changed. Success → pop; `WardrobeException` → mapped snackbar, draft kept.
- Exposes the wardrobe's wearables (with images) to the grid from the repository — the grid is a picker over **existing** wearables only.

### 2. `OutfitFormView` — `lib/ui/features/outfits/views/outfit_form_view.dart`

- **Composes task 015's components** (name field, image picker tile, occasion, season selector, notes) + the **multi-select wearable grid** — the form's signature piece:
  - a scrollable grid of the wardrobe's wearables (thumbnail or type placeholder, name, type) with a **selection check** overlay; multi-select; the selected set is the outfit's composition (FR-8.2).
  - the grid works at every breakpoint inside the centered 480-px column (single column, `maxWidth: 480`, Responsive design doc §5).
- **Validation (FR-8.4):** inline errors naming the missing requirement; frozen copy (UI doc §10): name → "Give it a name."; photo → "An outfit needs a photo."; composition → "Pick at least one wearable."
- **Image:** *Take photo* / *Choose from album* (FR-8.2); on edit the photo can be **replaced** but **never removed** (FR-8.6 — no remove affordance in outfit mode, task 015's tile rule).
- **Save** → repository call → pop on success.

## Definition of done

**Build** (standard gate): all items pass.

**Widget test constraints** — `test/ui/features/outfits/form/` (fake `OutfitRepository` + fake `WearableRepository` + mocked `image_picker`):

- [ ] **Create happy path:** photo + name + 2 selected wearables → submit → `create` called with the draft (image temp path, name, both `wearableIds`) → pop; the new outfit is **first** in the Outfits list stream (FR-8.12) and in the Home *Latest outfits* carousel (FR-3.2).
- [ ] **Validation — name:** empty name blocks + "Give it a name." (FR-8.4).
- [ ] **Validation — photo:** no photo blocks + "An outfit needs a photo." (A-7, FR-8.4).
- [ ] **Validation — composition:** zero selected wearables blocks + "Pick at least one wearable." (A-6, FR-8.4).
- [ ] **Multi-select grid:** selecting/deselecting wearables updates the selection set; the wardrobe's full wearable set renders (thumbnails/placeholders + name + type); the selection persists across scroll.
- [ ] **Edit pre-fill:** the `:id/edit` route opens with name, photo, and the exact composition pre-filled; changing two fields + adding one wearable → `update` + `setOutfitWearables` called; `updatedAt` bumped (FR-8.5).
- [ ] **Photo replacement on edit:** replacing the photo updates it; **no** remove path exists (FR-8.6).
- [ ] **Composition change on edit:** removing a wearable from the selection → `setOutfitWearables` called without it; the detail (020) no longer lists it.
- [ ] **Optional fields:** description/occasion/season/notes all optional; "All seasons" stores `Season.allSeasons` (wire `"all_seasons"`, A-9).
- [ ] **Error path:** repository exception → snackbar with mapped copy; draft kept; no pop.
- [ ] **Layout:** single column centered, `maxWidth: 480`, at 375 / 800 / 1440 px.
- [ ] **Route scoping:** ViewModel created on route build, disposed on pop.

**Functional acceptance**

- [ ] The form is a route, not a dialog (FR-8.2).
- [ ] No `setState` in the view; the draft lives in the ViewModel.
- [ ] Create and edit share one form (mode flag).
- [ ] The "outfit always has an image" invariant (A-7) holds at the form level: no code path submits without one.

**Out of scope for this task:** the delete dialog (024), the wearable form (022), sync (010).
