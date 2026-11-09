# iWardrobe — Data model & local database

| | |
|---|---|
| **Version** | 1.0 (v1 / MVP) |
| **Date** | 8 November 2026 |
| **Status** | Reference for implementation |
| **Companion documents** | [Documentation index](README.md) · [Functional specification](functional-specification.md) · [Architecture](architecture.md) · [iCloud sync](icloud-sync.md) · [Responsive design](responsive-design.md) · [UI & design language](ui-design.md) |

## Purpose

This document defines **what** iWardrobe stores, **where** it stores it, and **how** the two map to the functional specification:

- the domain entities and their fields (Domain model),
- the exact JSON documents used for persistence snapshots and iCloud sync payloads (JSON wire format),
- the local `drift`/SQLite schema (Local database),
- image file storage (Image storage),
- the public repository API the UI is allowed to call (Repository API surface),
- an end-to-end data-flow example (Data flow example).

The [functional specification](functional-specification.md) remains the source of truth for behavior. The requirements this document grounds on are in particular **FR-11.1** (all data in an internal SQLite database, all images as files in the app's documents directory, no server), **FR-9.1** (the favorite state is a boolean stored with each record), and the assumptions **A-5** (wearable type set), **A-7** (image required for outfits, optional for wearables), **A-8** (wearable color optional), and **A-9** (season set).

Division of labor with the companion documents: [Architecture](architecture.md) defines the layers these objects live in; [iCloud sync](icloud-sync.md) defines the *transfer protocol* — document order, conflict resolution (A-10), offline queue (FR-10.4). The *payload format* it transfers is defined here, in the JSON wire format section.

## Domain model

### Entities

**`Wearable`** — a single clothing item or accessory (FR-8.3).

| Field | Type | Required | Notes |
|---|---|---|---|
| `id` | `String` (UUID v4) | Yes | Generated client-side; stable across devices (A-10) |
| `name` | `String` | Yes | FR-8.3 |
| `type` | `WearableType` | Yes | One of the fixed set, A-5 (FR-6.4) |
| `color` | `Color?` | No | Optional (A-8); a wearable without a color never matches a color filter (FR-6.5) |
| `size` | `String?` | No | FR-8.3 |
| `brand` | `String?` | No | FR-8.3 |
| `material` | `String?` | No | FR-8.3 |
| `notes` | `String?` | No | FR-8.3 |
| `isFavorite` | `bool` | Yes | Default `false`; FR-9.1, FR-9.4 |
| `imagePath` | `String?` | No | Relative path under the documents directory; optional for wearables (A-7), placeholder when absent (FR-7.1) |
| `createdAt` | `DateTime` (UTC) | Yes | Used for newest-first ordering (A-3) |
| `updatedAt` | `DateTime` (UTC) | Yes | Bumped on every edit (FR-8.5); basis for last-writer-wins (A-10) |
| `tags` | `List<Tag>` | No | Via the `wearable_tags` join table (FR-8.3) |

**`Outfit`** — a named, saved combination of wearables (FR-8.2).

| Field | Type | Required | Notes |
|---|---|---|---|
| `id` | `String` (UUID v4) | Yes | Generated client-side (A-10) |
| `name` | `String` | Yes | FR-8.2 |
| `imagePath` | `String` | Yes | Always required — at creation and at all times (A-7, FR-8.6) |
| `description` | `String?` | No | FR-8.2, FR-5.3 |
| `occasion` | `String?` | No | FR-8.2, FR-5.3 |
| `season` | `Season?` | No | Optional (FR-8.2); displayed only when set (FR-5.3); one of A-9 |
| `notes` | `String?` | No | FR-8.2, FR-5.3 |
| `isFavorite` | `bool` | Yes | Default `false`; FR-9.1 |
| `createdAt` | `DateTime` (UTC) | Yes | A-3, A-4 (Home *Latest outfits*) |
| `updatedAt` | `DateTime` (UTC) | Yes | FR-8.5, A-10 |
| `wearables` | `List<Wearable>` | Yes, **≥ 1** | Via the `outfit_wearables` join table (A-6, FR-8.2) |

The outfit entity has **no** color or tag fields of its own (A-1): both are derived from the composing wearables.

**`Tag`** — a short user-defined label (FR-8.3).

| Field | Type | Required | Notes |
|---|---|---|---|
| `id` | `String` (UUID v4) | Yes | Generated client-side |
| `name` | `String` | Yes | Unique per wardrobe, case-insensitive (unique index on `tags.name`) |

### Enums

`WearableType` — fixed set (A-5, FR-6.4):

| Value | Wire string |
|---|---|
| `Top` | `"top"` |
| `Bottom` | `"bottom"` |
| `Dress` | `"dress"` |
| `Jacket` | `"jacket"` |
| `Shoes` | `"shoes"` |
| `Accessory` | `"accessory"` |

`Season` — fixed set (A-9, FR-8.2):

| Value | Wire string |
|---|---|
| `Spring` | `"spring"` |
| `Summer` | `"summer"` |
| `Autumn` | `"autumn"` |
| `Winter` | `"winter"` |
| `AllSeasons` | `"all_seasons"` |

`Color` — fixed predefined set of 14 values, single-select per wearable (A-8):

| Value | Wire string | | Value | Wire string |
|---|---|---|---|---|
| `Black` | `"black"` | | `Green` | `"green"` |
| `White` | `"white"` | | `Teal` | `"teal"` |
| `Grey` | `"grey"` | | `Blue` | `"blue"` |
| `Beige` | `"beige"` | | `Navy` | `"navy"` |
| `Brown` | `"brown"` | | `Purple` | `"purple"` |
| `Red` | `"red"` | | `Pink` | `"pink"` |
| `Orange` | `"orange"` | | | |
| `Yellow` | `"yellow"` | | | |

The set is fixed in v1: adding a value requires a specification change, and readers must reject unknown values (see JSON wire format).

### Relationships

```text
 Outfit 1 ── N Wearable     outfit_wearables join table; an outfit has at least one (A-6)
 Wearable M ── N Tag         wearable_tags join table
 Outfit  (derived)  Tag      no direct link; computed from the composing wearables (A-1)
```

| Relationship | Cardinality | Stored as | Source |
|---|---|---|---|
| Outfit → Wearable (composition) | 1 — N, N ≥ 1 | `outfit_wearables` | A-6, FR-8.2 |
| Wearable → Tag | M — N | `wearable_tags` | FR-8.3 |
| Outfit → Tag (derived) | M — N, derived | not stored; joined through the composition | A-1, FR-4.5 |

### Invariants & cascade rules

| # | Invariant / rule | Enforced by | Source |
|---|---|---|---|
| 1 | An outfit always contains at least one wearable | Form validation (FR-8.4); `setOutfitWearables` rejects an empty set | A-6, FR-8.2 |
| 2 | Deleting a wearable removes it from every outfit that contains it | `WearableRepository.delete` cascade | FR-8.8 |
| 3 | An outfit left with zero wearables is deleted in the same operation | same cascade | FR-8.9, A-6 |
| 4 | Deleting an outfit never deletes any of its wearables | `OutfitRepository.delete` removes only the outfit row, its composition rows, and its image file | FR-8.10 |
| 5 | An outfit always has an image | Required at creation; the edit form cannot remove it | A-7, FR-8.2, FR-8.6 |
| 6 | A wearable with no color never matches a color filter | Query uses `color IS NOT NULL` | A-8, FR-6.5 |
| 7 | Favorite is a boolean persisted on the row and survives restarts | `is_favorite` column | FR-9.1, FR-9.4 |
| 8 | Every edit bumps `updated_at` | Repository `update` path | FR-8.5, A-10 |
| 9 | Tag names are unique per wardrobe | Unique index on `tags.name` (case-insensitive) | — |

## JSON wire format

The exact JSON documents below are used for **persistence snapshots** and as the **iCloud sync payloads**. [iCloud sync](icloud-sync.md) defines when and how these documents are transferred; their shape is fixed here.

**Wearable document** (tags embedded):

```json
{
  "id": "6f9e1c2a-4b7d-4e0a-9c1f-2d3e4f5a6b7c",
  "name": "Blue shirt",
  "type": "top",
  "color": "blue",
  "size": "M",
  "brand": "Uniqlo",
  "material": "Cotton",
  "isFavorite": true,
  "imagePath": "images/wearables/6f9e1c2a-4b7d-4e0a-9c1f-2d3e4f5a6b7c.jpg",
  "createdAt": "2026-11-01T09:30:00Z",
  "updatedAt": "2026-11-05T14:12:45Z",
  "tags": [
    { "id": "aa11bb22-cc33-4d44-8e55-ff6677889900", "name": "casual" }
  ]
}
```

**Outfit document** (composition by id, derived color/tag facets included):

```json
{
  "id": "c0ffeecd-5a2e-4f1a-9b3c-7e8d9f0a1b2c",
  "name": "Casual Friday",
  "imagePath": "images/outfits/c0ffeecd-5a2e-4f1a-9b3c-7e8d9f0a1b2c.jpg",
  "description": "Relaxed office look",
  "occasion": "Work casual",
  "season": "all_seasons",
  "isFavorite": true,
  "wearableIds": [
    "6f9e1c2a-4b7d-4e0a-9c1f-2d3e4f5a6b7c",
    "b1d2e3f4-5a6b-4c7d-8e9f-0a1b2c3d4e5f",
    "d9e8f7a6-5b4c-4d3e-9f8a-7b6c5d4e3f2a"
  ],
  "colors": ["blue"],
  "tags": ["casual", "denim"],
  "createdAt": "2026-11-05T16:20:00Z",
  "updatedAt": "2026-11-05T16:20:00Z"
}
```

**Formatting rules.**

| Aspect | Rule |
|---|---|
| Key naming | `camelCase` |
| Timestamps | ISO-8601 UTC, second precision, `Z` suffix (e.g. `"2026-11-05T14:12:45Z"`) |
| Enum values | Lower-case strings; multi-word values in `snake_case` (`"all_seasons"`) |
| Null optionals | Omitted when writing; absent means `null` when reading |
| Unknown fields | **Ignored on read** — a newer app version may add fields without breaking older readers (forward compatibility) |
| Malformed input | A missing required field, a wrong type, or an unknown enum value makes `fromJson` throw `FormatException`; the caller (repository / sync layer) decides to skip and log the document |
| `colors` / `tags` on Outfit | Derived from the composing wearables (A-1) and materialized so the outfit-level filters (FR-4.4, FR-4.5) work as soon as the outfit document is known; the authoritative source remains the wearable documents plus the `outfit_wearables` composition, which clients recompute locally |
| `imagePath` | Relative to the application documents directory, so the same string identifies the file on every device (1:1 mapping for sync) |

**Model implementation.** Per the project's JSON serialization convention, models are immutable (`final` fields, const constructors) and implement `fromJson`/`toJson` manually with `dart:convert`: a `factory X.fromJson(Map<String, dynamic> json)` that pattern-matches the required keys and throws `FormatException` on anything else, plus a `Map<String, dynamic> toJson()` that omits null optionals.

```dart
// domain/models/wearable.dart (abridged)
factory Wearable.fromJson(Map<String, dynamic> json) {
  return switch (json) {
    {
      'id': String id,
      'name': String name,
      'type': String type,
      'createdAt': String createdAt,
      'updatedAt': String updatedAt,
    } =>
      Wearable(
        id: id,
        name: name,
        type: WearableType.fromString(type), // throws FormatException if unknown
        color: _enumOrNull<Color>(json['color'], Color.fromString),
        size: json['size'] as String?,
        brand: json['brand'] as String?,
        material: json['material'] as String?,
        notes: json['notes'] as String?,
        isFavorite: json['isFavorite'] as bool? ?? false,
        imagePath: json['imagePath'] as String?,
        createdAt: DateTime.parse(createdAt),
        updatedAt: DateTime.parse(updatedAt),
        tags: (json['tags'] as List<dynamic>? ?? const [])
            .map((e) => Tag.fromJson(e as Map<String, dynamic>))
            .toList(),
      ),
    _ => throw const FormatException('Failed to load Wearable.'),
  };
}
```

The `switch` only destructures the known keys, so documents containing *additional* unknown fields still match the first case — which is exactly the forward-compatibility rule above.

## Local database (drift/SQLite)

The local database is a single SQLite file in the app's documents directory (FR-11.1), accessed exclusively through `drift` and the `DatabaseService`. Tables use UUID text primary keys, `snake_case` column names, and store timestamps in UTC.

```dart
// data/models/wardrobe_tables.dart
import 'package:drift/drift.dart';

part 'wardrobe_tables.g.dart';

class Wearables extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get type => text()();
  TextColumn? get color => text().nullable()();
  TextColumn? get size => text().nullable()();
  TextColumn? get brand => text().nullable()();
  TextColumn? get material => text().nullable()();
  TextColumn? get notes => text().nullable()();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  TextColumn? get imagePath => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [{id}];

  @override
  Set<Index> get indexes => {
        Index.by('idx_wearables_name', {name}), // name search (FR-6.3)
        Index.by('idx_wearables_favorite', {isFavorite}),
      };
}

class Outfits extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get imagePath => text()(); // required — no nullable (A-7)
  TextColumn? get description => text().nullable()();
  TextColumn? get occasion => text().nullable()();
  TextColumn? get season => text().nullable()(); // optional (FR-8.2)
  TextColumn? get notes => text().nullable()();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [{id}];

  @override
  Set<Index> get indexes => {
        Index.by('idx_outfits_created_at', {createdAt}), // ORDER BY created_at DESC (A-3)
        Index.by('idx_outfits_favorite', {isFavorite}),
      };
}

class OutfitWearables extends Table {
  TextColumn get outfitId => text().references(Outfits, #id)();
  TextColumn get wearableId => text().references(Wearables, #id)();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [{outfitId, wearableId}];

  @override
  Set<Index> get indexes => {
        Index.by('idx_outfit_wearables', {outfitId, wearableId}),
      };
}

class Tags extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
        {id},
        {name}, // tag names unique per wardrobe (case-insensitive)
      ];
}

class WearableTags extends Table {
  TextColumn get wearableId => text().references(Wearables, #id)();
  TextColumn get tagId => text().references(Tags, #id)();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [{wearableId, tagId}];

  @override
  Set<Index> get indexes => {
        Index.by('idx_wearable_tags', {wearableId, tagId}),
      };
}
```

```dart
// data/services/database_service.dart (abridged)
@DriftDatabase(
  tables: [Wearables, Outfits, Tags, OutfitWearables, WearableTags],
)
class WardrobeDatabase extends _$WardrobeDatabase {
  WardrobeDatabase(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          // v1 migration policy: additive only — new tables or nullable
          // columns may be added; existing columns are never dropped,
          // renamed, or type-changed, so documents synced from an older
          // version remain readable.
        },
      );
}
```

**Conventions.**

- **UUID primary keys are generated client-side** (v4). Every entity gets its id at creation time on the originating device, so records are valid before any sync and last-writer-wins (A-10) has a stable identity to compare.
- **`created_at` / `updated_at` are stored in UTC** (drift `dateTime`); the UI localizes them for display only.
- **Codegen.** Table accessors are generated with `build_runner`:

```bash
dart run build_runner build --delete-conflicting-outputs
```

- **Migration policy.** v1 ships as `schemaVersion` 1. Any later v1.x change must be **additive only** (new tables, new nullable columns); destructive changes are out of scope for v1 and would require the conflict policy in [iCloud sync](icloud-sync.md) to be extended first.
- **Transactions.** Every multi-table mutation (create with tags, delete with cascade per FR-8.8 – FR-8.10) runs in a single `drift` transaction, so the database is never left half-updated (FR-11.4).

## Image storage

Images are **files, never database rows** (FR-11.1). The database stores only relative path strings, which keeps the SQLite file small and makes the file layout the unit of sync (1:1 with the entity id).

```text
<application documents directory>/
├── wardrobe.db                        # drift SQLite database
└── images/
    ├── outfits/
    │   └── <outfit-uuid>.jpg          # display size, longest edge ≈ 1600 px
    ├── wearables/
    │   └── <wearable-uuid>.jpg        # display size, longest edge ≈ 1600 px
    └── thumbs/
        ├── outfits/
        │   └── <outfit-uuid>.jpg      # 512 px — carousels, grids, detail thumbnails
        └── wearables/
            └── <wearable-uuid>.jpg    # 512 px
```

**Import pipeline.**

1. The user picks a photo via `image_picker` (FR-8.2, FR-8.3); the package returns a temporary file in the original size.
2. `ImageFileService` resizes and compresses it with `flutter_image_compress` to **JPEG, longest edge ≈ 1600 px, quality ≈ 80**, and writes it to `images/<kind>/<uuid>.jpg`.
3. A **512 px** thumbnail is generated for lists, the Home carousel, and composing-wearable thumbnails (FR-3.2, FR-5.4) and written to `thumbs/<kind>/<uuid>.jpg` — decoding a small file per grid tile keeps scrolling at 60 fps (NFR-3).
4. The **relative** path (`images/wearables/<uuid>.jpg`) is stored on the row.

**Decision: only the compressed version is stored.** The camera original is discarded after step 3. Rationale: one canonical file per entity halves storage and the sync payload (FR-10.1), and 1600 px comfortably covers detail-page display on every supported screen, including Mac. Trade-off: the app cannot later offer a lossless original; if that becomes a product requirement it can be added as an extra file per entity without any schema change.

**Naming and sync.** Files are named with the entity UUID, so a sync document's `imagePath` maps 1:1 to a file on every device; [iCloud sync](icloud-sync.md) transfers the two files per entity alongside the JSON document.

**Cleanup on delete.** When an entity is deleted, the repository performs the database cascade (row + join rows) in one transaction, then deletes the entity's two image files in the same operation. A failed file deletion is logged and repaired by a startup scan that removes any file under `images/` whose UUID no longer exists in the database (orphan reconciliation). Deleting the last wearable of an outfit also deletes that outfit and its files (FR-8.9); deleting an outfit never touches its wearables' files (FR-8.10).

**Missing-file fallback.** If an image file is absent at display time (for example a wearable with no image — A-7 — or a partial sync state), `WardrobeImage` (`lib/ui/core/widgets`) renders the type-based placeholder defined in [UI & design language](ui-design.md) (FR-7.1, FR-5.4). Images are always loaded lazily with a placeholder while decoding (NFR-3).

## Repository API surface

The repositories are the **only** layer that touches `drift`, the file system, or sync (see [Architecture](architecture.md), Architectural pattern). The UI may call nothing else. The API below is the interface the implementations (`WearableRepositoryImpl`, `OutfitRepositoryImpl`) fulfill and that ViewModels and tests depend on.

```dart
// domain: the only public data API the UI may call
abstract interface class WearableRepository {
  /// All wearables matching [filter], newest first (A-3).
  /// Name substring (FR-6.3), type (FR-6.4), color (FR-6.5),
  /// tags OR within the dimension, AND across dimensions (A-2, FR-6.7).
  Stream<List<Wearable>> streamFiltered(WearableFilter filter);

  /// Favorited wearables for Home *Favorite clothes* (FR-3.4, FR-9.5).
  Stream<List<Wearable>> streamFavorite();

  /// One wearable with its tags; `null` when it no longer exists.
  Stream<Wearable?> streamById(String id);

  /// Total count, used by Home's empty-wardrobe state (FR-3.6).
  Stream<int> streamCount();

  /// Validates per FR-8.3 / FR-8.4 and inserts row + tag rows in one
  /// transaction; returns the created wearable.
  Future<Wearable> create(WearableDraft draft);

  /// Updates fields, bumps `updatedAt` (FR-8.5), and replaces tags.
  Future<Wearable> update(Wearable updated);

  /// Toggles `isFavorite` (FR-6.8, FR-9.3).
  Future<void> toggleFavorite(String id);

  /// Deletes the wearable, removes it from every outfit, and deletes
  /// any outfit left with zero wearables (FR-8.8, FR-8.9), including
  /// the affected image files.
  Future<void> delete(String id);
}

abstract interface class OutfitRepository {
  /// All outfits matching [filter], newest first (A-3, FR-4.1).
  /// Color and tag are derived from composing wearables (A-1, FR-4.4, FR-4.5).
  Stream<List<Outfit>> streamFiltered(OutfitFilter filter);

  /// The [limit] most recently created outfits — Home carousel
  /// (FR-3.2, A-4; Home uses `limit: 10`).
  Stream<List<Outfit>> streamLatest([int limit = 10]);

  /// Favorited outfits for Home (FR-3.3, FR-9.5).
  Stream<List<Outfit>> streamFavorite();

  /// One outfit with its composing wearables, each with its tags (FR-5.4).
  Stream<OutfitWithWearables?> streamById(String id);

  /// Total count, used by Home's empty-wardrobe state (FR-3.6).
  Stream<int> streamCount();

  /// Validates image + name + at least one wearable (FR-8.2, A-6)
  /// and inserts outfit row, composition rows, and image file atomically.
  Future<Outfit> create(OutfitDraft draft);

  /// Updates fields (image may be replaced but never removed — FR-8.6),
  /// bumps `updatedAt`, and may replace the composition.
  Future<Outfit> update(Outfit updated);

  /// Replaces the set of composing wearables; rejects an empty set (A-6).
  Future<void> setOutfitWearables(String outfitId, List<String> wearableIds);

  /// Toggles `isFavorite` (FR-4.8, FR-9.3).
  Future<void> toggleFavorite(String id);

  /// Deletes the outfit, its composition rows, and its image file —
  /// never any of its wearables (FR-8.10).
  Future<void> delete(String id);
}
```

The immutable filter state shared by both list pages (A-2):

```dart
// domain/filters.dart
class WearableFilter {
  const WearableFilter({
    this.nameSubstring,
    this.type,
    this.color,
    this.tagIds = const {},
  });

  final String? nameSubstring; // case-insensitive (FR-6.3)
  final WearableType? type; // single-select (FR-6.4)
  final Color? color; // single-select; null rows never match (A-8)
  final Set<String> tagIds; // OR within this dimension (FR-6.6)

  bool get isActive =>
      nameSubstring != null || type != null || color != null || tagIds.isNotEmpty;
}

class OutfitFilter {
  const OutfitFilter({
    this.nameSubstring,
    this.color,
    this.tagIds = const {},
  });

  final String? nameSubstring; // case-insensitive (FR-4.3)
  final Color? color; // derived via composing wearables (A-1, FR-4.4)
  final Set<String> tagIds; // OR within this dimension (A-2, FR-4.5)

  bool get isActive =>
      nameSubstring != null || color != null || tagIds.isNotEmpty;
}
```

**Semantics.**

- Streams emit an **immutable snapshot** (a new `List` with immutable models) whenever the underlying data or the filter changes, so every subscribed screen updates immediately (FR-8.11, FR-3.7).
- All queries are ordered `created_at DESC` (A-3), which makes a newly created item appear first (FR-8.12).
- Commands throw the typed exceptions from [Architecture](architecture.md), Error handling & logging; reads surface errors through the stream's `onError`.
- On Apple platforms, each mutation also publishes a local-change event that `SyncRepository` consumes to schedule the upload; on Android the same call path hits `NoopSyncService` and does nothing (FR-10.5, FR-10.6). The protocol itself is defined in [iCloud sync](icloud-sync.md).

## Data flow example

End-to-end walkthrough: the user adds a wearable (spec §7.2).

1. On the Wearables tab the user taps **Add wearable** (FR-8.1) → `context.go('/wearables/new')`. The route-scoped `WearableFormViewModel` exposes an empty `WearableDraft`.
2. The user optionally picks a photo (A-7), enters name "Blue shirt", type **Top**, color **Blue**, size **M**, and the tag "casual", then taps **Save**.
3. `WearableFormViewModel` validates: name and type are required; a missing value raises `ValidationException` and the form shows the inline error naming it (FR-8.3, FR-8.4). Here validation passes.
4. `WearableRepository.create(draft)` executes: it generates a UUID v4, compresses the picked image to `images/wearables/<uuid>.jpg` plus the 512 px thumbnail via `ImageFileService`, and inserts the `wearables` row, the `tags` row (reused if it already exists), and the `wearable_tags` link in a single `drift` transaction (FR-11.1).
5. The drift table stream fires → `streamFiltered` re-emits → the already-subscribed `WearableListViewModel` receives the new snapshot with the new wearable **first** (A-3, FR-6.1, FR-8.12). `HomeViewModel`'s *Favorite clothes* stream is unaffected until the item is favorited (FR-3.7).
6. `context.pop()` returns to the Wearables tab with its previous scroll position and filters intact (FR-2.3, FR-2.4).
7. On Apple platforms the local-change event reaches `SyncRepository` → `IcloudSyncService` uploads the wearable JSON document and both image files to iCloud (FR-10.1, FR-10.2; protocol in [iCloud sync](icloud-sync.md)). On Android, `NoopSyncService` performs nothing and no sync UI exists (FR-10.5, FR-10.6).
8. Any other open screen that shows this wearable — for example a favorite toggle from its detail page — reflects the change immediately through the same streams (FR-8.11, FR-9.3), and the state survives an app restart because it lives in the database and on disk (FR-9.4, FR-11.4).
