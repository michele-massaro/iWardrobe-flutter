# Task 003 — Local database (drift) & DatabaseService

| | |
|---|---|
| **Phase** | 1 — Foundation |
| **Depends on** | 001, 002 |
| **Primary references** | [Data model & local database](../data-model-and-database.md) §Local database (drift/SQLite) |

## Objective

Create the local `drift`/SQLite database — the single store for all wardrobe records (FR-11.1) — plus the stateless `DatabaseService` that owns the database instance and raw row queries. Tables, indexes, and the migration policy are fixed by the Data model doc; this task makes them real, generated, and testable in memory.

## What the agent must deliver

### 1. Table definitions — `lib/data/models/wardrobe_tables.dart`

Implement the five tables **exactly** as in the Data model doc §Local database (the doc contains the full `drift` source; copy its semantics, not necessarily verbatim):

- `Wearables` — UUID text PK; `name`, `type` (text), nullable `color`/`size`/`brand`/`material`/`notes`; `isFavorite` bool default false; nullable `imagePath`; `createdAt`/`updatedAt` (drift `dateTime`, UTC); unique key `{id}`; indexes `idx_wearables_name` (name search, FR-6.3) and `idx_wearables_favorite`.
- `Outfits` — UUID text PK; `name`; `imagePath` **non-nullable** (A-7); nullable `description`/`occasion`/`season`/`notes`; `isFavorite` default false; `createdAt`/`updatedAt`; unique key `{id}`; indexes `idx_outfits_created_at` (ORDER BY for newest-first, A-3) and `idx_outfits_favorite`.
- `OutfitWearables` — `outfitId`/`wearableId` referencing the parent tables; composite unique key `{outfitId, wearableId}`; index `idx_outfit_wearables`.
- `Tags` — UUID PK; `name`; unique keys `{id}` and `{name}` (case-insensitive uniqueness per wardrobe).
- `WearableTags` — `wearableId`/`tagId` with references; composite unique key; index `idx_wearable_tags`.

Run codegen: `dart run build_runner build --delete-conflicting-outputs` → `wardrobe_tables.g.dart` (gitignored, never hand-edited, never committed).

### 2. Database class — `lib/data/services/database_service.dart`

- `WardrobeDatabase extends _$WardrobeDatabase` with `schemaVersion => 1` and the doc's `MigrationStrategy` (onCreate → `createAll()`; onUpgrade → **additive-only** policy documented in code: new tables / new nullable columns only, existing columns never dropped/renamed/type-changed).
- Two construction paths: (a) production — opens the SQLite file at `<application documents directory>/wardrobe.db` via `path_provider`; (b) `WardrobeDatabase.inMemory()` for tests (`NativeDatabase.memory()`).
- `DatabaseService` is a stateless wrapper exposing the database instance and raw row query helpers. It knows nothing about the domain (rule 4, Architecture §Architectural pattern): rows go out, domain models come back only at the repository layer.

### 3. Conventions (binding)

- UUID text primary keys generated client-side (task 008/009 generate them at insert time; the DB does not).
- `created_at`/`updated_at` stored in UTC; UI localizes for display only.
- Every multi-table mutation happens inside a single `drift` transaction (foundation for FR-11.4; the repositories in 008/009 will use the service's transaction helper).

## Definition of done

**Build** (standard gate): codegen succeeds; `flutter analyze` clean; `dart format` clean; `flutter test` green; platform builds succeed.

**Unit test constraints** — `test/data/database/` with an in-memory `WardrobeDatabase`:

- [ ] Schema creation: all five tables exist with the documented column nullability (outfit `image_path` NOT NULL; wearable `image_path` NULL; `is_favorite` defaults to false).
- [ ] Raw insert/read round-trip per table, including the join tables.
- [ ] Unique constraints: inserting a duplicate tag `name` fails (case-insensitive); duplicate composite join rows fail.
- [ ] Indexes exist: verify `idx_wearables_name`, `idx_wearables_favorite`, `idx_outfits_created_at`, `idx_outfits_favorite`, and both join indexes are present (schema inspection).
- [ ] Ordering: `SELECT ... ORDER BY created_at DESC` returns newest first on the outfits table (the A-3/FR-4.1/FR-6.1 foundation).
- [ ] Transaction helper: a two-table mutation rolls back completely when the second statement throws (FR-11.4).
- [ ] Migration strategy object: `schemaVersion == 1`; the additive-only policy is asserted as documented (no destructive upgrades available in v1).

**Functional acceptance**

- [ ] `git status` shows no `*.g.dart` files; regeneration from a clean checkout works.
- [ ] No domain model types imported by `DatabaseService` (services return raw rows).

**Out of scope for this task:** repositories, streams, image handling, sync.
