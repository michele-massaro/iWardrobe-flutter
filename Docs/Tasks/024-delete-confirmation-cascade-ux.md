# Task 024 — Delete confirmation & cascade UX

| | |
|---|---|
| **Phase** | 4 — Features |
| **Depends on** | 020, 021 |
| **Primary references** | [Functional specification](../functional-specification.md) FR-8.7 – FR-8.10, FR-9.4 · [UI & design language](../ui-design.md) §10 (delete copy) · [Data model](../data-model-and-database.md) §Invariants & cascade rules |

## Objective

Deliver the **explicit delete confirmation** for both detail pages — with copy that names the item and, for a wearable, how many outfits it is part of — and wire the confirmed delete to the repository cascade so the consequences are immediate and visible everywhere. The user story: *as a user, I want to delete an item or an outfit only after seeing exactly what will happen, and to see the result instantly.*

## What the agent must deliver

### 1. The confirmation dialog (shared by both detail pages)

`lib/ui/core/widgets/delete_confirmation.dart` — a `DialogTheme`-styled confirmation (24 radius, `surface` elevated):

- **Wearable (FR-8.7/8.8):** title names the item ("Delete *<name>**?"); body states the cascade consequence in plain words — frozen copy (UI doc §10): "It will be removed from **N** outfits. An outfit left with no wearables is deleted too." where **N** is the live count of containing outfits (from the repository — computed, not hardcoded).
- **Outfit (FR-8.10):** title names the outfit; body: "Its wearables are kept." (deleting an outfit never deletes its wearables).
- **Actions:** **Cancel** (no-op) · **Delete** (primary, `error`/destructive styling) — both 44 × 44 targets; screen-reader labels on both (NFR-4; audit in 028).

### 2. Wiring on the detail pages

- `WearableDetailView` (021) and `OutfitDetailView` (020) invoke the dialog from their Delete action.
- On **Delete**: call the repository `delete(id)` (the cascade — removal from all outfits, empty-outfit deletion with their image files, FR-8.8/8.9 — is implemented there, 008/009; this task owns the *UX* around it).
- On success: the detail page pops (or shows the graceful gone state, per 020/021) and **every open screen updates immediately** through the streams — the list, Home, and any other detail (FR-8.11, FR-3.7).
- On `WardrobeException`: a snackbar with the mapped short copy (Architecture §Error handling: one snackbar per failed action, no blocking dialog, no stack traces) and the item stays.

### 3. State consequences (verified, not implemented here)

After a confirmed wearable delete: containing outfits lose the piece; an outfit left empty is gone (row + image files); the wearable's files are gone (repository cascade, 008). After a confirmed outfit delete: the outfit + its image files are gone; **every wearable survives** (FR-8.10). The favorite state of survivors is untouched (FR-9.4).

## Definition of done

**Build** (standard gate): all items pass.

**Widget test constraints** — `test/ui/features/…/delete/` (fake repositories; one suite per detail page):

- [ ] **Wearable dialog copy:** the title names the item; the body shows the **correct live N** (seed the wearable into 3 outfits → "3 outfits"; delete two of them → "1 outfit").
- [ ] **Wearable cascade (FR-8.7/8.8/8.9):** confirm → the wearable is removed from every containing outfit; the outfit that survives keeps its other wearables; the outfit left empty is deleted including its image files; the detail page pops.
- [ ] **Outfit dialog copy:** names the outfit; body "Its wearables are kept."
- [ ] **Outfit delete (FR-8.10):** confirm → the outfit row + composition rows + both image files are gone; **all composing wearables still exist** with their rows and image files.
- [ ] **Cancel:** no repository call, no state change (FR-8.7).
- [ ] **Immediate propagation (FR-8.11/3.7):** after confirm, the list page, Home, and any other open screen reflect the deletion without manual refresh (assert via stream emissions through the fakes).
- [ ] **Failure:** a repository exception → snackbar with the mapped copy; the item remains; no crash.
- [ ] **Targets/a11y:** both actions are ≥ 44 × 44; both have screen-reader labels (the full audit is 028 — here assert presence).
- [ ] **Favorites untouched:** a surviving wearable's `isFavorite` is unchanged by the cascade (FR-9.4).

**Functional acceptance**

- [ ] The cascade is **not** re-implemented in the UI — the view calls the repository `delete` once.
- [ ] All copy verbatim from the UI doc §10 table (with the dynamic N).
- [ ] Deleting is always a two-step (tap Delete → confirm) — no single-tap destructive action anywhere.

**Out of scope for this task:** the repository cascade implementation (008/009), sync tombstones (010 — the delete flows through the same `localChanges` event), edit flows.
