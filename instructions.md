# Agent instructions — iWardrobe

Read this file before doing any work in this repository. It keeps every agent
iteration aligned on what the project is, which document governs which decision,
and the rules that must not be violated.

## 1. What this project is

**iWardrobe** is a personal wardrobe management app in Flutter (v1 / MVP). The
user catalogs clothing items (**wearables**), composes them into named
**outfits**, marks **favorites**, and views them on a Home dashboard. On Apple
platforms (iOS, iPadOS, macOS) the wardrobe syncs to the user's own iCloud;
Android is local-only. Offline-first, account-free, no server, no telemetry.

- Project recap: [README.md](README.md)
- Complete documentation set (the reference): [`Docs/`](Docs/) — start with
  [Docs/README.md](Docs/README.md), then [Docs/functional-specification.md](Docs/functional-specification.md).

**Current phase:** design/documentation only. The application source
(`lib/`, `test/`, platform folders) does not exist yet. Do not scaffold or
implement code unless the user explicitly starts the implementation phase.

## 2. Source of truth & precedence

| Question | Answered by |
|---|---|
| *What* the app does (behavior, requirements) | [Docs/functional-specification.md](Docs/functional-specification.md) — **single source of truth for behavior** |
| *How* it is built (layers, stack, structure) | [Docs/architecture.md](Docs/architecture.md) |
| *What* is stored (entities, schema, JSON, images) | [Docs/data-model-and-database.md](Docs/data-model-and-database.md) |
| *When/how* data is replicated (sync protocol) | [Docs/icloud-sync.md](Docs/icloud-sync.md) |
| *How* layout adapts to window width | [Docs/responsive-design.md](Docs/responsive-design.md) |
| *How* it looks (theme, components, copy) | [Docs/ui-design.md](Docs/ui-design.md) |
| Project summary for outsiders | [README.md](README.md) — a **recap**, never a source of truth; if it ever disagrees with `Docs/`, the docs win |

When a decision is not covered, prefer extending the documentation over
inventing requirements: raise the question with the user, or record the
proposal as a clearly-marked addition to the relevant document.

## 3. Stable identifiers

These identifiers are **stable** and referenced across all documents and
(future) tests. Never renumber, rename, or reuse them:

- `F-01 … F-11` — features (functional spec §4)
- `FR-x.y` — functional requirements (functional spec §5); `(Optional, P2)` marks stretch items
- `A-1 … A-11` — specification assumptions (functional spec §5.12)
- `NFR-1 … NFR-6` — non-functional requirements (functional spec §8)
- `M1 … M15`, `T1 … T4` — merge test cases / sync triggers (icloud-sync.md §13 / §8)
- Breakpoints: `compact` (< 600) · `medium` (600–1023) · `expanded` (≥ 1024) (responsive-design.md §3)

New requirements get the next free number in their section. Deleting a
requirement means deprecating it (mark it `DELETED` with a note), not reusing
its id.

## 4. Documentation conventions

All documents in `Docs/` follow the same format — keep it when editing:

1. **Title** `# iWardrobe — <topic>`.
2. **Header table** with: `Version` (`1.0 (v1 / MVP)`), `Date`, `Status`
   (e.g. `Reference for implementation`), and a `Companion documents` row that
   links **every** sibling document by relative link. When you add or remove a
   document, update the companion rows in **all** documents and the index in
   [Docs/README.md](Docs/README.md).
3. **Cross-references** are always relative markdown links to sibling docs,
   citing the stable ids (`FR-x.y`, `A-x`, `NFR-x`) next to the claim.
4. **Wording**: normative behavior uses *shall*; stretch behavior is marked
   `(Optional, P2)`.
5. **Structure**: structured facts live in tables; code (schema, wire format,
   Dart) lives in fenced code blocks labeled with the planned file path
   (e.g. `// data/models/wardrobe_tables.dart`).
6. **Version & date**: bump the `Version` only on meaningful content changes;
   update `Date` whenever the document is modified (use the date the change is
   made).
7. **Scope**: documents define the v1 baseline only. Optional/P2 items
   (e.g. `FR-1.8`, `FR-9.6`) stay explicitly out of the baseline.

## 5. Change protocol (keeping the doc set coherent)

- **Behavior first.** Any change to what the app does is proposed in the
  functional specification (new/changed `FR-x.y`, and `A-x` if a new
  assumption is made), then propagated to the companion documents that touch
  it (architecture, data model, sync, responsive, UI) and to the root
  [README.md](README.md) recap.
- **One document owns a topic** (see the precedence table above). Do not
  redefine a topic elsewhere; link to its owning document instead.
- **Payload vs protocol split:** the JSON wire format is owned by
  [data-model-and-database.md](Docs/data-model-and-database.md);
  [icloud-sync.md](Docs/icloud-sync.md) defines only when/how it is transferred.
  Respect that split when editing either.
- **User-facing copy is frozen** in [ui-design.md §10](Docs/ui-design.md).
  Never paraphrase those strings in other documents or in code.

## 6. Scope discipline

Explicitly **out of scope for v1** (functional spec §9) — do not add:

- iCloud sync on Android (Android is local-only by design, `FR-10.6`)
- Sharing / social features, third-party logins, analytics & telemetry
- Multi-user / household sharing, price & stock tracking
- Anything optional marked `(Optional, P2)` unless the user promotes it to baseline

Do not introduce new features, new entities, or new dependencies in the
documentation without a matching specification change.

## 7. Implementation-phase rules (binding once coding starts)

The following are hard constraints distilled from [architecture.md](Docs/architecture.md),
[data-model-and-database.md](Docs/data-model-and-database.md), and
[icloud-sync.md](Docs/icloud-sync.md). They are not suggestions:

**Layering (MVVM + Repository)**

- Views hold no business logic and no data access; they talk only to their
  ViewModel (immutable state snapshots + command methods).
- Repositories (`WearableRepository`, `OutfitRepository`, `SyncRepository`)
  are the single source of truth and the only layer touching `drift`, the file
  system, or sync. Services are stateless wrappers that know nothing about the
  domain.
- Data flows one way: `Repository → stream → ViewModel → View`; commands flow
  back. No `setState` for domain state in Views.
- DI is the `provider` tree only (order: services → repositories →
  ViewModels); app-scope vs route-scope per the architecture doc. No service
  locator, no manual repository construction.
- There is **no use-case layer** in v1 (`lib/domain/use_cases` is intentionally
  absent).

**Platform & dependencies**

- The only platform branch in the whole codebase is the `SyncService`
  registration (`IcloudSyncService` on iOS/macOS, `NoopSyncService` on
  Android, selected by `defaultTargetOs`). No other Android/iOS forks.
- No new dependency without adding a row to the Tech stack table in
  [architecture.md](Docs/architecture.md).
- Domain models are plain immutable Dart classes with hand-written
  `fromJson`/`toJson` (pattern-matched, `FormatException` on malformed
  input, unknown fields ignored). No `freezed` / `built_value`.
- Codegen is `drift` only, via `build_runner`; generated `*.g.dart` files are
  never hand-edited and not committed.

**Behavior invariants**

- Cascade rules `FR-8.8 – FR-8.10` (deleting a wearable removes it from every
  outfit; an outfit left empty is deleted; deleting an outfit never deletes
  its wearables) — enforced in a single repository transaction.
- Outfits always keep an image (`A-7`); wearables may not have one
  (placeholder per [ui-design.md](Docs/ui-design.md)).
- Filters: AND across dimensions, OR within the tag dimension (`A-2`);
  newest-first ordering everywhere (`A-3`).
- Typed `WardrobeException` hierarchy for errors; one snackbar per failed
  action; never a blocking dialog; no stack traces or internal paths shown to
  the user. No logging beyond `debugPrint` gated on `kDebugMode`. Nothing
  leaves the device (NFR-2).

**Responsive & visual**

- Layout switches on `LayoutBuilder` `constraints.maxWidth` (the three
  breakpoints above) — **never** on device type, hardware, or
  `MediaQuery.orientationOf`. No orientation lock.
- Visual language, tokens, component set, and copy follow
  [ui-design.md](Docs/ui-design.md) exactly, including light + dark palettes,
  44 × 44 targets, and the frozen empty/error copy.

**Testing & code quality**

- Hand-written fakes (no generated mocks); repositories tested with an
  in-memory `drift` database (`NativeDatabase.memory()`) and a temp image dir;
  merge engine tested against cases `M1 … M15`.
- The acceptance criteria in [functional-specification.md §10](Docs/functional-specification.md)
  are the release checklist: every unchecked box must map to at least one
  automated test before a build is accepted.
- Commit-time gate, in order:

  ```bash
  dart run build_runner build --delete-conflicting-outputs
  dart format lib test
  dart analyze          # zero issues
  flutter test
  ```

## 8. Skills

This repository pins a catalog of Dart/Flutter skills in [`.agents/skills/`](.agents/skills)
(source `dart-lang/skills`, locked by [skills-lock.json](skills-lock.json)).
When a task clearly matches a skill (e.g. writing tests → `dart-add-unit-test`,
static analysis → `dart-run-static-analysis`, responsive layouts →
`flutter-build-responsive-layout`, JSON serialization →
`flutter-implement-json-serialization`), load and follow that skill's
instructions before acting. The skills support the docs above; they never
override the documented invariants in §7.

## 9. Git workflow

- Work on `master` unless the user says otherwise.
- Commit locally with a concise subject line plus a body that explains the
  *why*. Keep one logical change per commit.
- **Do not push to the remote unless the user explicitly asks.**
- Keep the repository clean: no stray artifacts, no committed generated
  `*.g.dart` files, no lockfile churn unrelated to the change.

## 10. Quick do/don't

| Do | Don't |
|---|---|
| Cite stable ids (`FR-x.y`, `A-x`, `NFR-x`) when discussing or changing behavior | Renumber or rename existing identifiers |
| Keep all docs mutually consistent (companion rows, index, relative links) | Let `README.md` drift away from `Docs/` |
| Propose behavior changes in the functional spec first | Re-define a topic outside its owning document |
| Read the owning doc before implementing or editing a topic | Invent requirements not in the doc set |
| Use relative links between `Docs/` files | Use absolute paths or remote URLs for cross-doc links |
| Commit locally, push only on request | Push, rebase, or force without explicit instruction |
| Use the frozen UI copy verbatim | Paraphrase user-facing strings |
