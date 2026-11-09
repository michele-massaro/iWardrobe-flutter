# iWardrobe — Documentation

iWardrobe is a personal wardrobe management app built with Flutter. It catalogs the user's individual clothing items (called **wearables**), composes them into named **outfits**, highlights favorites on a Home dashboard, and — on Apple platforms — keeps the entire wardrobe, images included, in sync across iPhone, iPad, and Mac through iCloud. The app is offline-first and account-free: everything is handled inside the app, with no remote APIs, no server, and no telemetry.

This `Docs/` folder is the complete documentation set for the iWardrobe v1 (MVP) build. It defines what the app does, how it is built, and how it looks and adapts to each form factor, and it is the reference for design, implementation, and acceptance testing. The set begins with this index and the [Functional specification](functional-specification.md); the remaining documents belong to the same set and cross-reference each other by relative link.

## Documentation index

| # | Document | Description |
|---|---|---|
| 1 | [Functional specification](functional-specification.md) | What the app does: platforms, glossary, feature inventory (F-01 …), testable requirements (FR-x.y), user stories, key flows, non-functional requirements, and acceptance criteria. |
| 2 | [Architecture](architecture.md) | How the app is built: MVVM + Repository layering (UI / Logic / Data), `provider` state management with `ChangeNotifier` ViewModels, `go_router` tab navigation, and the project structure. |
| 3 | [Data model & local database](data-model-and-database.md) | The wardrobe entities (outfit, wearable, color, tag), their fields and relationships, the `drift` (SQLite) schema, and how images are stored as local files. |
| 4 | [iCloud sync](icloud-sync.md) | Bidirectional sync of database records and images with `icloud_storage_sync`, Apple platforms only, including conflict handling and offline behavior. |
| 5 | [Responsive design](responsive-design.md) | Breakpoints and adaptive layout rules so the app works well on smartphone, tablet, and Mac, based on window width rather than device type. |
| 6 | [UI & design language](ui-design.md) | The cozy visual language: palette, typography, core components (cards, filter chips, favorite hearts), iconography, and empty states. |
| 7 | [Task index](Tasks/README.md) | The implementation plan: 30 user-story-sized tasks, each with its objective, full specification, and definition of done (build + test constraints). |

## Suggested reading order

Start with the [Functional specification](functional-specification.md), because it defines the product and the stable identifiers (F-xx features, FR-x.y requirements) that every other document references. Next, read [Architecture](architecture.md) to understand the code-level structure, then [Data model & local database](data-model-and-database.md) to see what is stored and where, and then [iCloud sync](icloud-sync.md) to understand how that local data is replicated across Apple devices. Finish with [Responsive design](responsive-design.md) and [UI & design language](ui-design.md), which define how the app adapts to screen size and how it looks and feels. The implementation is then planned in the [Task index](Tasks/README.md).

> **Note.** The repository root `README.md` is the short project recap (overview, status, quick links); this `Docs/` folder holds the complete documentation set.
