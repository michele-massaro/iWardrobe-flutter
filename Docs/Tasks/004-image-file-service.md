# Task 004 — ImageFileService & image import pipeline

| | |
|---|---|
| **Phase** | 2 — Data layer |
| **Depends on** | 002, 003 |
| **Primary references** | [Data model & local database](../data-model-and-database.md) §Image storage · [Functional specification](../functional-specification.md) FR-8.2, FR-8.3, FR-11.1, A-7, NFR-3 |

## Objective

Deliver the single file-system service that owns every wardrobe image: the import pipeline (pick → compress → store), the fixed directory layout, deletion with the entity, and the startup orphan reconciliation. Images are **files, never database rows** (FR-11.1); only relative path strings are stored on records.

## What the agent must deliver

### 1. Layout — exactly the documented tree

```text
<application documents directory>/
└── images/
    ├── outfits/<uuid>.jpg        # ≈1600 px JPEG
    ├── wearables/<uuid>.jpg      # ≈1600 px JPEG
    └── thumbs/
        ├── outfits/<uuid>.jpg    # 512 px
        └── wearables/<uuid>.jpg  # 512 px
```

Files are named with the entity UUID so a sync document's `imagePath` maps 1:1 to a file on every device (iCloud sync doc §4).

### 2. Service — `lib/data/services/image_file_service.dart`

Stateless wrapper (knows nothing about the domain, Architecture rule 4). API (adjust names, keep semantics):

- `Future<String> importImage({required String sourcePath, required String kind, required String uuid})` — reads the picked temp file, resizes/compresses with `flutter_image_compress` to **JPEG, longest edge ≈ 1600 px, quality ≈ 80** → `images/<kind>/<uuid>.jpg`; generates the **512 px** thumbnail → `thumbs/<kind>/<uuid>.jpg`; returns the **relative** path `images/<kind>/<uuid>.jpg`. `kind` ∈ {`outfits`, `wearables`}.
- `Future<void> deleteFiles(String kind, String uuid)` — removes both the original and the thumbnail.
- `String relativePath(String kind, String uuid)` — pure path builder (used by repositories and sync without touching disk).
- `Future<List<String>> reconcileOrphans(Map<String, Set<String>> existingUuidsByKind)` — removes any file under `images/` whose UUID no longer exists in the database (orphan reconciliation, Data model doc §Image storage). Returns the removed relative paths.
- All I/O failures throw `ImageFileException` (task 002).

### 3. Decision carried from the docs (do not revisit)

Only the compressed version is stored; the camera original is discarded after import (halves storage and sync payload — FR-10.1). 1600 px covers detail display on every supported screen including Mac. A failure during compression must leave no half-written files (write to a temp name, then move).

## Definition of done

**Build** (standard gate): all items of the standard build gate pass.

**Unit test constraints** — `test/data/image_file_service/` (temp directories; a small valid test image generated in-test, e.g. a colored PNG written to a temp file):

- [ ] **Import pipeline:** `importImage` produces both `images/wearables/<uuid>.jpg` and `thumbs/wearables/<uuid>.jpg`; the original is decodable JPEG with longest edge ≤ ~1600 px (± tolerance) and the thumbnail's longest edge ≤ 512 px.
- [ ] **Relative path:** the returned string equals `images/wearables/<uuid>.jpg` and resolves correctly against the documents dir (the string, not the absolute path, is what gets stored).
- [ ] **Delete:** `deleteFiles` removes both files; a second call on the same uuid does not throw.
- [ ] **Orphan reconciliation:** given existing-UUID sets, only files whose UUID is absent are removed; files of live entities are untouched; returns exactly the removed paths.
- [ ] **Failure:** an unreadable/invalid source file throws `ImageFileException` and leaves no partial file under `images/`.
- [ ] **Both kinds:** the same behavior holds for `kind == 'outfits'`.

**Functional acceptance**

- [ ] No `Wearable`/`Outfit`/`Tag` types referenced by the service (raw paths and uuid strings only).
- [ ] The service does not create or read `wardrobe.db`.

**Out of scope for this task:** calling `image_picker` from UI (that is the forms, tasks 022/023), sync transfer of image files (task 010), placeholder rendering (task 012).
