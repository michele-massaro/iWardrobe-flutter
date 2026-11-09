# Task 025 — Sync status indicator

| | |
|---|---|
| **Phase** | 5 — Sync completion |
| **Depends on** | 013 (shell slots), 010 (status stream) |
| **Primary references** | [iCloud sync](../icloud-sync.md) §10 User-visible status · [UI & design language](../ui-design.md) §10 (sync copy) · [Responsive design](../responsive-design.md) §5 (Sync status row) · [Functional specification](../functional-specification.md) FR-10.5, NFR-4 |

## Objective

Deliver the single, minimal, **passive** sync-status indicator — a small clock glyph + one line of status text — that appears on **Apple platforms only**, in the breakpoint-appropriate slot, and renders the four documented states with the frozen copy. The user story: *as a user on iPhone, iPad, or Mac, I want a subtle cue of when my wardrobe last synced and when a sync problem occurred, without a settings screen or menu.*

## What the agent must deliver

### 1. `SyncStatusIndicator` — `lib/ui/core/widgets/sync_status_indicator.dart`

A non-interactive (passive) widget — no tap, no menu, no settings (v1 has no sync management UI):

- **Appearance:** small clock glyph (≈ 16–20 px) + status text (Label style, `text-secondary` color); tabular figures for the timestamp.
- **States & frozen copy** (iCloud doc §10, UI doc §10):

| State (from `SyncRepository` status stream, task 010) | Copy |
|---|---|
| Idle, last sync known | "Last synced 12:30" (local time) |
| Idle, never synced | "Not synced yet" |
| Syncing | "Syncing…" |
| Error | "Sync paused — no connection" **and** the last successful time, kept from before the failure (FR-10.5) — or "Sync error — remote data quarantined" for the quarantine reason |

- The reason (transient network vs quarantine) comes from the status data (task 010 exposes the reason enum) — the widget maps it to copy.
- **Screen-reader label** describing the full state (NFR-4 — audit in 028).

### 2. Placement (Responsive design doc §5, "Sync status" row)

- **compact / medium (`< 1024`):** trailing position of the **app bar** (top-right) of the active screen.
- **expanded (`≥ 1024`):** trailing slot of the **NavigationRail** (reserved in task 013) — or the app-bar trailing position if the screen uses the app bar; consistent across screens.
- **Visibility:** rendered **only** when `AppViewModel.syncAvailable` is true (Apple platforms, FR-10.5). On **Android the indicator never appears** — no sync UI of any kind (FR-10.6).
- The indicator is a shell-level / screen-chrome concern: one instance per visible chrome (task 013's shell slots), driven by the shared `SyncRepository` status stream — not per-screen widgets.

## Definition of done

**Build** (standard gate): all items pass.

**Widget test constraints** — `test/ui/widgets/sync_status/` (fake `SyncRepository` status stream; `AppViewModel.syncAvailable` toggled):

- [ ] **Each state renders the exact frozen copy:** idle-last ("Last synced 12:30" — assert the local-time formatting from a fixed UTC input), idle-never ("Not synced yet"), syncing ("Syncing…"), error-network ("Sync paused — no connection"), error-quarantine ("Sync error — remote data quarantined").
- [ ] **Timestamp retention:** on the error state, the **previous** successful time is still shown (FR-10.5) — the indicator never regresses to "Not synced yet" after a failure.
- [ ] **Android visibility:** with `syncAvailable == false` the widget renders nothing (zero size / absent) at every breakpoint (FR-10.6).
- [ ] **Apple placement:** at 375 px the indicator sits in the app-bar trailing slot; at 1024 px in the rail trailing slot (assert via the shell integration from task 013).
- [ ] **Passive:** the widget exposes no tap gesture (the hit test finds no `InkWell`/`GestureDetector`); it is pure display.
- [ ] **Live updates:** the status stream transitioning syncing → idle-last updates the text without a widget rebuild of the shell.
- [ ] **Screen-reader:** the semantic label changes with the state (assert the label string per state).

**Functional acceptance**

- [ ] The indicator consumes only the `SyncRepository` status stream + `AppViewModel.syncAvailable` — no direct `SyncService` or platform checks.
- [ ] No sync settings/menu/management UI is introduced (explicitly out of scope for v1).

**Out of scope for this task:** the status data (010), two-device behavior (026), any sync controls.
