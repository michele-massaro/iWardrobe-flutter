# Task 026 — Two-device sync verification

| | |
|---|---|
| **Phase** | 5 — Sync completion |
| **Depends on** | 025, working Apple device builds |
| **Primary references** | [iCloud sync](../icloud-sync.md) §13 Testing strategy (manual two-device script), §12 First-launch on a new device, §8 Triggers · [Functional specification](../functional-specification.md) FR-10.1 – FR-10.7, FR-3.6 |

## Objective

Verify, on **two real Apple devices** signed into the same Apple account, that the sync implemented in tasks 006–010 behaves end-to-end as specified — and record the evidence. This is the acceptance task for the F-10 feature set; it is a verification pass, not an implementation one (any defect found is fixed here, with a regression test where the defect is reproducible in unit tests). The user story: *as a user with an iPhone and a Mac, I want the outfit I add on one device to appear on the other, and I want to see sync working in real time.*

## What the agent must do

### 1. Prepare

- Two Apple devices (any two of: iPhone, iPad, Mac) signed in to the **same** Apple account; the app's container id is the real one (task 006's placeholder `TEAM123` replaced with the real team id — if not yet set, record it as a blocker and complete what is possible on simulators where the plugin supports them, flagging the gap).
- Both builds from the current `master`, installed.

### 2. Execute the documented manual script (iCloud doc §13, all five steps)

1. **Add on A → appears on B.** Add a wearable + an outfit on device A (wait for the debounce run, T2). On device B, trigger a refresh (resume the app, T3). Assert the new items appear **with their images** (not just rows).
2. **Edit conflict → last-writer-wins.** Edit the same item's name on A and B while both are online; whichever saved later (later `updatedAt`) wins on **both** devices after the next runs.
3. **Delete on A → gone on B.** Delete an item on A; on B the item disappears on the next refresh (tombstone propagation).
4. **Offline change.** Turn A offline, add an item; it stays local and the app stays fully usable (FR-10.4); the indicator shows the error/paused state; go back online → the item syncs to B (pending changes sync when connectivity returns).
5. **Images.** Assert image files (not just metadata) are present on both sides — grid + detail render the photo on B.

### 3. First-launch on a new device (iCloud doc §12)

- Fresh install on device C (or a wiped simulator with the container reachable): on first launch the pull imports the existing wardrobe **before** "ready"; Home shows the imported content; the empty-wardrobe welcome state (FR-3.6) is shown only when the wardrobe is truly empty on all devices.
- Verify the indicator transitions "Not synced yet" → "Last synced …" (task 025 copy).

### 4. Android negative check

- On an Android device/emulator: **no** sync indicator, no sync UI of any kind (FR-10.6); the app is fully functional with local-only data (FR-10.5/10.6).

### 5. Record the evidence

Fill in the **Verification log** below: date, devices + build (commit ref), per-step pass/fail with notes, and any blocker (e.g. real team id pending). Any fix made during this task is committed with a message referencing this task; if a unit-testable defect is found, the corresponding regression test is added in 007–010's test suites (referenced in the log).

## Definition of done

**Build** (build constraint): the app builds and installs on both Apple devices used (the standard build gate passes on `master`).

**Verification constraint** (this task's binding requirement — there is no unit-test suite for this task; the matrix itself is the evidence):

- [ ] All **five** manual-script steps executed and **passing** (iCloud doc §13), logged in the Verification log with timestamps + device names.
- [ ] First-launch import on a new device verified (doc §12), logged.
- [ ] Offline change + reconnect sync verified (FR-10.4), logged — including the indicator's error state during offline and its recovery.
- [ ] Cross-device image transfer verified (photos visible on both devices, FR-10.1).
- [ ] Android device shows **zero** sync UI (FR-10.6), logged.
- [ ] Any defect found: fixed, committed, and (if unit-testable) regression-tested; the fix noted in the log.
- [ ] The `Verification log` section below is complete (no empty rows).

## Verification log

| Date | Devices (model + build ref) | Step | Result | Notes |
|---|---|---|---|---|
| — | — | 1 — add on A → appears on B (with images) | ☐ | |
| — | — | 2 — edit conflict → LWW | ☐ | |
| — | — | 3 — delete on A → gone on B | ☐ | |
| — | — | 4 — offline change → syncs on reconnect | ☐ | |
| — | — | 5 — images present on both sides | ☐ | |
| — | — | First-launch import on new device (FR-3.6) | ☐ | |
| — | — | Android: no sync UI (FR-10.6) | ☐ | |

## Out of scope

Fixing the sync *protocol* (documented in 007–010 — deviations must go through the docs first, `instructions.md` §5); iCloud account provisioning beyond replacing the team id; any sync management UI.
