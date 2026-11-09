# Task 010 — SyncRepository pipeline

| | |
|---|---|
| **Phase** | 2 — Data layer |
| **Depends on** | 005, 006, 007, 008, 009 |
| **Primary references** | [iCloud sync](../icloud-sync.md) §6 Sync protocol (sequence, steps 1–9), §8 Triggers & scheduling, §9 Offline behavior & error handling, §12 First-launch on a new device |

## Objective

Deliver `SyncRepository` — the owner of the **single serialized sync pipeline** that turns the merge engine (007) into a running system: triggers and scheduling (T1–T4), debounce and coalescing, the 9-step push/pull run, container-side and local-side application, failure handling with exponential backoff, corrupt-snapshot quarantine, image transfer, and the observable status that the UI (task 025) will render.

## What the agent must deliver

### 1. Constructor & inputs

`SyncRepository({required SyncService sync, required PreferencesService preferences, required WearableRepository wearables, required OutfitRepository outfits, required SyncBookkeepingService bookkeeping})` — exactly the registration in Architecture §Dependency injection. No platform checks inside: `sync.available == false` (Android) short-circuits the whole repository into inert (no queue, no retry, no status state — FR-10.6).

### 2. Triggers & scheduling (iCloud doc §8)

| # | Trigger | Action |
|---|---|---|
| T1 | App start, after the local DB load | Full pipeline: push + pull-merge |
| T2 | Local mutation via `localChanges` events (008/009) | Debounced (~5 s) run: push, then pull |
| T3 | App resume from background | Full pipeline (pull-merge) |
| T4 | Periodic refresh while foreground (optional, ~15 min) | Pull-merge; push if pending |

Rules (binding):

- **One serialized pipeline** guarded by a lock — no concurrent runs (at most one writer of the shared `wardrobe.json`).
- **Debounce:** T2 arms a ~5 s timer reset by every further mutation; when it expires, exactly one run is scheduled.
- **Coalescing:** a trigger firing mid-run sets a `pending` flag; on completion, at most one follow-up run executes if the flag is set. A mutation made *during* a run is never lost (the local DB already contains it; the follow-up picks it up).
- **No background daemon:** runs only on T1–T4.

### 3. The 9-step run (iCloud doc §6 — implement in order)

1. **Collect local state** — serialize all tags/wearables/outfits to wire documents (task 002 shapes); load local tombstones; load the last-merged state.
2. **Compute local changes** — added/modified since last-merged (new id, or `updatedAt` newer), plus new tombstones. Nothing changed → pull-only run.
3. **List the container** — `sync.listFiles(prefix: 'Documents/', timeout)`; the listing is the presence index for image operations.
4. **Fetch & parse the remote snapshot** — `Documents/sync/wardrobe.json`. **On failure: quarantine** — `sync.rename` to `Documents/sync/wardrobe.json.bad-<timestamp>`, treat remote as empty, surface the error in status; **local data is never touched** (doc §9).
5. **Merge** — the pure engine (007) computes the merged state from {local, local tombstones, remote, remote tombstones}.
6. **Push the container side** — if merged ≠ remote: write the merged envelope to a temp file, `replace` at `Documents/sync/wardrobe.json` (or `upload` into a fresh container); `upload` every image of a merged-state entity absent from the container listing (per-file `onProgress`, per-file retry); `delete` container image files whose entity is gone (orphan cleanup).
7. **Apply the local side** — upsert winning entities into the local DB (rows, joins, tag vocabulary); apply deletions; enforce the composition invariant (outfit left with zero surviving wearables is deleted in the same merge — FR-8.8/8.9/A-6); fetch absent image files into the local `images/...` layout; remove local files of entities deleted by the merge (startup orphan reconciliation cleans residuals).
8. **Record** — store the merged envelope as the new last-merged state (bookkeeping); write the last successful sync timestamp to `PreferencesService` (FR-10.5); status → success.
9. **Emit success** — update the status stream; release the lock; start one coalesced follow-up if a trigger fired mid-run.

The container document is read (3–4) **before** it is written (6): the write is local changes **merged into** the existing document, never a blind whole-file overwrite (A-10, FR-10.7).

### 4. Failure handling (iCloud doc §9)

- **Failure → retry:** no network, iCloud unavailable, `METADATA_QUERY_TIMEOUT` (transient from 006), upload errors — the queue stays intact; **exponential backoff 1 min → 2 → 4 → 8, capped at 15 min**, reset to base on success. T1 and T3 always attempt regardless of backoff state.
- **Corrupt remote snapshot (envelope level):** local data never touched; file renamed to `wardrobe.json.bad-<timestamp>` (preserved, out of the sync path); error surfaced with the last successful time retained (FR-10.5); the run continues with remote treated as empty, so the local state becomes the new shared document.
- **Entity level:** a single entity with an unknown enum/missing field/wrong type is **skipped and logged**; the rest is applied (forward compatibility).
- **Per-file image transfer:** independent operations; a failed file retries up to 3 times within the run, then defers to backoff; never aborts the run. Absence-based transfer + startup orphan reconciliation converge both sides.

### 5. Deletion propagation

Deleting on one device records a local tombstone (`{id, deletedAt = now UTC}`) via the bookkeeping (007); it is merged into the shared `wardrobe.json` on the next successful push and merged on the other devices — this is how deletions propagate (FR-10.2/10.3).

### 6. Status stream (consumed by task 025)

An observable (e.g. `Stream<SyncStatus>` or a `ValueNotifier`) exposing exactly the four doc states: idle-last (`lastSyncAt`), idle-never, syncing, error (short reason + retained last successful time). Copy strings are owned by task 025/UI doc; this task exposes the **data** (state enum + `DateTime?` + reason enum).

## Definition of done

**Build** (standard gate): all items pass. No `TargetPlatform` branch anywhere in the pipeline (the seam is `sync.available`, set once at registration).

**Unit test constraints** — `test/data/sync/pipeline/` (fake `SyncService`, in-memory DB, temp dir, per Architecture §Testing strategy — hand-written fakes, no generated mocks):

- [ ] **Full push:** local-new entities + tombstones are pushed; the container `wardrobe.json` carries the merged envelope; images of new entities uploaded; first push uses `upload` (fresh container) and later runs `replace`.
- [ ] **Full pull:** remote-new entities are imported into the local DB with correct rows/joins; their images fetched into the local layout; `streamById`/filtered streams reflect them.
- [ ] **LWW end-to-end:** conflicting edits → the later `updatedAt` wins on **both** sides after two runs (doc §13 manual-script case 2).
- [ ] **Deletion propagation:** delete on local → tombstone in the pushed envelope; applying a remote tombstone deletes the local row + files and recomputes outfits (FR-8.8/8.9).
- [ ] **Debounce:** N rapid mutations → exactly one scheduled run after the timer expires.
- [ ] **Coalescing:** a trigger mid-run produces at most one follow-up; a mutation during the run is included in the follow-up (never lost).
- [ ] **Serialization:** two concurrent trigger firings never run the pipeline concurrently (lock held; second waits/coalesces).
- [ ] **Backoff:** failing runs schedule retries 1→2→4→8 min, capped at 15; success resets to base; T1/T3 bypass backoff.
- [ ] **Quarantine:** corrupt `wardrobe.json` (unparseable / unknown `formatVersion`) → file renamed `wardrobe.json.bad-<ts>`; local DB + files untouched; error state surfaced with previous timestamp retained; local state then pushed as the new document.
- [ ] **Entity-level corruption:** one bad entity skipped + logged; the rest applied.
- [ ] **Image convergence:** absent-on-one-side files transferred; files present on both sides never re-transferred (no byte comparison).
- [ ] **Container orphan cleanup:** image files whose entity is gone from the merged state are `delete`d.
- [ ] **Status transitions:** idle-never → syncing → idle-last (with timestamp) on success; → error (with reason) on failure; Android (`available == false`) → the repository stays inert, no status changes.
- [ ] **First-launch pull (doc §12):** empty local + non-empty remote → full import before the "ready" signal; empty local + empty/absent remote → empty-wardrobe signal (FR-3.6 interaction).

**Functional acceptance**

- [ ] The pipeline is the **only** code path that calls `SyncService` (008/009 never touch it directly).
- [ ] The "no background sync" rule holds: no timer survives app close (T1–T4 only).
- [ ] `flutter test` for this task runs deterministically (faked clocks/timers; no real network or plugin).

**Out of scope for this task:** the status indicator UI (025), two-device verification (026), Xcode setup (006).
