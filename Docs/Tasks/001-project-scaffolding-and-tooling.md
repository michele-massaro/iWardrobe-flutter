# Task 001 — Project scaffolding & tooling

| | |
|---|---|
| **Phase** | 1 — Foundation |
| **Depends on** | — |
| **Primary references** | [Architecture](../architecture.md) §Tech stack, §Code quality · [Data model](../data-model-and-database.md) §Local database |

## Objective

Turn this documentation-only repository into a buildable Flutter project targeting **iOS, iPadOS, macOS, and Android** with the exact v1 toolchain, so every later task builds on a working foundation. The end state is an empty but honest shell: the correct dependencies, analysis rules, codegen wiring, platform folders, and a trivial entry point.

## What the agent must deliver

### 1. Project generation

- Run `flutter create --org com.example --project-name iwardrobe --platforms ios,macos,android .` inside the existing repository (do **not** move `Docs/`, `README.md`, or `instructions.md`; `flutter create` on an existing directory must preserve them).
  - `com.example` keeps consistency with the documented bundle/container examples (`com.example.iwardrobe`, `iCloud.TEAM123.com.example.iwardrobe`). Changing the org later is a product decision, not a task detail.
- Replace the default `lib/main.dart` with a minimal placeholder: a `MaterialApp` titled `iWardrobe` showing a `Scaffold` with the text `iWardrobe (scaffold)`. The real entry point (bootstrap + DI + router) arrives in task 013.

### 2. `pubspec.yaml` — dependencies are exactly the tech-stack table

Runtime dependencies (no more, no less — per `instructions.md` §7):

| Package | Notes |
|---|---|
| `provider` | DI + `ChangeNotifier` ViewModels |
| `go_router` | Routing, tab shell, onboarding gate |
| `drift` | Local SQLite |
| `path_provider` | Documents directory |
| `image_picker` | Camera / album |
| `flutter_image_compress` | Resize + JPEG at import |
| `shared_preferences` | Onboarding flag, last-sync timestamp |
| `icloud_storage_sync` | **Pin exactly `0.0.5`** — re-verify the constraint against pub.dev at implementation time (the package README may advertise a different version; the docs say the published release is 0.0.5) |
| `uuid` | Client-side UUID v4 |

Dev dependencies: `flutter_lints`, `build_runner`, `drift_dev`, `integration_test` (from the Flutter SDK).

### 3. Analysis & formatting

- `analysis_options.yaml` includes `package:flutter_lints/flutter.yaml`; **no additional rules in v1** (per Architecture §Code quality).
- Every file passes `dart format` (this becomes part of the commit gate, not a one-off).

### 4. Codegen & generated files

- `dart run build_runner build --delete-conflicting-outputs` must succeed on the scaffold (no drift tables yet — the command must simply run clean).
- Add `*.g.dart` (drift-generated table accessors) to `.gitignore` — generated files are **never committed** and are regenerated locally and in CI.

### 5. Commit gate script

- Add `scripts/commit-gate.sh` running, in order: `build_runner build --delete-conflicting-outputs`, `dart format lib test`, `dart analyze`, `flutter test` — the exact checklist from Architecture §Code quality. Make it executable; exit non-zero on the first failure.
- Optional (nice-to-have, not required for DoD): a `.github/workflows/ci.yml` running the same gate on push/PR.

## Definition of done

**Build** (standard gate, §README of this folder):

- [ ] `flutter analyze` — zero issues.
- [ ] `dart format --set-exit-if-changed lib test` — clean.
- [ ] `flutter test` — passes (include at least one trivial smoke test, e.g. the placeholder app inflates).
- [ ] `flutter build apk` succeeds.
- [ ] `flutter build macos` succeeds.
- [ ] `flutter build ios --no-codesign` succeeds.
- [ ] `dart run build_runner build --delete-conflicting-outputs` succeeds.

**Content constraints**

- [ ] `pubspec.yaml` contains exactly the dependency set above (a new dependency without a tech-stack row is a violation of `instructions.md` §7).
- [ ] `icloud_storage_sync` is pinned to `0.0.5` (or the re-verified current release, documented in the commit message).
- [ ] `*.g.dart` is gitignored; `git status` shows no generated files.
- [ ] `scripts/commit-gate.sh` exists, is executable, and runs clean end-to-end.
- [ ] `Docs/`, `README.md`, `instructions.md` are untouched by the scaffold.

**Out of scope for this task:** any `lib/` code beyond the placeholder, any platform configuration beyond what `flutter create` generates, CI beyond the optional workflow.
