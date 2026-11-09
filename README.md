# iWardrobe

**iWardrobe** is a personal wardrobe management app built with Flutter. It catalogs the user's clothing items (called **wearables**), composes them into named **outfits**, highlights favorites on a Home dashboard, and — on Apple platforms — keeps the entire wardrobe, images included, in sync across iPhone, iPad, and Mac through iCloud.

The app is **offline-first and account-free**: everything lives inside the app, with no remote APIs, no server, and no telemetry.

> **Status:** This repository currently contains the complete **v1 (MVP) documentation set** in [`Docs/`](Docs/), plus the implementation plan in [`Docs/Tasks/`](Docs/Tasks/) — 30 user-story-sized tasks, each with an objective, full specification, and definition of done. The implementation is a future task; for now the project is in the design/documentation phase. The docs are the reference for design, implementation, and acceptance testing.

---

## What the app does

A user catalogs their clothing — each item a **wearable** — with a photo and details (type, color, size, brand, material, tags), composes those wearables into named **outfits**, and marks the items they love as **favorites**. A Home dashboard surfaces the latest outfits, favorite outfits, and favorite clothes, so the app opens directly on what the user cares about.

| Feature | Description |
|---|---|
| **Onboarding** | A three-page first-launch introduction (catalog → compose → sync), shown once. |
| **Three-tab navigation** | Home, Outfits, Wearables — each tab preserves its state (scroll, filters, content) across switches. |
| **Home dashboard** | *Latest outfits* carousel, *Favorite outfits*, and *Favorite clothes* sections, with friendly empty states. |
| **Outfits** | List, detail, add, edit, delete; filterable by name, color, and tag (color/tag derived from the composing wearables). |
| **Wearables** | List, detail, add, edit, delete; filterable by name, type, color, and tag. |
| **Favorites** | A persistent "heart" flag on any outfit or wearable, surfaced immediately on Home. |
| **iCloud sync** | Bidirectional sync of database records and images on iOS, iPadOS, and macOS (last-writer-wins conflicts). Android is local-only. |
| **Local storage** | An internal SQLite database (`drift`) for records and local files for images. No server, no account. |

## Design principles

- **Private by design.** No account, no server, no remote API. The wardrobe lives on the device and, on Apple platforms, only in the user's own iCloud.
- **Useful every day.** Fast discovery through name, type, color, and tag filters; one-tap favorites keep preferred looks reachable in two taps.
- **Cozy and personal.** A warm, approachable visual language (terracotta & cream palette, rounded type, soft cards) — a closet, not a productivity tool.
- **Responsive everywhere.** Layout adapts to *window width*, not device type, across smartphone, tablet, and Mac (including resizable Mac windows and iPad multitasking).

## Target platforms

| Platform | Form factor | Role | iCloud sync |
|---|---|---|---|
| iOS (iPhone) | Smartphone | **Primary target** | Yes |
| iPadOS (iPad) | Tablet | First-class | Yes |
| macOS (Mac) | Desktop | First-class | Yes |
| Android | Smartphone / tablet | Supported | **No — local data only** |

## Tech stack (planned)

| Technology / package | Purpose |
|---|---|
| Flutter + Dart | Single codebase for iOS, iPadOS, macOS, Android |
| `provider` | Dependency injection + `ChangeNotifier` ViewModels (MVVM + Repository) |
| `go_router` | Declarative routing, three-tab shell, onboarding gate |
| `drift` / `drift_dev` | Local SQLite database (with `build_runner` codegen) |
| `image_picker` + `flutter_image_compress` | Photo capture/selection; resize + JPEG compression at import |
| `shared_preferences` | Onboarding flag; last successful sync timestamp |
| `icloud_storage_sync` (0.0.5) | iCloud sync on Apple platforms only |
| `uuid` | Client-side UUID v4 ids (offline-first, stable across devices) |
| `path_provider`, `flutter_lints` | App documents directory; static analysis rule set |

Domain models are plain immutable Dart classes with hand-written `fromJson`/`toJson` — no `freezed`/`built_value`, keeping codegen limited to `drift`.

## Documentation

The full documentation set lives in [`Docs/`](Docs/). Each document is versioned for v1 (MVP) and cross-references the others by relative link.

| # | Document | Description |
|---|---|---|
| 1 | [Functional specification](Docs/functional-specification.md) | What the app does: platforms, glossary, feature inventory (F-01 …), testable requirements (FR-x.y), user stories, key flows, non-functional requirements, assumptions, and acceptance criteria. |
| 2 | [Architecture](Docs/architecture.md) | How the app is built: MVVM + Repository layering (UI / Logic / Data), `provider` state management, `go_router` navigation, project structure, and code-quality conventions. |
| 3 | [Data model & local database](Docs/data-model-and-database.md) | The entities (outfit, wearable, color, tag), their fields and relationships, the `drift`/SQLite schema, the JSON wire format, and local image storage. |
| 4 | [iCloud sync](Docs/icloud-sync.md) | Bidirectional sync protocol with `icloud_storage_sync` (Apple only): container layout, push/pull pipeline, conflict resolution, tombstones, offline behavior, and testing. |
| 5 | [Responsive design](Docs/responsive-design.md) | Breakpoints (compact / medium / expanded) and adaptive layout rules based on window width, not device type. |
| 6 | [UI & design language](Docs/ui-design.md) | The cozy visual language: palette, typography, core components, iconography, motion, dark mode, accessibility, and exact empty/error state copy. |
| 7 | [Task index](Docs/Tasks/README.md) | The implementation plan: 30 user-story-sized tasks with objective, full spec, and definition of done (build + test constraints). |

**Suggested reading order:** start with the [Functional specification](Docs/functional-specification.md) (it defines the product and the stable identifiers every other document references), then [Architecture](Docs/architecture.md), [Data model & local database](Docs/data-model-and-database.md), [iCloud sync](Docs/icloud-sync.md), and finally [Responsive design](Docs/responsive-design.md) and [UI & design language](Docs/ui-design.md). The [documentation index](Docs/README.md) has the same map.

## Repository layout

```text
iWardrobe-flutter/
├── README.md        # this file — short project recap
├── instructions.md  # agent alignment rules for all iterations
├── Docs/            # complete v1 documentation set
│   ├── README.md                    # documentation index
│   ├── functional-specification.md
│   ├── architecture.md
│   ├── data-model-and-database.md
│   ├── icloud-sync.md
│   ├── responsive-design.md
│   ├── ui-design.md
│   └── Tasks/                       # implementation plan (index + 30 task files)
└── .agents/         # agent/tooling configuration
```

The application source (`lib/`, `test/`, platform folders) is not present yet; it will follow the project structure defined in [Architecture](Docs/architecture.md).

## Out of scope for v1

Explicitly excluded from the MVP:

- iCloud sync on Android (Apple-only service)
- Sharing / social features, third-party logins, analytics & telemetry
- Multi-user / household sharing
- Price and stock tracking

## Acceptance

A v1 build is accepted when every checkbox in [Functional specification §10](Docs/functional-specification.md) holds — including onboarding shown once, three-tab state preservation, the three Home sections, working filters (AND across dimensions, OR within tags), immediate-and-persistent favorite toggling, full CRUD with cascade rules, full offline usability, and (on Apple platforms) cross-device sync.
