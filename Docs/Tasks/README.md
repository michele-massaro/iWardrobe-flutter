# iWardrobe — Implementation tasks

| | |
|---|---|
| **Version** | 1.0 (v1 / MVP) |
| **Date** | 9 November 2026 |
| **Status** | Implementation plan |
| **Companion documents** | [Documentation index](../README.md) · [Functional specification](../functional-specification.md) · [Architecture](../architecture.md) · [Data model & local database](../data-model-and-database.md) · [iCloud sync](../icloud-sync.md) · [Responsive design](../responsive-design.md) · [UI & design language](../ui-design.md) |

This folder decomposes the iWardrobe v1 implementation into **30 tasks**. Each task file is self-contained: it names the objective, carries every specification an agent needs (requirements with stable ids, code locations, key snippets, frozen copy), and ends with a **Definition of done** containing the build and test constraints. Tasks are user-story sized — bigger than a function, smaller than an epic.

## How to use this plan

1. Work in **numeric order**. A task's `Depends on` lists what must be done first; within a phase, tasks without mutual dependencies can be done in parallel (for example 018/019, 020/021, 022/023).
2. Before starting a task, read the task file **and** the cited sections of the companion documents. The companion documents remain the source of truth; if a task and a doc disagree, the doc wins and the task must be corrected.
3. A task is complete only when its **entire** Definition of done holds (build gate + required tests + functional acceptance). Then commit (local; no push unless asked) and update the `Status` column below with the commit ref.
4. Do not add scope: anything not in a task belongs to another task or to the out-of-scope list in [functional specification §9](../functional-specification.md).

## Standard build gate

Unless a task says otherwise, its Definition of done always includes:

```bash
dart run build_runner build --delete-conflicting-outputs   # when codegen is involved
dart format lib test                                       # clean on re-run
dart analyze                                               # zero issues
flutter test                                               # all tests pass
flutter build apk && flutter build macos && flutter build ios --no-codesign
```

## Task index

| # | Task | Phase | Depends on | Status |
|---|---|---|---|---|
| 001 | [Project scaffolding & tooling](001-project-scaffolding-and-tooling.md) | 1 — Foundation | — | ☑ a463128 |
| 002 | [Domain models, enums, filters, exceptions](002-domain-models-and-json.md) | 1 — Foundation | — | ☐ |
| 003 | [Local database (drift) & DatabaseService](003-local-database-drift.md) | 1 — Foundation | 001, 002 | ☐ |
| 004 | [ImageFileService & image import pipeline](004-image-file-service.md) | 2 — Data layer | 002, 003 | ☐ |
| 005 | [PreferencesService & app bootstrap](005-preferences-and-bootstrap.md) | 2 — Data layer | 001 | ☐ |
| 006 | [SyncService abstraction & iCloud setup](006-sync-service-abstraction.md) | 2 — Data layer | 001 | ☐ |
| 007 | [Sync events, snapshot envelope & merge engine](007-sync-events-envelope-merge.md) | 2 — Data layer | 002 | ☐ |
| 008 | [WearableRepository](008-wearable-repository.md) | 2 — Data layer | 003, 004, 007 | ☐ |
| 009 | [OutfitRepository](009-outfit-repository.md) | 2 — Data layer | 003, 004, 007 | ☐ |
| 010 | [SyncRepository pipeline](010-sync-pipeline.md) | 2 — Data layer | 005, 006, 007, 008, 009 | ☐ |
| 011 | [AppTheme, typography & design tokens](011-theme-and-tokens.md) | 3 — Shell & UI core | 001 | ☐ |
| 012 | [Core widgets: image, placeholder, card, heart](012-core-widgets.md) | 3 — Shell & UI core | 011 | ☐ |
| 013 | [App entry, DI tree, router & adaptive shell](013-app-entry-router-shell.md) | 3 — Shell & UI core | 005, 010, 011, 012 | ☐ |
| 014 | [FilterBar, EmptyState & NoResultsState](014-filter-and-state-widgets.md) | 4 — Features | 011 | ☐ |
| 015 | [Shared form components](015-form-components.md) | 4 — Features | 011, 012 | ☐ |
| 016 | [Onboarding flow](016-onboarding.md) | 4 — Features | 005, 013 | ☐ |
| 017 | [Home dashboard](017-home-dashboard.md) | 4 — Features | 008, 009, 012, 013 | ☐ |
| 018 | [Outfits list](018-outfit-list.md) | 4 — Features | 009, 012, 013, 014 | ☐ |
| 019 | [Wearables list](019-wearable-list.md) | 4 — Features | 008, 012, 013, 014 | ☐ |
| 020 | [Outfit detail](020-outfit-detail.md) | 4 — Features | 009, 012, 013 | ☐ |
| 021 | [Wearable detail](021-wearable-detail.md) | 4 — Features | 008, 012, 013 | ☐ |
| 022 | [Wearable form (create & edit)](022-wearable-form.md) | 4 — Features | 008, 013, 015 | ☐ |
| 023 | [Outfit form (create & edit)](023-outfit-form.md) | 4 — Features | 009, 013, 015 | ☐ |
| 024 | [Delete confirmation & cascade UX](024-delete-confirmation-cascade-ux.md) | 4 — Features | 020, 021 | ☐ |
| 025 | [Sync status indicator](025-sync-status-indicator.md) | 5 — Sync completion | 013, 025's data from 010 | ☐ |
| 026 | [Two-device sync verification](026-two-device-sync-verification.md) | 5 — Sync completion | 025, 026 device builds | ☐ |
| 027 | [Responsive layout pass](027-responsive-layout-pass.md) | 6 — Quality & acceptance | 013, 017–024 | ☐ |
| 028 | [Accessibility & motion audit](028-accessibility-motion-audit.md) | 6 — Quality & acceptance | 011–024 | ☐ |
| 029 | [Performance pass](029-performance-pass.md) | 6 — Quality & acceptance | 017–024 | ☐ |
| 030 | [Integration test & final acceptance](030-integration-test-final-acceptance.md) | 6 — Quality & acceptance | all | ☐ |

## Phase overview

| Phase | Tasks | Outcome |
|---|---|---|
| 1 — Foundation | 001–003 | Buildable project, domain models, local database |
| 2 — Data layer | 004–010 | Services, repositories, sync engine & pipeline (fully unit-tested) |
| 3 — Shell & UI core | 011–013 | Theme, shared widgets, entry point, routing, adaptive shell |
| 4 — Features | 014–024 | Onboarding, Home, both lists, both details, both forms, delete UX |
| 5 — Sync completion | 025–026 | Status indicator, verified cross-device sync |
| 6 — Quality & acceptance | 027–030 | Responsive/a11y/performance passes, integration test, acceptance checklist |

Notes:

- The acceptance criteria in [functional specification §10](../functional-specification.md) are distributed across the tasks; task 030 verifies that every box is covered by an automated test or a recorded manual script.
- `Docs/` stays the source of truth during implementation: if an implementation detail must deviate from a document, update the document first and keep its stable identifiers (see `instructions.md`).
- Task files 026 and 030 contain verification log sections that the implementing agent fills in as evidence.
