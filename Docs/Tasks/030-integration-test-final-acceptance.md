# Task 030 — Integration test & final acceptance

| | |
|---|---|
| **Phase** | 6 — Quality & acceptance |
| **Depends on** | all |
| **Primary references** | [Functional specification](../functional-specification.md) §10 Acceptance criteria · [Architecture](../architecture.md) §Testing strategy · [instructions.md](../../instructions.md) §9 Git workflow |

## Objective

Close the project: add the **integration test** that exercises the end-to-end user flow on a real device, then verify that **every acceptance criterion in functional spec §10** is covered by an automated test or a recorded manual script, and leave the repository in release-ready state. The user story: *as the owner, I want one recorded proof that the app works end-to-end and a checklist showing nothing from the specification was left undone.*

## What the agent must do

### 1. Integration test — `test/integration_test/wardrobe_flow_test.dart`

Per the Architecture doc §Testing strategy, the smoke flow on a real device/emulator (`flutter test integration_test`):

1. Add a **wearable** (with a photo via the picker flow, type, color, tags).
2. Add an **outfit** composing ≥ 1 of the wearables (with a photo).
3. Mark the outfit **favorite** (heart on the card).
4. Open **Home** — assert the outfit appears in *Latest outfits* (FR-3.2, FR-8.12) **and** in *Favorite outfits* (FR-3.3); the wearable is visible in the Wearables list (FR-6.1).
5. (Apple simulator) observe the sync indicator state transitions (025) — no crash on the first sync run (T1).

The test uses the real repositories/database (on-device SQLite, not in-memory) and the real router — it is the proof that the layers integrate.

### 2. Acceptance coverage — functional spec §10, box by box

For **every** checkbox in functional spec §10 (the acceptance criteria), record in the Final acceptance log below:

- which automated test file covers it (unit/widget/integration — with the test name), **or**
- which recorded manual script covers it (task 026's Verification log rows), **or**
- why it is structurally guaranteed (cite the task + code path).

Uncovered boxes are defects: implement the missing test (or fix the product) before closing this task. The onboarding-shown-once, tab state preservation, Home sections, filter semantics (AND across / OR within), immediate + persistent favorites, full CRUD with cascade rules, **offline usability in airplane mode** (FR-11.2/FR-11.3 — verify on-device with the network off: every feature works; nothing is transmitted), and the Apple cross-device item (via 026) must all be checkable.

### 3. Code-quality & repo hygiene (release gate)

- Full standard build gate on `master` (including all platform builds).
- Architecture PR rules verified (instructions.md §7): no dependency outside the tech-stack table; no layering violation (View → ViewModel → Repository); **no platform branching outside the `SyncService` registration**; no untracked generated files; no `TODO`/`FIXME` left in `lib/`.
- `Docs/` consistency: every doc's companion row + this task folder's index are in sync; the root `README.md` matches reality.
- Commit everything; no push unless asked.

## Definition of done

**Build constraint:**

- [ ] `flutter test integration_test` passes on a device/emulator (the smoke flow end-to-end).
- [ ] Full standard build gate green on `master`.

**Acceptance constraint:**

- [ ] **Every** box in functional spec §10 is checked off in the Final acceptance log below with its evidence (test file + test name, or 026 log row, or structural citation). Zero open boxes.
- [ ] Airplane-mode run recorded: all features work offline; no network traffic (FR-11.2, FR-11.3, NFR-1, NFR-2).
- [ ] Architecture PR rules verified (grep results cited in the log).
- [ ] No `TODO`/`FIXME` in `lib/`; no untracked generated files; `Docs/` index + companion rows consistent; root README accurate.
- [ ] The Final acceptance log is complete (no empty rows, all boxes with evidence).

## Final acceptance log

| §10 criterion (paraphrase) | Evidence (test file::test / log row / structural) | Status |
|---|---|---|
| Onboarding shown once on first launch | — | ☐ |
| Three tabs, state preserved per branch | — | ☐ |
| Home: three sections in order, latest/favorites | — | ☐ |
| Filters: name/type/color/tag, AND across, OR within tags | — | ☐ |
| Favorite toggle immediate + persistent (both entities) | — | ☐ |
| CRUD for wearables + cascade (FR-8.7–8.10) | — | ☐ |
| CRUD for outfits + composition invariant | — | ☐ |
| Empty vs no-results states distinct | — | ☐ |
| Fully usable offline; nothing transmitted | — | ☐ |
| Apple: cross-device sync of items + images | — | ☐ |
| NFR-6 responsive (resize sweep) | — | ☐ |
| NFR-4 accessibility baseline | — | ☐ |
| NFR-3 performance (scroll/filter) | — | ☐ |

## Out of scope

New features, doc restructuring, anything beyond making the v1 baseline verifiably complete. If §10 reveals a genuine spec gap, update the functional spec first (instructions.md §5) and cite it.
