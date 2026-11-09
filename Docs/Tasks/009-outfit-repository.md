# Task 009 — OutfitRepository

| | |
|---|---|
| **Phase** | 2 — Data layer |
| **Depends on** | 003, 004, 007 |
| **Primary references** | [Data model & local database](../data-model-and-database.md) §Repository API surface, §Invariants, §JSON wire format (derived facets) · [Functional specification](../functional-specification.md) FR-4.x, FR-5.4, FR-8.2/8.5/8.6/8.10, A-1, A-3, A-6 |

## Objective

Deliver the repository that is the **single source of truth** for outfits + composition: filtered streams (with color/tag **derived** from the composing wearables — A-1), the latest-outfits feed for Home, full CRUD honoring the invariants (an outfit always has an image, always ≥ 1 wearable, deleting an outfit never deletes its wearables), and the composition-replacement operation.

## What the agent must deliver

### 1. Public interface — exactly the documented API

`abstract interface class OutfitRepository` (full signature in the Data model doc §Repository API surface):

```dart
Stream<List<Outfit>> streamFiltered(OutfitFilter filter);       // newest first (A-3, FR-4.1)
Stream<List<Outfit>> streamLatest([int limit = 10]);            // Home carousel (FR-3.2, A-4)
Stream<List<Outfit>> streamFavorite();                          // Home (FR-3.3)
Stream<OutfitWithWearables?> streamById(String id);             // composing wearables + tags (FR-5.4)
Stream<int> streamCount();
Future<Outfit> create(OutfitDraft draft);                       // image+name+≥1 wearable, atomic
Future<Outfit> update(Outfit updated);                          // image replaceable, never removed (FR-8.6)
Future<void> setOutfitWearables(String outfitId, List<String> wearableIds); // empty rejected (A-6)
Future<void> toggleFavorite(String id);                         // FR-4.8, FR-9.3
Future<void> delete(String id);                                 // never deletes wearables (FR-8.10)
Stream<SyncChangeEvent> get localChanges;
```

Implementation (`OutfitRepositoryImpl`) consumes `DatabaseService` + `ImageFileService`.

### 2. Query semantics (binding)

- **Newest first** everywhere (`created_at DESC`, A-3).
- **Name:** case-insensitive substring (FR-4.3).
- **Color (derived, A-1, FR-4.4):** an outfit matches when **at least one composing wearable** has the selected color — implemented by joining `outfit_wearables` + `wearables` (the outfit entity has no color field).
- **Tags (derived, A-1, A-2, FR-4.5/4.6):** an outfit matches when at least one composing wearable carries **any** of the selected tags (OR within the dimension; AND across dimensions with name/color).
- **`streamLatest(limit)`** — the N most recently created outfits; Home uses `limit: 10` (FR-3.2, A-4).
- **`streamById`** returns the outfit plus **every** composing wearable with its tags (FR-5.4); `null` when the outfit no longer exists.
- Streams emit fresh immutable snapshots on any data or filter change (FR-8.11).

### 3. Mutation semantics

- **`create`** (FR-8.2, A-6, A-7): validate — image present (required, A-7), `name` non-empty, `wearableIds` non-empty (A-6); otherwise `ValidationException` naming the missing requirement (the frozen copy is the form's concern — FR-8.4). Import the image (1600 px + 512 px, task 004), then insert the `outfits` row and all `outfit_wearables` rows **in one transaction**. Emit `SyncChangeEvent.created`.
- **`update`** (FR-8.5/8.6): update optional fields; **bump `updated_at`**; the image may be **replaced** (new import, old file removed) but the row always keeps a valid `image_path`; the composition may be replaced only via `setOutfitWearables`. Emit `updated`.
- **`setOutfitWearables`** (A-6): replace the composition rows; **reject an empty set** (`ValidationException`). All referenced wearables must exist. Emit `updated`.
- **`toggleFavorite`** (FR-4.8, FR-9.3): flip `is_favorite`, persisted on the row (FR-9.4). Emit `updated`.
- **`delete`** (FR-8.10): remove the `outfits` row, its `outfit_wearables` rows, and its two image files — **never** any wearable row, join row, or wearable image. Emit `deleted`.

### 4. Derived facets for sync (A-1)

When the repository (or the pipeline, 010) serializes an outfit to the wire format, the `colors` and `tags` arrays are **computed from the composing wearables** at that moment. The authoritative source remains the wearable documents + composition; clients recompute locally (Data model doc §JSON wire format, formatting rules).

## Definition of done

**Build** (standard gate): all items pass.

**Unit test constraints** — `test/data/repositories/outfit_repository/` (in-memory `drift` + temp image dir):

- [ ] **Derived color filter:** outfit matches the color filter iff ≥ 1 composing wearable has it; an outfit whose wearables lack the color does not match; the outfit entity itself stores no color.
- [ ] **Derived tag filter:** multi-select OR within the dimension; AND when combined with name/color; outfits matched through different composing wearables.
- [ ] **streamLatest:** returns exactly the N most recent by `created_at`; `limit` honored; `limit: 10` default.
- [ ] **streamById:** returns every composing wearable with its tags; `null` after delete.
- [ ] **Create validation:** missing image → `ValidationException`; missing name → `ValidationException`; empty `wearableIds` → `ValidationException` (A-6).
- [ ] **Create:** row + all composition rows inserted atomically; image imported to `images/outfits/<uuid>.jpg` + thumb; row's `image_path` set (non-null, schema-level guarantee).
- [ ] **Update:** field change + `updatedAt` bump; image replacement works and the old file is removed; image can never be removed (no update path yields null `image_path`).
- [ ] **setOutfitWearables:** replaces the composition (removed/added rows correct); empty list rejected; referencing a non-existent wearable rejected.
- [ ] **Delete:** outfit row + composition rows + both image files removed; **all composing wearables survive** with their rows and image files (FR-8.10).
- [ ] **toggleFavorite:** persisted on the row; stream re-emits.
- [ ] **Events:** one `SyncChangeEvent` per mutation with correct kind/action/id.
- [ ] **Derived facets:** serializing an outfit to the wire format yields `colors`/`tags` equal to the union over composing wearables (A-1).

**Functional acceptance**

- [ ] No `drift` row types leak past the repository.
- [ ] The interface matches the Data model doc line-for-line.
- [ ] Invariant "an outfit always has an image" holds at the schema level (non-nullable column) **and** the API level (no path can remove it).

**Out of scope for this task:** the wearable-side cascade (008), sync application (010), UI.
