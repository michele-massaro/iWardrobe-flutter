# Task 007 — Sync events, snapshot envelope & merge engine

| | |
|---|---|
| **Phase** | 2 — Data layer |
| **Depends on** | 002 |
| **Primary references** | [iCloud sync](../icloud-sync.md) §4 What is synchronized (envelope), §6 Sync protocol (merge rules), §7 Conflict resolution & tombstones, §13 Testing strategy (M1–M15) · [Data model](../data-model-and-database.md) §JSON wire format |

## Objective

Deliver the pure core of the sync system: the local-change event types the repositories will emit, the `wardrobe.json` snapshot envelope, the local bookkeeping (last-merged state + local tombstones), and the **merge engine** — a pure function computing the merged wardrobe from {local, remote, now} with last-writer-wins, tombstones, pruning, and idempotency. This task contains no I/O beyond the bookkeeping file; the pipeline that applies its results is task 010.

## What the agent must deliver

### 1. Sync change events — `lib/domain/sync_events.dart`

A small sealed type for local mutations (consumed by `SyncRepository` in task 010): entity kind (`wearable` | `outfit` | `tag`), action (`created` | `updated` | `deleted`), entity id, and UTC timestamp. Repositories (008/009) emit one event per mutation through the same call path on every platform (on Android it reaches `NoopSyncService` and dies — FR-10.6).

### 2. Snapshot envelope — `lib/data/sync/snapshot.dart`

The exact envelope of the iCloud sync doc §4 "The snapshot document (envelope)":

```json
{ "formatVersion": 1, "updatedAt": "...", "tags": [...], "wearables": [...],
  "outfits": [...], "deleted": { "tags": [], "wearables": [{ "id", "deletedAt" }], "outfits": [] } }
```

- `formatVersion`: integer, `1` in v1. A reader meeting an **unknown version refuses the whole document** (quarantine path) — never a partial merge. Model the rejection so the pipeline can distinguish "unknown version / malformed" (quarantine) from "single bad entity" (skip + log).
- `updatedAt`: latest `updatedAt` across wearables and outfits (informational; per-entity comparison is authoritative).
- `tags`/`wearables`/`outfits`: exactly the entity documents of the JSON wire format (task 002) — not redefined here.
- `deleted`: tombstones `{id, deletedAt}` per entity kind.
- Unknown fields ignored on read; malformed required content → `FormatException`.
- `fromDatabase(...)` builder: serialize the local DB content (via repository-free raw access passed in) plus local tombstones into an envelope — used at push time (the local `wardrobe.db` is **never** transferred; only its content, iCloud doc §4).

### 3. Local bookkeeping — `lib/data/sync/bookkeeping.dart`

Per-device, **never synchronized** (iCloud doc §4 "What is not synchronized"):

- Last-merged state: the wardrobe as it stood after the last successful sync (envelope on disk under the documents dir, e.g. `sync_bookkeeping/last_merged.json`).
- Local tombstones: `{id, deletedAt}` created at deletion time, carried into the snapshot's `deleted` section on the next push, merged into the shared document, and pruned per the 30-day rule below.
- A `SyncBookkeepingService` with load/save/append-tombstone/replace-merged-state operations (file I/O only; domain shapes reused).

### 4. Merge engine — `lib/data/sync/merge_engine.dart`

**Pure function** (no I/O; file transfers become a *plan* in the output):

`MergeResult merge({required localEntities, required localTombstones, required remoteEntities, required remoteTombstones, required DateTime now})`

Per-entity decisions exactly per the iCloud doc §6 "Merge rules" table:

| Case | Result |
|---|---|
| Remote-new | Import into local; plan fetch of its image files |
| Local-new | Keep locally; plan upload (document + image files) |
| Both-changed | LWW by `updatedAt`; winner's document + files win. **Identical `updatedAt` → no change** (idempotent no-op) |
| Both-deleted | Gone; no action |
| One-side-deleted | Newer wins: `deletedAt` > other `updatedAt` → stays gone; other > `deletedAt` → resurrected; **tie → deletion stands** |
| Image-only change | Document identical both sides; file present on only one side → transfer to the absent side (push/pull plan). Present on both → **never** re-transferred or byte-compared |

Merge-time invariants applied after per-entity decisions:

- **Composition integrity:** each surviving outfit's `wearableIds` filtered to surviving wearables; an outfit left with zero is deleted in the same merge (FR-8.8, FR-8.9, A-6).
- **Tag vocabulary:** a tag's tombstone removes it from the vocabulary and strips it from the embedded `tags` arrays of all surviving wearable documents.
- **Tombstone pruning:** tombstones with `deletedAt` older than `now − 30 days` are dropped from the merged document (v1 approximation — iCloud doc §7, documented limitation).
- **Idempotency:** equal `updatedAt` → no write; already-applied import → no-op; the same input yields the same output, and applying the output twice changes nothing.

`MergeResult` carries: the merged entities (new container state **and** new local target state — one computation, two projections), the surviving tombstones, and the image transfer plan (upload list, fetch list, container-orphan delete list — absence-based, per doc §6 steps 6–7).

## Definition of done

**Build** (standard gate): all items pass. The merge engine file has no import of any service, plugin, or repository (pure domain/data logic).

**Unit test constraints** — `test/data/sync/merge/` must implement **all fifteen** cases M1–M15 of the iCloud doc §13 table, plus:

- [ ] **M1** remote-new import (no document re-upload when no local change).
- [ ] **M2** local-new upload (merged document contains it; image in upload plan).
- [ ] **M3** both-changed, local wins.
- [ ] **M4** both-changed, remote wins (local row replaced; remote image in fetch plan).
- [ ] **M5** identical `updatedAt` → no DB write, no container write (no-op).
- [ ] **M6** re-merge idempotency (second application changes nothing).
- [ ] **M7** remote deletion wins (local entity gone; tombstone retained).
- [ ] **M8** local deletion wins (entity absent from merged state; tombstone carried).
- [ ] **M9** both deleted → gone, no action.
- [ ] **M10** deletion tie → deletion stands, no resurrection.
- [ ] **M11** tombstone pruning (older than 30 days dropped).
- [ ] **M12** long-offline re-introduction (asserts the *documented limitation*, iCloud doc §7/§14).
- [ ] **M13** corrupt remote document → local untouched; quarantine flag set (engine signals; pipeline renames).
- [ ] **M14** composition integrity (outfit recomputed; deleted when left empty).
- [ ] **M15** image convergence (file transferred to absent side only; present on both → never re-transferred).
- [ ] **Envelope:** round-trip of the doc's example envelope; unknown `formatVersion` rejected as quarantine-grade; a single malformed entity is distinguishable from envelope-level failure (skip-and-log vs quarantine, doc §9).
- [ ] **Bookkeeping:** tombstone append + prune round-trip through `SyncBookkeepingService` (temp dir); last-merged state replace/load.

**Functional acceptance**

- [ ] The tie rule is encoded: equal timestamps never trigger a write; tombstone-vs-entity tie → deletion stands.
- [ ] The 30-day pruning window and its documented limitation are present in code comments referencing the doc.

**Out of scope for this task:** pipeline triggers/serialization/backoff (010), actual file transfers (010), any UI.
