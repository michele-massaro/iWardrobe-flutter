# Task 022 — Wearable form (create & edit)

| | |
|---|---|
| **Phase** | 4 — Features |
| **Depends on** | 008, 013, 015 |
| **Primary references** | [Functional specification](../functional-specification.md) FR-8.3, FR-8.4, FR-8.5, FR-8.6, A-5, A-7, A-8 · [UI & design language](../ui-design.md) §5.8, §10 (validation copy) · [Architecture](../architecture.md) §Navigation & routing (forms as routes) |

## Objective

Deliver the add/edit wearable form (F-08) as a full route with a route-scoped ViewModel: all attributes, optional photo, tags, inline validation, and the repository round-trip that makes the new/changed item appear everywhere. The user story: *as a user, I want to add a new item with its photo and details — or edit an existing one — in one form, with clear feedback on what I must fill in.*

## What the agent must deliver

### 1. `WearableFormViewModel` — `lib/ui/features/wearables/view_models/wearable_form_view_model.dart`

**Route-scoped** (created in the route `builder`; the `:id/edit` route seeds the draft from the existing wearable). Owns the mutable `WearableDraft` (task 002) + validation state:

- Fields: `name` (required), `type` (required — A-5 set), `color?` (optional, A-8), `size?`, `brand?`, `material?`, `notes?`, `tags` (multi), `sourceImagePath?` (**optional** — A-7).
- `validate()` → the missing-requirement set; the form **cannot submit** while incomplete (FR-8.4).
- `submit()`: create → `WearableRepository.create(draft)`; edit → `update(updated)`. On success the view pops; on `WardrobeException` the form shows the mapped snackbar copy (task 024's presentation rules apply here too) and keeps the draft.
- The repository performs the image import pipeline (008/004) from the picker's temp file — the form only hands over the path.

### 2. `WearableFormView` — `lib/ui/features/wearables/views/wearable_form_view.dart`

- **Composes the shared components of task 015** — name field, type chip row, color swatch grid, size/brand/material/notes, tag chip input, image picker tile — inside the documented single-column, centered, `maxWidth: 480` layout (Responsive design doc §5).
- **Validation presentation (FR-8.4):** inline error naming the missing requirement; frozen copy (UI doc §10): "Give it a name." / the type requirement is named inline. Submit button disabled or blocked until valid.
- **Image:** *Take photo* / *Choose from album* (FR-8.3); the tile shows the selected preview; **optional** — a wearable without a photo is valid, and on edit the photo may be **removed** (the detail then shows the type placeholder — FR-8.6).
- **Tags:** add/remove chips (existing wardrobe tags suggested).
- **Save** (primary action) → repository call → pop on success.
- **Edit mode:** the form opens pre-filled; saving bumps `updated_at` (FR-8.5, repository-level).

## Definition of done

**Build** (standard gate): all items pass.

**Widget test constraints** — `test/ui/features/wearables/form/` (fake `WearableRepository` + mocked `image_picker`):

- [ ] **Create happy path:** fill name + type + optional color + tags + photo → submit → repository `create` called with a draft carrying all fields + the temp image path → pop to the list; the new wearable is **first** in the list stream (FR-8.12) and in the Home section (FR-3.7 — assert via the fake stream).
- [ ] **Validation:** submitting with empty name blocks + shows "Give it a name." inline; submitting without a type blocks + names the type requirement (FR-8.4).
- [ ] **Optional fields:** a valid draft with no color/size/brand/material/notes/image stores the nulls (A-7, A-8); the detail renders the type placeholder for the photoless item.
- [ ] **Photo:** picking from album (mocked) sets the preview + temp path; the import is delegated to the repository (assert the draft carries the path, not the file bytes).
- [ ] **Remove photo on edit:** an existing item with a photo → remove → submit → `update` called with `imagePath` cleared → detail shows the placeholder (FR-8.6).
- [ ] **Edit pre-fill:** the `:id/edit` route opens with every field pre-filled from the existing wearable; a single-field edit persists with `updatedAt` bumped (FR-8.5).
- [ ] **Tags:** added chips round-trip into the draft; removed chips are dropped (case-insensitive uniqueness).
- [ ] **Error path:** a repository `ValidationException`/`ImageFileException` → snackbar with the mapped short copy; the draft is kept; the form does not pop.
- [ ] **Layout:** single column centered, `maxWidth: 480`, at 375 / 800 / 1440 px.
- [ ] **Route scoping:** the ViewModel is created on route build and disposed on pop.

**Functional acceptance**

- [ ] The form is a route, not a dialog (FR-8.3; Architecture §Navigation).
- [ ] No `setState` in the view; the draft lives in the ViewModel.
- [ ] Both creation and editing go through the same form code (mode flag), not two forms.

**Out of scope for this task:** the outfit form (023 — it reuses these components + adds the composition grid), delete (024), sync (010).
