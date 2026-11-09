# Task 002 — Domain models, enums, filters, exceptions

| | |
|---|---|
| **Phase** | 1 — Foundation |
| **Depends on** | — |
| **Primary references** | [Data model & local database](../data-model-and-database.md) §Domain model, §JSON wire format · [Functional specification](../functional-specification.md) A-1 … A-11 |

## Objective

Deliver the complete **domain layer** (`lib/domain`) — the immutable models, enums, filter state, and typed exceptions every other layer shares, with hand-written `fromJson`/`toJson` that exactly implement the documented JSON wire format. Nothing else in the app may invent entity shapes; this task is their single definition.

## What the agent must deliver

### 1. Models — `lib/domain/models/`

- **`wearable.dart`** — `Wearable`, immutable (`final` fields, const constructor, hand-written `copyWith`): `id` (UUID v4 string), `name`, `type` (`WearableType`), `color?` (`Color?`), `size?`, `brand?`, `material?`, `notes?`, `isFavorite` (bool, default false), `imagePath?` (relative string, **nullable** — A-7), `createdAt`/`updatedAt` (`DateTime`, UTC), `tags` (`List<Tag>`).
- **`outfit.dart`** — `Outfit`: `id`, `name`, `imagePath` (**non-nullable** — A-7, FR-8.6), `description?`, `occasion?`, `season?` (`Season?`, A-9), `notes?`, `isFavorite`, `createdAt`/`updatedAt`, `wearableIds` (`List<String>`, ≥ 1 — A-6). No color or tag fields of its own (A-1).
- **`tag.dart`** — `Tag`: `id`, `name` (unique per wardrobe, case-insensitive).
- **`outfit_with_wearables.dart`** (or nested) — the read model for `streamById`: an outfit plus its composing `Wearable`s, each with tags (FR-5.4).
- **`drafts.dart`** — `WearableDraft` and `OutfitDraft`, the form → repository input: draft fields plus an optional source image path (temp file from `image_picker`). `OutfitDraft` requires `name`, source/target image, and `wearableIds` (≥ 1).
- **`enums.dart`** — `WearableType` (exactly `Top, Bottom, Dress, Jacket, Shoes, Accessory` — A-5, FR-6.4), `Season` (exactly `Spring, Summer, Autumn, Winter, AllSeasons` — A-9), `Color` (exactly the 14-value set from the Data model doc). Each enum exposes a `fromString` (wire-string parsing that throws `FormatException` on unknown values) and `wire`/`toString` mapping to the documented lower-case snake-case strings (`"all_seasons"` etc.).

### 2. Filters — `lib/domain/filters.dart`

Immutable `WearableFilter` and `OutfitFilter` exactly per the Data model doc (§Repository API surface): `nameSubstring?`, `type?` (wearables), `color?`, `tagIds` (Set, default empty), and `isActive`. Semantics are A-2/FR-4.6/FR-6.7: AND across dimensions, OR within the tag dimension; a null color never matches a row without a color (A-8).

### 3. Exceptions — `lib/domain/exceptions.dart`

`sealed class WardrobeException implements Exception` + `ValidationException` (FR-8.4), `ImageFileException` (A-7 image I/O), `SyncException` (FR-10.4) — exactly the hierarchy in Architecture §Error handling.

### 4. JSON wire format (binding)

Per the Data model doc §JSON wire format:

- `factory X.fromJson(Map<String, dynamic>)` using a **`switch` pattern match** that destructures only the required keys (so documents with *additional unknown fields still parse* — forward compatibility) and throws `FormatException('Failed to load X.')` on anything else.
- `toJson()` omits null optionals; key naming `camelCase`; timestamps ISO-8601 UTC second precision with `Z`; enums as lower-case strings.
- Outfit documents carry `wearableIds` plus the **derived** `colors` and `tags` facets (A-1) so outfit-level filters work as soon as the document is known; the authoritative source remains the wearable documents + composition.

## Definition of done

**Build** (standard gate): `flutter analyze` clean, `dart format` clean, `flutter test` green, platform builds succeed.

**Unit test constraints** — `test/domain/` (or matching layout) must contain passing tests for:

- [ ] **Round-trip:** `Wearable`, `Outfit`, `Tag` `fromJson` → `toJson` reproduce the documented example documents byte-for-byte in content (all fields, ordering of keys irrelevant).
- [ ] **Wire format:** the exact sample documents in the Data model doc (wearable with embedded tags; outfit with `wearableIds`, `colors`, `tags`, `season: "all_seasons"`) parse into the expected model values.
- [ ] **Forward compatibility:** documents with extra unknown fields parse successfully and ignore the extras; null optionals absent on read are `null`.
- [ ] **Malformed rejection:** missing required field, wrong type, and unknown enum value each make `fromJson` throw `FormatException` (one test each per entity).
- [ ] **Enum coverage:** every `WearableType`, `Season`, and `Color` value round-trips through its wire string; unknown strings throw.
- [ ] **Filters:** `isActive` is true for each single active dimension and false for the const default; tag set emptiness behaves as documented.
- [ ] **Immutability:** `copyWith` changes only the given field; models are `final`/const-constructible (compile-time, verified by usage in tests).

**Functional acceptance**

- [ ] No domain file imports `drift`, the file system, the plugin, or any UI package (domain is pure Dart + `dart:convert`).
- [ ] No `freezed`/`built_value` or any codegen in `lib/domain` (instructions.md §7).

**Out of scope for this task:** repositories, streams, database tables, any UI.
