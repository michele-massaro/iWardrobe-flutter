# iWardrobe — iCloud sync

| | |
|---|---|
| **Version** | 1.0 (v1 / MVP) |
| **Date** | 9 November 2026 |
| **Status** | Reference for implementation |
| **Companion documents** | [Documentation index](README.md) · [Functional specification](functional-specification.md) · [Architecture](architecture.md) · [Data model & local database](data-model-and-database.md) · [Responsive design](responsive-design.md) · [UI & design language](ui-design.md) · [Task index](Tasks/README.md) |

## 1. Purpose & scope

This document defines **how** iWardrobe v1 replicates the wardrobe across Apple platforms: the iCloud container and Xcode setup, the container layout, the `icloud_storage_sync` API mapping, the sync protocol (push/pull pipeline), conflict resolution and tombstones, triggers and scheduling, offline and error behavior, the user-visible status, and the testing strategy.

It is the protocol document for the F-10 feature set. The stable identifiers it grounds on are:

- **FR-10.1 – FR-10.7** — the iCloud sync functional requirements ([Functional specification](functional-specification.md) §5.10),
- **NFR-1** — offline-first: sync is a background enhancement that degrades gracefully,
- **NFR-2** — local privacy: no accounts, no server, data only in the user's own iCloud,
- **A-10** — conflicts on the same item are resolved last-writer-wins by update timestamp,
- **FR-10.4** — the app stays fully usable offline; pending changes sync when connectivity returns.

[Functional specification](functional-specification.md) §7 defers the end-to-end sync flow to this document; this is that document.

Division of labor with the companion documents:

- **The payload format is not defined here.** The exact JSON entity documents — camelCase keys, ISO-8601 UTC second-precision timestamps with `Z` suffix, lower-case enum strings, null optionals omitted, unknown fields ignored — and the `imagePath` convention are fixed in [Data model & local database](data-model-and-database.md), **JSON wire format**. This document defines *when and how* those documents and their image files are transferred, not their shape.
- **The service and repository seams are not defined here.** The `SyncService` interface, `IcloudSyncService` (the `icloud_storage_sync` wrapper), `NoopSyncService`, `SyncRepository`, the local-change event emitted by every repository mutation, the `SyncException` type, and the single platform branch at provider registration are defined in [Architecture](architecture.md) (Tech stack, Project structure, Cross-platform strategy, Error handling & logging). This document builds on those seams without redefining them.
- **The data being replicated** — entities, invariants, cascade rules, the local image layout — is defined in [Data model & local database](data-model-and-database.md); the product behavior is defined in [Functional specification](functional-specification.md) §5.10.

Scope: v1 baseline only — sync on iOS, iPadOS, and macOS; one wardrobe per Apple account; no background daemon; no sync on Android (FR-10.6).

## 2. Platform support

iCloud sync runs on Apple platforms only (FR-10.5, FR-10.6). The `icloud_storage_sync` package supports iOS and macOS only, which matches this scope. The single platform branch happens once, at provider registration ([Architecture](architecture.md), Cross-platform strategy), guarded by `defaultTargetOs`:

```dart
// app.dart (see Architecture, Dependency injection)
Provider<SyncService>(
  create: (_) => defaultTargetOs == TargetPlatform.iOS ||
          defaultTargetOs == TargetPlatform.macOS
      ? IcloudSyncService()
      : const NoopSyncService(),
)
```

| Platform | Sync implementation | What the user sees |
|---|---|---|
| iOS (iPhone) | `IcloudSyncService` | Full feature set + last-sync indicator (FR-10.5) |
| iPadOS (iPad) | `IcloudSyncService` | Full feature set + last-sync indicator (FR-10.5) |
| macOS | `IcloudSyncService` | Full feature set + last-sync indicator (FR-10.5) |
| Android | `NoopSyncService` | Full feature set **except sync**; no sync settings, no status UI (FR-10.5, FR-10.6) |

On Android the local-change event still flows through the same repository call path, but it hits `NoopSyncService` and performs nothing: **zero sync code paths run** — no queue, no retry, no status state. `AppViewModel.syncAvailable` (from `SyncRepository`) is `false` on Android, which is what hides the indicator; no other code path exists for sync on Android (FR-10.6).

## 3. iCloud container & Xcode setup

### Container id

The app uses a **single shared iCloud container** of the form:

```text
iCloud.<team-id>.<bundle-id>
```

for example `iCloud.TEAM123.com.example.iwardrobe`. The same container id is assigned to both the iOS App ID and the macOS App ID, so every Apple device of the user shares one wardrobe space. Note the common gotcha: if the macOS App ID is built on a different base bundle id, a container *derived* from it would be a different container — the identical container id must be assigned explicitly to both App IDs.

### Prerequisite checklist

| # | Item |
|---|---|
| 1 | An Apple Developer account, with an App ID for the iOS app and an App ID for the macOS app |
| 2 | The **iCloud capability enabled on both App IDs**, with the container id (`iCloud.<team-id>.<bundle-id>`) assigned to each |
| 3 | The app signed with a provisioning profile (development or release) that includes the iCloud capability |
| 4 | `icloud_storage_sync` pinned to **0.0.5** in `pubspec.yaml` — the current published version. The package README example says `^1.0.0`, but the latest published release is 0.0.5; **re-verify the version constraint against pub.dev at implementation time** |
| 5 | The container declared in `Info.plist` and in `Runner.entitlements` for each target (snippets below) |

### Xcode setup (iOS and macOS targets)

1. Select the app target → **Signing & Capabilities**.
2. **＋ Capability → iCloud**.
3. Enable the **iCloud** container checkbox and enter/select the container id `iCloud.<team-id>.<bundle-id>`.
4. Repeat for the macOS target.

Xcode generates the declarations below; they must exist in source control for both targets. The plugin talks to this container's iCloud-synced area, and all relative paths in this document are relative to the container root.

**`ios/Runner/Info.plist`** (and the macOS target's `Info.plist`) — the container id as the array value of the iCloud container-identifiers key:

```plist
<key>com.apple.developer.icloud-container-identifiers</key>
<array>
    <string>iCloud.TEAM123.com.example.iwardrobe</string>
</array>
```

**`ios/Runner/Runner.entitlements`** (and the macOS target's entitlements file) — the entitlements array containing the container id string:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.icloud-container-identifiers</key>
    <array>
        <string>iCloud.TEAM123.com.example.iwardrobe</string>
    </array>
</dict>
</plist>
```

## 4. What is synchronized

Two categories of data are synchronized (FR-10.1):

1. **The wardrobe snapshot document** — a single JSON document at `Documents/sync/wardrobe.json` carrying the complete wardrobe in the wire format of [Data model & local database](data-model-and-database.md) §"JSON wire format": the tag vocabulary, the wearable documents (tags embedded), the outfit documents (composition by `wearableIds`), plus the deletion tombstones (§7).
2. **Every image file** — for each entity, the compressed original (≈1600 px JPEG) and its 512 px thumbnail, named by the entity UUID, laid out under the container **1:1 with the local layout** ([Data model & local database](data-model-and-database.md), Image storage).

### Container layout

```text
<container>/
└── Documents/
    ├── sync/
    │   └── wardrobe.json               # single snapshot document (§4, §7)
    └── images/
        ├── outfits/
        │   └── <outfit-uuid>.jpg        # compressed original, ≈1600 px
        ├── wearables/
        │   └── <wearable-uuid>.jpg      # compressed original, ≈1600 px
        └── thumbs/
            ├── outfits/
            │   └── <outfit-uuid>.jpg    # 512 px
            └── wearables/
                └── <wearable-uuid>.jpg  # 512 px
```

### 1:1 local ↔ container mapping

The wire format stores `imagePath` relative to the application documents directory (for example `images/wearables/<uuid>.jpg`), so the same string identifies the file on every device; the container path is `Documents/` + `imagePath`:

| Local path (application documents directory) | Container relative path |
|---|---|
| `images/outfits/<uuid>.jpg` | `Documents/images/outfits/<uuid>.jpg` |
| `images/wearables/<uuid>.jpg` | `Documents/images/wearables/<uuid>.jpg` |
| `images/thumbs/outfits/<uuid>.jpg` | `Documents/images/thumbs/outfits/<uuid>.jpg` |
| `images/thumbs/wearables/<uuid>.jpg` | `Documents/images/thumbs/wearables/<uuid>.jpg` |
| (generated from the local DB at push time — no persistent local file) | `Documents/sync/wardrobe.json` |

The local `wardrobe.db` file itself is **never** transferred — only its content, serialized in the wire format at push time.

### The snapshot document (envelope)

The envelope that wraps the entity documents is:

```json
{
  "formatVersion": 1,
  "updatedAt": "2026-11-05T16:20:00Z",
  "tags": [
    { "id": "aa11bb22-cc33-4d44-8e55-ff6677889900", "name": "casual" }
  ],
  "wearables": [
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
  ],
  "outfits": [
    {
      "id": "c0ffeecd-5a2e-4f1a-9b3c-7e8d9f0a1b2c",
      "name": "Casual Friday",
      "imagePath": "images/outfits/c0ffeecd-5a2e-4f1a-9b3c-7e8d9f0a1b2c.jpg",
      "description": "Relaxed office look",
      "occasion": "Work casual",
      "season": "all_seasons",
      "isFavorite": true,
      "wearableIds": [
        "6f9e1c2a-4b7d-4e0a-9c1f-2d3e4f5a6b7c"
      ],
      "colors": ["blue"],
      "tags": ["casual"],
      "createdAt": "2026-11-05T16:20:00Z",
      "updatedAt": "2026-11-05T16:20:00Z"
    }
  ],
  "deleted": {
    "tags": [],
    "wearables": [
      { "id": "b1d2e3f4-5a6b-4c7d-8e9f-0a1b2c3d4e5f", "deletedAt": "2026-11-05T18:02:11Z" }
    ],
    "outfits": []
  }
}
```

| Field | Rule |
|---|---|
| `formatVersion` | Integer; `1` in v1. A reader meeting an unknown version **refuses the whole document** (quarantine path, §9) — never a partial merge |
| `updatedAt` | The latest `updatedAt` across the snapshot's wearables and outfits; informational — per-entity comparison is authoritative (§7) |
| `tags` | The wardrobe tag vocabulary; each entry is a tag document `{id, name}` |
| `wearables` / `outfits` | Exactly the entity documents of the wire format (not redefined here); each entity's `imagePath` locates its files via the mapping above |
| `deleted` | Deletion tombstones per entity kind; each entry is `{id, deletedAt}` — lifecycle in §7 |
| Unknown fields | Ignored on read (forward compatibility, consistent with the wire format rules) |
| Malformed input | A missing required field, a wrong type, or an unknown enum value makes parsing throw `FormatException` → the failure path in §9 |

### What is **not** synchronized

| Data | Why it stays device-local |
|---|---|
| Onboarding-completed flag (FR-1.6, FR-1.7) | Per-device first-launch concern; each install presents onboarding once |
| Last successful sync timestamp (FR-10.5) | Each device records the time of **its own** last successful sync |
| Local sync bookkeeping (last-merged state + local tombstones, §7) | A per-device bookkeeping file used for change detection and offline durability; never part of the shared wardrobe |
| Any other app setting (`shared_preferences`) | Device-local preference; v1 has no setting that needs to be shared |

## 5. Package API mapping

All container operations go through the `SyncService` interface ([Architecture](architecture.md)); on Apple platforms `IcloudSyncService` maps them onto the plugin instance `icloudSyncPlugin` (`icloud_storage_sync` 0.0.5). Every call takes a `containerId`.

| Sync operation | `icloud_storage_sync` method (0.0.5) | Arguments used |
|---|---|---|
| List container files (scoped, bounded) | `gather` → `Future<List<ICloudFile>>` | `containerId`, `relativePathPrefix: 'Documents/'`, `timeout` — throws `PlatformException` with code `METADATA_QUERY_TIMEOUT` when the metadata query exceeds the timeout |
| Fetch remote file bytes (snapshot, images) | `getCloudFiles` → `Future<List<CloudFiles>>` | `containerId` — the service selects the entry matching the needed relative path |
| Upload a new local file | `upload` | `containerId`, `filePath` (local source), `destinationRelativePath` (e.g. `Documents/images/outfits/<uuid>.jpg`), `onProgress` (`StreamHandler<double>`) |
| Replace an existing container file | `replace` | `containerId`, `updatedFilePath` (local merged snapshot or image), `relativePath` |
| Delete a container file | `delete` | `containerId`, `relativePath`, `isDirectory: false` |
| Quarantine a corrupt snapshot | `rename` | `containerId`, `relativePath: 'Documents/sync/wardrobe.json'`, `newName: 'wardrobe.json.bad-<timestamp>'` |
| (Reserved — unused in v1) | `move` | `containerId`, `fromRelativePath`, `toRelativePath` |

Representative calls, as issued by `IcloudSyncService`:

```dart
// IcloudSyncService — representative plugin calls (icloud_storage_sync 0.0.5)
icloudSyncPlugin.gather(
    containerId: containerId,
    relativePathPrefix: 'Documents/',
    timeout: timeout);

icloudSyncPlugin.getCloudFiles(containerId: containerId);

icloudSyncPlugin.upload(
    containerId: containerId,
    filePath: localImagePath,
    destinationRelativePath: 'Documents/images/outfits/<uuid>.jpg',
    onProgress: onProgress); // StreamHandler<double>, progress 0..1

icloudSyncPlugin.replace(
    containerId: containerId,
    updatedFilePath: mergedSnapshotPath,
    relativePath: 'Documents/sync/wardrobe.json');

icloudSyncPlugin.rename(
    containerId: containerId,
    relativePath: 'Documents/sync/wardrobe.json',
    newName: 'wardrobe.json.bad-20261109T123000Z');

icloudSyncPlugin.delete(
    containerId: containerId,
    relativePath: 'Documents/images/wearables/<uuid>.jpg',
    isDirectory: false);
```

Usage notes:

- `relativePathPrefix` keeps listings scoped to `Documents/`; `timeout` bounds the metadata query so a slow iCloud never hangs the app. `METADATA_QUERY_TIMEOUT` is treated as a **transient failure** → backoff retry; the app is never blocked (NFR-1, FR-10.4).
- `onProgress` reports per-file progress; the pipeline surfaces it only as the generic "Syncing…" state — v1 has no per-file progress UI, keeping the indicator lightweight (FR-10.5).
- The write-back strategy: `upload` when the container target is absent (first sync into a fresh container), `replace` when overwriting an existing file (the merged snapshot, a changed image).
- The `ICloudFile` field shape and the `getCloudFiles` selection are confirmed against the published 0.0.5 API at implementation time (see §3, checklist item 4).

## 6. Sync protocol

The pipeline runs inside `SyncRepository` ([Architecture](architecture.md)) and is **serialized**: no two runs execute concurrently (§8). One run is this sequence:

1. **Collect local state.** All tags, wearables, and outfits from the local DB serialized as wire-format documents; the local tombstone list (with `deletedAt`); the last-merged state (the wardrobe as it stood after the last successful sync, from the local bookkeeping file).
2. **Compute local changes.** Entities added or modified since the last-merged state (a new id, or an `updatedAt` newer than the last-merged copy), plus new local tombstones. If nothing changed, the run is pull-only.
3. **List the container.** `gather` with `relativePathPrefix: 'Documents/'` and a `timeout`; the `ICloudFile` listing is the presence index for the image operations in steps 6–7.
4. **Fetch and parse the remote snapshot.** `getCloudFiles` → `Documents/sync/wardrobe.json` → parse into a snapshot. **On failure: quarantine** — `rename` the file to `Documents/sync/wardrobe.json.bad-<timestamp>`, treat the remote as empty, surface the error in the sync status; **local data is never touched** (§9).
5. **Merge (per-entity LWW).** One merge engine computes the merged wardrobe from {local entities, local tombstones, remote entities, remote tombstones} using the rules in §7. The merge result is both the new container state and the new local target state — one computation, two projections.
6. **Push the container side.** If the merged document differs from the remote one: write it to a temporary local file, then `replace` it at `Documents/sync/wardrobe.json` (or `upload` into a fresh container). Upload every image file of an entity in the merged state that is absent from the container listing (new, or left over from a previously failed transfer) — `upload` per file, with `onProgress`, per-file retry. Delete container image files whose entity is gone from the merged state — `delete` (orphan cleanup).
7. **Apply the local side.** Upsert the winning entities into the local DB (rows, join rows, tag vocabulary), apply deletions, and enforce the composition invariant: an outfit left with zero surviving wearables is deleted in the same merge (FR-8.8, FR-8.9, A-6). Fetch the image files of merged-state entities that are absent locally into the local `images/...` layout; remove local files of entities deleted by the merge (the startup orphan reconciliation in [Data model & local database](data-model-and-database.md) cleans up any residual).
8. **Record.** Store the merged snapshot as the new last-merged state in the local bookkeeping file; write the last successful sync timestamp to `shared_preferences` (FR-10.5); move the status to success.
9. **Emit success.** Notify the UI (the repository stream updates the indicator) and release the pipeline lock; if a trigger fired during the run, start one coalesced follow-up run (§8).

The container document is read (steps 3–4) **before** it is written (step 6) because it is a *shared* document: the write is the local changes **merged into** the existing container document, never a blind whole-file overwrite that would discard another device's changes (A-10, FR-10.7).

### Sequence

```text
Local app (SyncRepository)           IcloudSyncService               iCloud container
      │                                  │                                │
      │ 1. collect local state (DB,      │                                │
      │    tombstones, last-merged)      │                                │
      │ 2. compute local changes         │                                │
      │ 3. list container ──────────────▶│ gather(prefix, timeout) ──────▶│
      │◀─────────────────────────────────│◀───────────────────────────────│
      │ 4. fetch + parse snapshot ──────▶│ getCloudFiles ────────────────▶│
      │◀─────────────────────────────────│◀───────────────────────────────│
      │    on failure: rename → .bad-<ts>, treat remote as empty          │
      │ 5. merge per-entity LWW (one engine, §7)                          │
      │ 6. push: replace wardrobe.json ─▶│ replace ──────────────────────▶│
      │         upload absent images ───▶│ upload (onProgress) ──────────▶│
      │         delete container orphans▶│ delete ───────────────────────▶│
      │ 7. apply: upsert/delete in DB,   │                                │
      │    fetch absent images, clean up │                                │
      │ 8. record last-merged +          │                                │
      │    last-sync timestamp           │                                │
      │ 9. emit success                  │                                │
```

### Merge rules

Per entity (tag, wearable, outfit), the merge decides the merged state:

| Case | Local | Remote (container) | Merged state |
|---|---|---|---|
| **Remote-new** | absent | present | Imported into the local DB; its image files fetched locally |
| **Local-new** | present | absent | Kept locally; uploaded to the container (document + image files) |
| **Both-changed** | `updatedAt` = L | `updatedAt` = R | Last-writer-wins: the newer copy wins; the winner's document and files are the merged state. Identical `updatedAt` → **no change** (idempotent) |
| **Both-deleted** | tombstone | tombstone | Gone; no action |
| **One-side-deleted** | tombstone (`deletedAt` = T) | entity (`updatedAt` = U) | The newer wins: T > U → stays gone (tombstone retained, subject to pruning); U > T → the entity is resurrected (tombstone discarded); T = U → the deletion stands |
| **Image-only change** | document identical on both sides (`updatedAt` equal), image file present on only one side | — | The file is transferred to the side that lacks it (push: `upload`; pull: fetch). A file present on both sides is never re-transferred or byte-compared (§14) |
| **Corrupt document** | — | `wardrobe.json` unparseable | Local data untouched; the remote file is quarantined as `wardrobe.json.bad-<timestamp>`; the error is surfaced; the run continues with the remote treated as empty (§9) |

Merge-time invariants, applied after the per-entity decisions:

- **Composition integrity.** Each surviving outfit's `wearableIds` is filtered to surviving wearables; an outfit left with zero is deleted in the same merge (FR-8.8, FR-8.9, A-6), so the merged state always satisfies the invariants of [Data model & local database](data-model-and-database.md).
- **Tag vocabulary.** A wearable's tag set is materialized from the embedded `tags` array of its winning document; a tag tombstone removes the tag from the vocabulary and strips it from the embedded arrays of all surviving wearable documents in the merged state.
- **Idempotency.** Re-running the same merge changes nothing: no DB write, no file write, no container write (§7).

## 7. Conflict resolution & tombstones

**Last-writer-wins (A-10, FR-10.7).** Every entity carries an `updatedAt` that is bumped on every edit (FR-8.5). When two copies of the same entity conflict, the copy with the **later** `updatedAt` wins, regardless of which side it is on. Identical `updatedAt` means **no change** — the merge is a no-op for that entity, which is what makes a re-merge idempotent.

**Tie rule.** Equal timestamps never trigger a write. Entity vs entity: the existing state stands (the copies agree by definition). Tombstone vs entity: the **deletion stands** — a tie never resurrects data.

**Tombstones.** A deletion is not merely the absence of an entity. The deleting device records a tombstone `{id, deletedAt}` (where `deletedAt` = now, UTC) in the local bookkeeping; it is carried into the snapshot's `deleted` section on the next push and merged into the shared document. That is how deletions propagate to devices that still hold the entity (FR-10.2, FR-10.3).

**Tombstone lifecycle (v1 rule).**

1. Created locally at deletion time, with `deletedAt` = now (UTC).
2. Merged into the shared `wardrobe.json` on the next successful push.
3. **Pruned at merge time when older than 30 days**: a tombstone entry with `deletedAt` earlier than `now − 30 days` is dropped from the merged document. The intent is to prune a tombstone only after it has been observed on all devices; the 30-day timestamp rule is the v1 approximation, since the app has no per-device acknowledgement in v1.

**Documented limitation.** A device that stays offline (or is reinstalled) longer than the 30-day window could **re-introduce a deleted item** on its next push: the tombstone that would have suppressed it has already been pruned from the shared document, while the device's local copy still holds the entity with its old `updatedAt`. This is an accepted v1 trade-off for a personal, single-user wardrobe; see §14.

**Idempotency.** The merge is a pure function of {local state, remote state, `now`}: the same input yields the same output, and applying the output twice makes no further change. Concretely — equal `updatedAt` → no write; an already-applied import → the upsert is a no-op; an already-pruned tombstone → no change; a file present on both sides → not re-transferred.

## 8. Triggers & scheduling

| # | Trigger | Action | Reference |
|---|---|---|---|
| T1 | App start, after the local DB load | Full pipeline: push local changes + pull-merge remote | FR-10.2, FR-11.4 |
| T2 | Local mutation (create / edit / delete / favorite toggle), via the local-change event ([Data model & local database](data-model-and-database.md), Repository API surface) | Debounced (~5 s) run: push, then pull | FR-10.1, FR-10.2 |
| T3 | App resume from background | Full pipeline (pull-merge) | FR-10.2, FR-10.4 |
| T4 | Periodic refresh while the app is in the foreground (optional, ~15 min) | Pull-merge; push if local changes are pending | FR-10.4 |

Scheduling rules:

- **One serialized pipeline.** All triggers funnel into the single pipeline owned by `SyncRepository`, guarded by a lock: **no concurrent sync runs** — the shared `wardrobe.json` has at most one writer at a time.
- **Debounce.** T2 arms a ~5-second timer that is reset by every further mutation; when it expires, exactly one run is scheduled. Rapid edits (for example saving a form) coalesce into a single sync.
- **Coalescing.** A trigger that fires mid-run does not start a second run; it sets a `pending` flag, and when the current run ends, at most one follow-up run executes if the flag is set. A mutation made *during* a run is never lost: the local DB (the source of truth) already contains it, and the follow-up run picks it up.
- **No background sync.** v1 has no daemon: a sync runs only on T1–T4, i.e. while the app is launched, resumed, or in the foreground. A change made while the app is closed propagates at that device's next launch (T1); other devices pick it up on their next trigger.

## 9. Offline behavior & error handling

**Principle (NFR-1, FR-10.4).** The app is fully usable offline. Local state — DB + image files + local tombstones — is always complete and authoritative on the device; sync is a background enhancement. Pending changes are **queued locally by construction**: every mutation is already in the DB and the local tombstones, and the diff against the last-merged state is exactly what is pending. Nothing in the app is ever blocked by sync — no blocking dialogs ([Architecture](architecture.md), Error handling & logging).

**Failure → retry.** A failed run (no network, iCloud unavailable, `METADATA_QUERY_TIMEOUT`, an upload error) loses nothing: the queue stays intact and the pipeline retries with **exponential backoff: 1 min → 2 min → 4 min → 8 min, capped at 15 min** (reset to the base on success). App start (T1) and resume (T3) always attempt a sync regardless of backoff state.

**Corrupt remote snapshot — quarantine.** Two failure levels, matching the error policy in [Architecture](architecture.md):

- **Envelope level** — malformed JSON, or an unknown `formatVersion`: local data is **never touched** (nothing is applied from that file); the remote file is renamed to `Documents/sync/wardrobe.json.bad-<timestamp>` (`rename`) — preserved for inspection, out of the sync path; the error is surfaced in the sync status while the last successful time is retained (FR-10.5). The run then continues with the remote treated as empty: the local state becomes the merged state and is pushed as the new `wardrobe.json`, restoring the user's local data as the shared wardrobe. Any other-device change that existed only inside the corrupt document remains in the `.bad-` file for manual recovery.
- **Entity level** — a single entity document with an unknown enum value, a missing required field, or a wrong type (`FormatException` from `fromJson`): that one entity is **skipped and logged**; the rest of the wardrobe is applied (forward compatibility, per the Architecture error table).

**Per-file image transfer.** Image uploads are independent operations with `onProgress`. A failed file is retried within the run (up to 3 attempts) and then deferred to the backoff retry; it never aborts the run. The document remains the source of truth for which files should exist, and the absence-based transfer rule (§6, steps 6–7) plus the startup orphan reconciliation ([Data model & local database](data-model-and-database.md)) converge both sides.

**User-visible status states.**

| State | Indicator (Apple platforms) | FR reference |
|---|---|---|
| Idle — last sync succeeded | "Last synced 12:30" (last successful time, FR-10.5) | FR-10.5 |
| Idle — never succeeded | "Not synced yet" | FR-10.5 |
| Syncing | "Syncing…" (subtle in-progress state) | FR-10.5 |
| Error | Short reason ("Sync paused — no connection", "Sync error — remote data quarantined") plus the last successful time; previous timestamp retained | FR-10.4, FR-10.5 |

## 10. Status & user-visible behavior

- **Where the indicator appears (Apple platforms only).** A lightweight indicator in the app header area — a clock glyph plus short text; visual treatment, placement per window width, and the screen-reader label (≥ 44 × 44 logical px target) are defined in [UI & design language](ui-design.md) and [Responsive design](responsive-design.md). It is not a menu and not a settings page; in the error state it reveals the last successful time and the short reason.
- **Source of the value.** The last successful sync timestamp is stored via `shared_preferences` ([Architecture](architecture.md), Tech stack) and exposed through `AppViewModel`/`SyncRepository`; on Android `syncAvailable` is `false` and the indicator does not exist at all.
- **Copy examples.**
  - Idle, synced: `Last synced 12:30`
  - Idle, never synced: `Not synced yet`
  - Running: `Syncing…`
  - Error: `Sync paused — no connection` or `Sync error — remote data quarantined`, always alongside the last successful time.
- **Android no-UI rule.** No sync indicator, no menu entry, no settings, no wording that references synchronization — the feature set is otherwise complete (FR-10.5, FR-10.6).

## 11. Security & privacy

- **No accounts, no Apple ID handling.** The app never requests credentials, never performs Apple ID sign-in, and stores no credentials (FR-11.3; [Functional specification](functional-specification.md) §9: no third-party logins). Container authentication is performed by the platform via the iCloud entitlements and the user's already-signed-in Apple account; the app merely uses the container.
- **Data goes only to the user's own iCloud.** The sole replication path is the `iCloud.<team-id>.<bundle-id>` container of the user's Apple account (NFR-2, FR-10.1). There is no server, no remote API, no analytics, no telemetry, and nothing else is transmitted (NFR-2, FR-11.3).
- **Encryption.** The app relies on Apple's iCloud encryption — Apple's infrastructure encrypts iCloud data in transit and at rest. v1 adds no application-level (end-to-end) encryption of its own: the threat model is the user's own account on the user's own devices, which is the documented scope of the "private by design" guarantee ([Functional specification](functional-specification.md) §1).
- **Quarantine files** (`wardrobe.json.bad-*`) contain wardrobe data; they reside in the same user-owned container and are never transmitted anywhere else.

## 12. First-launch on a new device

Scenario: a fresh install on a second Apple device, the same Apple account, a wardrobe that already exists on another device.

1. The app launches; onboarding runs (FR-1.1 – FR-1.5). The onboarding flag is device-local and is unaffected by sync.
2. After the local DB load and onboarding completion, T1 fires. While this first run is in flight the app shows a brief first-launch loading state ("Setting up your wardrobe…"); **Home is shown only when the run finishes** — the pull-merge imports the full remote wardrobe (snapshot document + all image files) before Home is displayed.
3. The pipeline lists the container, fetches `Documents/sync/wardrobe.json`, and parses it (quarantine path on failure, §9).
4. The merge classifies every remote entity as **remote-new** (the local wardrobe is empty) → all tags, wearables, and outfits are imported into the local DB; every referenced image file (compressed original + thumbnail per entity) is fetched into the local `images/...` layout.
5. The last-merged state and the last successful sync timestamp are recorded; the indicator shows "Last synced …" (FR-10.5).
6. Home is shown with the imported wardrobe — the three sections populated (FR-3.1 – FR-3.4).

**FR-3.6 interaction.** The welcoming empty state is shown **only when the wardrobe is genuinely empty on all devices** — that is, when the first pull completes and finds no remote snapshot, or an empty one. If the first pull fails (offline), the app still proceeds to Home with the empty local state: the empty state with its calls to action is shown, the sync indicator carries the error, and anything the user adds works locally and syncs on the next successful run (FR-3.6, FR-10.4, NFR-1).

## 13. Testing strategy

### Unit tests — the merge engine (fake `SyncService`)

The merge engine is the unit under test. Per the conventions in [Architecture](architecture.md) (Testing strategy), it is exercised with hand-written fakes of the `SyncService` interface (no generated mocks), an in-memory `drift` database, and a temporary directory for image files, so tests are deterministic and leave no artifacts.

| # | Case | Setup | Expected |
|---|---|---|---|
| M1 | Remote-new import | Entity only in the remote document | Imported into the local DB; image files fetched locally; no document re-upload when no local change exists |
| M2 | Local-new upload | Entity only in the local DB | Uploaded merged document contains it; image uploaded; container listing grows |
| M3 | Both-changed, local wins | L.`updatedAt` > R.`updatedAt` | Local row kept; container document carries the local values |
| M4 | Both-changed, remote wins | R.`updatedAt` > L.`updatedAt` | Local row replaced; remote image file written locally |
| M5 | Identical `updatedAt` | L.`updatedAt` = R.`updatedAt`, equal content | No DB write, no container write (no-op) |
| M6 | Re-merge idempotency | Same merge input applied twice | The second application changes nothing (DB, files, status) |
| M7 | Remote deletion wins | Remote tombstone with `deletedAt` > L.`updatedAt` | Local entity deleted (row + image files); tombstone retained in the merged document |
| M8 | Local deletion wins | Local tombstone with `deletedAt` > R.`updatedAt` | Entity absent from the merged state; merged document carries the tombstone |
| M9 | Both deleted | Tombstones on both sides | Entity gone; no action |
| M10 | Deletion tie | `deletedAt` = other side's `updatedAt` | Deletion stands; no resurrection |
| M11 | Tombstone pruning | Tombstone `deletedAt` older than 30 days | Pruned from the merged document |
| M12 | Long-offline re-introduction (documented limitation) | Stale local entity whose tombstone was already pruned elsewhere | After the device's push the entity reappears — asserts the documented v1 behavior (§7) |
| M13 | Corrupt remote document | Unparseable `wardrobe.json` | Local DB/files untouched; file renamed to `wardrobe.json.bad-<timestamp>`; error surfaced; local state pushed as the new document |
| M14 | Composition integrity | Outfit's `wearableIds` references a tombstoned wearable | Outfit recomputed; deleted when left with zero wearables (FR-8.8, FR-8.9) |
| M15 | Image convergence | Document present on both sides; image file absent on one side | File transferred to the absent side; a file present on both sides is never re-transferred |

```bash
flutter test
```

### Manual two-device acceptance script

Two Apple devices (for example an iPhone and a Mac) signed in to the **same Apple account**, both running the same build, network available.

1. **Add on A → appears on B.** On device A, add a wearable with a photo and an outfit containing it (FR-8.2, FR-8.3). Resume device B (or wait for the periodic refresh). Expected: the wearable and the outfit appear on B with both images, in the lists and on Home (FR-10.3).
2. **Edit conflict → LWW outcome.** While both devices are online, edit the same field of the same wearable on A, then on B, so both saves land (A first, then B). Expected: after both devices' next sync, both show B's value — the later `updatedAt` wins (A-10, FR-10.7); no crash, no duplicate.
3. **Delete on A → gone from B.** On A, delete the wearable (confirming the cascade dialog, FR-8.7). Expected: after B's next sync, the wearable is gone from B, its outfits are recomputed per FR-8.8/FR-8.9, and its image files are removed from B (FR-10.3).
4. **Offline A → queued, then synced.** Put A into airplane mode (FR-11.2); add another wearable on A — it appears locally and the indicator shows the error state with the last successful time. Reconnect. Expected: the next trigger (resume / periodic) pushes the wearable and it appears on B; nothing is lost (FR-10.4).
5. **Status.** Throughout, each device's indicator updates its last successful time after every successful run (FR-10.5). Android is out of scope for this script (FR-10.6).

This script is the manual realization of the final acceptance checkbox in [Functional specification](functional-specification.md) §10:

> "On Apple platforms, outfits, wearables, favorite flags, and images added on one device appear on a second device signed in to the same Apple account (see [iCloud sync](icloud-sync.md))."

## 14. Known limitations & future work

| # | Limitation (v1) | Notes / future work |
|---|---|---|
| 1 | **Tombstone pruning window (30 days).** A device offline longer than the window could re-introduce a deleted item on its next push (§7) | Future: per-device "last-seen" watermarks so tombstones can be pruned only after being observed on all devices |
| 2 | **Single user, single wardrobe.** One wardrobe per Apple account; no profiles, roles, or shared wardrobes | Out of scope by product decision ([Functional specification](functional-specification.md) §9) |
| 3 | **No byte-level image diffing.** An image file is transferred only when absent on the other side; a file present on both sides is never compared or re-transferred, even if the bytes differ | Future: content-hash comparison if divergence becomes observable |
| 4 | **Whole-snapshot document.** Every sync rewrites a single merged `wardrobe.json`; the merge is O(wardrobe size) | Fine for a personal wardrobe (hundreds of items); a delta-based protocol if wardrobes grow large |
| 5 | **No background sync.** Runs only on T1–T4; a change propagates at the device's next launch/resume | The plugin has no background-fetch API; v1 relies on the foreground triggers |
| 6 | **No application-level encryption.** Relies on Apple's iCloud encryption in transit and at rest (§11) | End-to-end encryption would require key-management design; out of scope for v1 |
| 7 | **Android is local-only.** No sync and no sync UI (FR-10.6) | iCloud is an Apple service; a non-Apple sync backend is a product decision beyond v1 |
| 8 | **`icloud_storage_sync` 0.0.5, iOS + macOS only.** Version constraint re-verified at implementation time (§3) | Track the package's releases; the `SyncService` seam isolates the plugin, so an upgrade or swap is contained to `IcloudSyncService` |
