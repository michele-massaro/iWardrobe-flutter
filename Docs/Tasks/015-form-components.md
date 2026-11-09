# Task 015 — Shared form components

| | |
|---|---|
| **Phase** | 4 — Features |
| **Depends on** | 011, 012 |
| **Primary references** | [UI & design language](../ui-design.md) §5.8 Form components, §2 Wardrobe color swatches, §10 (validation copy) · [Functional specification](../functional-specification.md) FR-8.2, FR-8.3, FR-8.4, FR-8.6, A-5, A-6, A-7, A-8, A-9 |

## Objective

Deliver the shared form field set used by **both** the wearable and the outfit forms (task 022/023 consume these; the components know nothing about which form hosts them): name field, type chip row, color swatch grid, optional text fields, tag chip input, image picker tile, and season selector — with the documented validation presentation.

## What the agent must deliver

### 1. Components — `lib/ui/core/widgets/form/` (UI doc §5.8)

| Component | Spec |
|---|---|
| **Name field** | Single-line text field; required for both forms; inline error when missing (FR-8.4) |
| **Type chip row** | Six single-select chips: Top, Bottom, Dress, Jacket, Shoes, Accessory (A-5, FR-6.4); required for wearables |
| **Color swatch grid** | 7 × 2 grid of the 14 swatches from the UI doc §2 (via the 011 swatch map); single-select, **optional** (A-8); "No color" clears the selection |
| **Size / Brand / Material / Notes** | Optional text fields; shown only as needed |
| **Tag chip input** | Type-ahead chip input: add on entry, remove on tap; multi-value (FR-8.3); existing wardrobe tags offered as suggestions |
| **Image picker tile** | Large 4:5 tile with **Take photo** and **Choose from album** options (`image_picker` — FR-8.2, FR-8.3); **required** for outfits, **optional** for wearables (A-7); on edit an outfit image may be replaced but **never removed** (FR-8.6), while a wearable's image may be removed (after which the placeholder applies) |
| **Season selector** | Single-select: Spring, Summer, Autumn, Winter, All seasons (A-9, FR-8.2) |

### 2. Behavior rules (binding)

- **Validation presentation:** the form does not submit while a required field is missing and shows an **inline error naming the missing requirement** (FR-8.4). Frozen copy (UI doc §10): name missing → "Give it a name."; outfit image missing → "An outfit needs a photo."; no wearable selected → "Pick at least one wearable." (the wearable-selection grid itself lives in the outfit form, task 023 — this task delivers the error-presentation pattern + the two copy owners that belong to form-level fields).
- **Layout:** always a single column, centered, `ConstrainedBox(maxWidth: 480)` + `Center` at **every** breakpoint (Responsive design doc §5, Forms; UI doc §5.8) — readability over width.
- **State ownership:** components are controlled — values come in, edits go out (`onChanged` callbacks). The form ViewModels (022/023) own the `WearableDraft`/`OutfitDraft` (task 002).
- **Image picker seam:** the picker returns a temp file path; the *import* (compression/thumbnails) is the repository's job (008/009 via task 004). The tile only manages selection state + the temp path + the "remove" affordance per kind.
- Hover/focus states on all fields for pointer/keyboard use (NFR-4; the full audit is 028).

## Definition of done

**Build** (standard gate): all items pass.

**Widget test constraints** — `test/ui/widgets/form/` (a minimal harness form that composes the components, with a fake `image_picker` — platform channels mocked or a seam injected):

- [ ] **Name field:** empty submission attempt shows the inline error "Give it a name."; typing clears it.
- [ ] **Type chip row:** single-select across the 6 types; "All"/none state renders; selecting Top then Dress leaves only Dress active.
- [ ] **Color swatch grid:** all 14 swatches render from the 011 map (complete coverage); single-select; "No color" clears (the reported value is `null` — a wearable without color, A-8).
- [ ] **Optional fields:** size/brand/material/notes accept and report text; empty values report `null`.
- [ ] **Tag chip input:** typing + entry adds a chip; tapping a chip removes it; existing tags appear as suggestions; duplicates are not added twice (case-insensitive).
- [ ] **Image picker tile:** *Take photo* and *Choose from album* invoke the (mocked) picker and report the temp path; outfit mode has **no remove** affordance (FR-8.6); wearable mode offers remove; a removed wearable image reports `null`.
- [ ] **Season selector:** single-select across the 5 documented values.
- [ ] **Layout:** the composed form is centered with `maxWidth: 480` at 375, 800, and 1440 px widths (single column at all three).
- [ ] **Error pattern:** the required-field error presentation is inline (not a dialog/snackbar) and names the missing requirement.

**Functional acceptance**

- [ ] No component imports a repository or ViewModel (pure controlled widgets).
- [ ] No hard-coded colors — swatches/tiles come from `AppTheme` (011).
- [ ] `image_picker` interaction is behind an injectable seam (the tests run headless on the host platform).

**Out of scope for this task:** the two form screens/routing/ViewModels (022/023), the outfit wearable multi-select grid (023), draft persistence (repository).
