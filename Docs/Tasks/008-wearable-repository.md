# Task 008 — WearableRepository

| | |
|---|---|
| **Phase** | 2 — Data layer |
| **Depends on** | 003, 004, 007 |
| **Primary references** | [Data model & local database](../data-model-and-database.md) §Repository API surface, §Invariants & cascade rules, §Data flow example · [Functional specification](../functional-specification.md) FR-6.x, FR-8.x, FR-9.x, A-2, A-3, A-8 |

## Objective

Deliver the repository that is the **single source of truth** for wearables + tags: live filtered streams, CRUD with validation, favorite toggling, and the delete cascade that removes a wearable from every outfit and deletes outfits left empty. It is the only layer the UI (via ViewModels) may call for this aggregate, and the seam the sync pipeline reads at push time.

## What the agent must deliver

### 1. Public interface — exactly the documented API

`abstract interface class WearableRepository` (full signature in the Data model doc §Repository API surface):

```dart
Stream<List<Wearable>> streamFiltered(WearableFilter filter);  // newest first (A-3)
Stream<List<Wearable>> streamFavorite();                       // Home *Favorite clothes*
Stream<Wearable?> streamById(String id);                       // with tags; null when gone
Stream<int> streamCount();                                      // Home empty-wardrobe state
Future<Wearable> create(WearableDraft draft);                   // FR-8.3/8.4, one transaction
Future<Wearable> update(Wearable updated);                     // bumps updatedAt, replaces tags
Future<void> toggleFavorite(String id);                         // FR-6.8, FR-9.3
Future<void> delete(String id);                                 // cascade FR-8.8/8.9
Stream<SyncChangeEvent> get localChanges;                       // consumed by SyncRepository (010)
```

The implementation (`WearableRepositoryImpl`) consumes `DatabaseService` + `ImageFileService` and exposes immutable domain models only.

### 2. Query semantics (binding — filter matrix, functional spec §5.6)

- **Newest first:** every stream orders by `created_at DESC` (A-3) — a newly created item appears first (FR-8.12).
- **Name:** case-insensitive substring (FR-6.3).
- **Type:** single value equality from the A-5 set (FR-6.4).
- **Color:** single value; a row with `color IS NULL` **never matches** (A-8, FR-6.5).
- **Tags:** multi-select, **OR within the dimension**, **AND across dimensions** (A-2, FR-6.6/6.7).
- Streams emit a fresh immutable snapshot (new `List` of immutable models) whenever the underlying data **or the filter** changes, so every subscribed screen updates immediately (FR-8.11, FR-3.7). Re-subscription on filter change is the ViewModel's job (018); the repository must re-emit promptly on any mutation.

### 3. Mutation semantics

- **`create`** (FR-8.3/8.4): validate — `name` non-empty, `type` set; otherwise throw `ValidationException` naming the missing requirement. Generate UUID v4; if the draft carries a source image, run the `ImageFileService` import pipeline (1600 px + 512 px thumb) **before** the row write; insert `wearables` row, `tags` rows (reused by case-insensitive name when they exist), and `wearable_tags` links **in a single `drift` transaction** (FR-11.1). Emit `SyncChangeEvent.created`.
- **`update`** (FR-8.5): update fields, **bump `updated_at`** (A-10 basis), replace the tag set; image replacement goes through the import pipeline (old file replaced); emit `updated`.
- **`toggleFavorite`** (FR-6.8, FR-9.3): flip `is_favorite`, persist on the row (survives restarts — FR-9.4); emit `updated`.
- **`delete`** (FR-8.8/8.9, in one transaction): delete the wearable row + its `wearable_tags` links; remove it from **every** `outfit_wearables` row; each affected outfit keeps its remaining wearables; **any outfit left with zero wearables is deleted** — row, composition rows, **and both of its image files** (Data model doc §Image storage "Cleanup on delete"). Delete the wearable's own two image files. A failed file deletion is logged and left to orphan reconciliation (task 004). Emit `deleted` (with the sync tombstone recorded by the pipeline — see 010).

### 4. Errors

Commands throw the typed exceptions (task 002); read streams surface errors via `onError` — one bad row never crashes the app (Architecture §Error handling policy).

## Definition of done

**Build** (standard gate): all items pass.

**Unit test constraints** — `test/data/repositories/wearable_repository/` (in-memory `drift` + temp image dir, per Architecture §Testing strategy):

- [ ] **Filter matrix:** name substring (case-insensitive); type single-select; color single-select with **null-color rows excluded**; tag OR within dimension; AND across dimensions (name+type+color+tags combined); each dimension individually and combined.
- [ ] **Ordering:** `streamFiltered` and `streamFavorite` emit newest first; after insert the new item is first (FR-8.12).
- [ ] **Create:** valid draft inserts row + reused tag row + link in one transaction; a second wearable with the same tag name reuses the existing tag (no duplicate, case-insensitive); validation failure (`name` empty / no `type`) throws `ValidationException` with the missing requirement named.
- [ ] **Create with image:** source file imported to `images/wearables/<uuid>.jpg` + thumb; the relative path is stored on the row; create without an image stores `imagePath == null` (A-7).
- [ ] **Update:** field change persisted; `updatedAt` strictly bumped; tag replacement (added and removed tags correct).
- [ ] **toggleFavorite:** false→true→false; value read back from the DB (persistence, FR-9.4).
- [ ] **Delete cascade:** wearable in two outfits — removed from both; one outfit survives with its other wearables; the other is left empty and is deleted **including its image files**; the wearable's own files are deleted.
- [ ] **Transaction atomicity:** simulating a mid-transaction failure leaves no partial rows.
- [ ] **Streams:** after create/update/delete/toggleFavorite, every subscribed stream re-emits with the new snapshot (FR-8.11); `streamById` goes to `null` after delete.
- [ ] **Events:** each mutation emits exactly one `SyncChangeEvent` with the right kind/action/id.

**Functional acceptance**

- [ ] No `drift` row types leak past the repository (ViewModels will see domain models only).
- [ ] The interface matches the Data model doc signature line-for-line (names, nullability, doc comments).

**Out of scope for this task:** outfit composition rules beyond the cascade (009), sync application (010), UI.
