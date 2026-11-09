# iWardrobe — Architecture

| | |
|---|---|
| **Version** | 1.0 (v1 / MVP) |
| **Date** | 8 November 2026 |
| **Status** | Reference for implementation |
| **Companion documents** | [Documentation index](README.md) · [Functional specification](functional-specification.md) · [Data model & local database](data-model-and-database.md) · [iCloud sync](icloud-sync.md) · [Responsive design](responsive-design.md) · [UI & design language](ui-design.md) |

## Purpose & scope

This document defines **how** iWardrobe v1 is built: the technology stack, the architectural pattern, the project structure, state management, dependency injection, navigation, the cross-platform strategy, and the conventions for error handling, testing, and code quality.

The [functional specification](functional-specification.md) is the single source of truth for **what** the app does; its stable identifiers (F-xx features, FR-x.y requirements, A-x assumptions, NFR-x) are referenced throughout this document. This document deliberately leaves the following topics to their companion documents:

- [Data model & local database](data-model-and-database.md) — the entities, their fields, the `drift`/SQLite schema, image files, and the public repository API.
- [iCloud sync](icloud-sync.md) — the Apple-platform replication protocol built on top of the services and repositories defined here.
- [Responsive design](responsive-design.md) — how the routes and shell chrome defined here adapt to window width.
- [UI & design language](ui-design.md) — the theme, components, and empty states consumed by the shared widgets.

Scope: a single Flutter codebase targeting iOS (primary), iPadOS, macOS, and Android (local-only, no sync — FR-10.6). The document defines the v1 baseline only; anything optional in the specification (for example FR-1.8, FR-9.6) is excluded.

## Tech stack

| Technology / package | Purpose | Notes |
|---|---|---|
| Flutter + Dart | Single codebase for iOS, iPadOS, macOS, Android | iOS is the primary design target (spec §2) |
| `provider` | Dependency injection and `ChangeNotifier` ViewModels | The provider tree is the only DI mechanism; no service locator |
| `go_router` | Declarative routing, three-tab shell, onboarding gate | `StatefulShellRoute.indexedStack` for FR-2.1 – FR-2.5 |
| `drift` (with `drift_dev`) | Local SQLite database | FR-11.1; schema in [Data model & local database](data-model-and-database.md) |
| `build_runner` | Codegen for `drift` table accessors | `dart run build_runner build --delete-conflicting-outputs` |
| `path_provider` | App documents directory for the database and image files | FR-11.1 |
| `image_picker` | Camera / photo album selection for outfit and wearable images | FR-8.2, FR-8.3 |
| `flutter_image_compress` | Resize + JPEG compression at import time | Keeps files small for storage and iCloud sync payloads (FR-10.1) |
| `shared_preferences` | Onboarding-completed flag; last successful sync timestamp | FR-1.6, FR-1.7, FR-10.5 |
| `icloud_storage_sync` | iCloud sync on Apple platforms | Current published version is **0.0.5**; the package supports **iOS + macOS only**, which matches the Apple-only sync scope (FR-10.5, FR-10.6) |
| `uuid` | Client-side UUID v4 generation for all entity ids | Offline-first creation; stable ids across devices for last-writer-wins (A-10) |
| `flutter_lints` | Static analysis rule set | Enforced at commit time and in CI |

No other third-party state-management, networking, or database packages are used. There is no HTTP client and no remote API of any kind (NFR-2). Domain models are plain immutable Dart classes (`final` fields, const constructors, hand-written `copyWith`) — no `freezed`/`built_value` codegen in v1, which keeps the codegen surface limited to `drift`.

## Architectural pattern

iWardrobe follows **MVVM + Repository** with strict separation of concerns across three layers: **UI**, **Data**, and a thin **Domain** layer holding the shared models.

### Layers

**UI layer (`lib/ui`).**
- **Views** are lean Flutter widgets. They hold no business logic and no data access; their logic is restricted to UI-specific concerns (layout, animation, local focus state). A View's only conversation partner is its ViewModel: it reads immutable state snapshots and invokes command methods.
- **ViewModels** extend `ChangeNotifier`. They own the screen's state, subscribe to repository streams, and expose **immutable state snapshots** (private mutable storage, public read-only getters) plus **command methods** (`save`, `toggleFavorite`, `setFilter`, …). Repositories are injected via the constructor.

**Data layer (`lib/data`).**
- **Repositories** are the **single source of truth** for each aggregate (wearables + tags, outfits + composition, sync). They consume one or more services, hide them from the rest of the app, and expose clean immutable domain models as streams or one-shot futures. All query, transaction, cascade (FR-8.8 – FR-8.10), and sync-orchestration logic lives here.
- **Services** are stateless wrappers around a single external dependency: `DatabaseService` (drift), `ImageFileService` (file system), `IcloudSyncService` / `NoopSyncService` (the `icloud_storage_sync` plugin), and `PreferencesService` (`shared_preferences`). Services return raw rows or raw file paths and know nothing about the domain.

**Domain layer (`lib/domain`).**
Immutable models (`Wearable`, `Outfit`, `Tag`), enums (`WearableType`, `Season`, `Color`), filter state, and typed exceptions, shared by every layer. **The optional use-case layer is *not* introduced in v1**: the v1 business rules (filter combination per A-2, cascade per FR-8.8 – FR-8.10, form validation per FR-8.4) are simple CRUD plus transformation and are kept in the ViewModels and Repositories where they belong. `lib/domain/use_cases` is intentionally absent from the project structure; it may be introduced later if logic must be reused across ViewModels without modification.

### Rules

1. Views hold no business logic and no data access.
2. ViewModels expose immutable state snapshots and command methods, and are the only thing Views talk to.
3. Repositories are the single source of truth and hide the services they consume.
4. Services are stateless wrappers around drift, the file system, and the iCloud plugin; they know nothing about the domain.
5. Data flows one way — Repository → stream → ViewModel → View; commands flow the other way — View → ViewModel → Repository.

### Layer diagram

```text
┌─────────────────────────────────────────────────────────────────────────┐
│ UI LAYER (lib/ui)                                                       │
│                                                                         │
│  OnboardingView · HomeView · OutfitListView · OutfitDetailView ·        │
│  OutfitFormView · WearableListView · WearableDetailView ·               │
│  WearableFormView                                                       │
│      ▲ reads immutable state   │ invokes command methods                │
│  OnboardingViewModel · HomeViewModel · OutfitListViewModel ·            │
│  OutfitDetailViewModel · OutfitFormViewModel ·                          │
│  WearableListViewModel · WearableDetailViewModel ·                      │
│  WearableFormViewModel · AppViewModel              (ChangeNotifier)     │
├─────────────────────────────────────────────────────────────────────────┤
│ DATA LAYER (lib/data)                                                   │
│                                                                         │
│  WearableRepository · OutfitRepository · SyncRepository                 │
│      │ single source of truth; hides the services below                 │
│  DatabaseService (drift) · ImageFileService (files) ·                   │
│  IcloudSyncService / NoopSyncService (icloud_storage_sync) ·            │
│  PreferencesService (shared_preferences)                                │
├─────────────────────────────────────────────────────────────────────────┤
│ DOMAIN (lib/domain)                                                     │
│                                                                         │
│  Wearable · Outfit · Tag · WearableType · Season · Color ·              │
│  WearableFilter · OutfitFilter · typed exceptions                       │
│  (no use-case layer in v1)                                              │
└─────────────────────────────────────────────────────────────────────────┘
```

## Project structure

The layout follows the skill's hybrid approach — UI grouped by feature, Data/Domain grouped by type — adapted to iWardrobe's features:

```text
lib/
├── main.dart                          # entry point: load bootstrap state, build router, runApp
├── app.dart                           # MaterialApp.router: theme, router, MultiProvider root
├── app/
│   └── router.dart                    # GoRouter: onboarding gate, tab shell, detail & form routes
├── data/
│   ├── models/
│   │   └── wardrobe_tables.dart       # drift table definitions (+ generated .g.dart)
│   ├── services/
│   │   ├── database_service.dart      # drift database instance and raw row queries
│   │   ├── image_file_service.dart    # image file IO under <documents>/images
│   │   ├── icloud_sync_service.dart   # icloud_storage_sync wrapper (Apple platforms)
│   │   ├── noop_sync_service.dart     # same SyncService interface, no-op (Android)
│   │   └── preferences_service.dart   # shared_preferences: onboarding flag, last sync time
│   └── repositories/
│       ├── wearable_repository.dart   # wearables + tags: filtered streams, CRUD, cascade
│       ├── outfit_repository.dart     # outfits + composition: filtered streams, CRUD, cascade
│       └── sync_repository.dart       # Apple-only sync orchestration; no-op on Android
├── domain/
│   ├── models/
│   │   ├── wearable.dart              # immutable model with fromJson/toJson
│   │   ├── outfit.dart
│   │   ├── tag.dart
│   │   ├── drafts.dart                # WearableDraft / OutfitDraft (form → repository input)
│   │   └── enums.dart                 # WearableType (A-5), Season (A-9), Color
│   ├── filters.dart                   # WearableFilter / OutfitFilter (immutable, A-2)
│   └── exceptions.dart                # typed domain exceptions
└── ui/
    ├── core/
    │   ├── theme.dart                 # palette and typography per UI & design language
    │   ├── wardrobe_shell.dart        # StatefulNavigationShell + NavigationBar (3 tabs)
    │   └── widgets/
    │       ├── favorite_heart.dart    # heart toggle, ≥ 44×44 logical px target (NFR-4)
    │       ├── filter_bar.dart        # name search + single/multi-select chips (A-2)
    │       ├── empty_state.dart       # empty-wardrobe and no-results states
    │       └── wardrobe_image.dart    # lazy image + type-based placeholder fallback (A-7, NFR-3)
    └── features/
        ├── onboarding/
        │   ├── views/onboarding_view.dart
        │   └── view_models/onboarding_view_model.dart
        ├── home/
        │   ├── views/home_view.dart
        │   └── view_models/home_view_model.dart
        ├── outfits/
        │   ├── views/outfit_list_view.dart
        │   ├── views/outfit_detail_view.dart
        │   ├── views/outfit_form_view.dart
        │   └── view_models/outfit_list_view_model.dart
        │   ├── view_models/outfit_detail_view_model.dart
        │   └── view_models/outfit_form_view_model.dart
        └── wearables/
            ├── views/wearable_list_view.dart
            ├── views/wearable_detail_view.dart
            ├── views/wearable_form_view.dart
            └── view_models/wearable_list_view_model.dart
            ├── view_models/wearable_detail_view_model.dart
            └── view_models/wearable_form_view_model.dart
```

One line per directory:

- **`lib/data/models`** — `drift` table definitions and the generated row accessors (the only raw-database types in the codebase).
- **`lib/data/services`** — stateless wrappers: `DatabaseService` (drift), `ImageFileService` (file system), `IcloudSyncService`/`NoopSyncService` (the iCloud plugin), `PreferencesService` (`shared_preferences`).
- **`lib/data/repositories`** — the single source of truth: `WearableRepository`, `OutfitRepository`, and `SyncRepository`.
- **`lib/domain/models`** — immutable domain models (`Wearable`, `Outfit`, `Tag`), form drafts, and the enums `WearableType`, `Season`, `Color`; the only models the UI ever sees.
- **`lib/domain/filters.dart`, `lib/domain/exceptions.dart`** — shared immutable filter state (A-2) and the typed exception hierarchy.
- **`lib/domain/use_cases`** — intentionally *not* present in v1 (see Architectural pattern); logic stays in ViewModels and Repositories.
- **`lib/ui/core`** — theme, the tab shell, and shared widgets: `FavoriteHeart`, `FilterBar`, `EmptyState`, `WardrobeImage`.
- **`lib/ui/features/onboarding`** — the three-page first-launch flow (F-01).
- **`lib/ui/features/home`** — Home dashboard with its three sections (F-03).
- **`lib/ui/features/outfits`** — outfit list + detail + form (F-04, F-05).
- **`lib/ui/features/wearables`** — wearable list + detail + form (F-06, F-07).
- **`lib/app.dart`** — `MaterialApp.router` wiring: theme, router, provider tree.
- **`lib/app/router.dart`** — the `GoRouter` configuration (gate, shell, branches, detail/form routes).
- **`lib/main.dart`** — app entry point.

## State management

State is managed with `provider` and `ChangeNotifier` ViewModels, one per screen. The v1 ViewModel set is: `AppViewModel`, `OnboardingViewModel`, `HomeViewModel`, `OutfitListViewModel`, `OutfitDetailViewModel`, `WearableListViewModel`, `WearableDetailViewModel`, plus one route-scoped form ViewModel per form (`OutfitFormViewModel`, `WearableFormViewModel`).

**How ViewModels expose state.** Each ViewModel keeps private mutable storage and exposes it through read-only getters that return immutable snapshots: value objects for scalars and `List<T>` of immutable domain models for collections. `isLoading` and `error` are first-class parts of the state. `notifyListeners()` is called only when a snapshot actually changes (identity check), so unchanged streams do not trigger rebuilds (NFR-3).

**How Views observe state.** Views read their ViewModel with `context.read<T>()` and wrap their content in a `ListenableBuilder` (the equivalent `provider` `Consumer` is acceptable but `ListenableBuilder` is the standard, since it depends only on `ChangeNotifier`). The View contains no `setState` for domain state — only for purely local UI state such as focus or animation.

**How repositories reach ViewModels.** By constructor injection from the provider tree; a ViewModel never constructs a repository.

**Data-flow rule.** `Repository → stream → ViewModel → View`. Repositories expose `Stream<List<...>>` queries; ViewModels subscribe, keep the latest snapshot, and notify; Views render. Commands flow back through ViewModel methods to repository methods.

Example — `OutfitListViewModel` with a filtered stream and filter state:

```dart
// ui/features/outfits/view_models/outfit_list_view_model.dart
class OutfitListViewModel extends ChangeNotifier {
  OutfitListViewModel({required OutfitRepository repository})
      : _repository = repository {
    _subscription = _subscribe();
  }

  final OutfitRepository _repository;
  StreamSubscription<List<Outfit>>? _subscription;

  // -- filter state (A-2; FR-4.3 – FR-4.7) -------------------------------
  OutfitFilter _filter = const OutfitFilter();
  OutfitFilter get filter => _filter;
  bool get hasActiveFilters => _filter.isActive;

  // -- immutable state snapshots ------------------------------------------
  List<Outfit> _outfits = const [];
  List<Outfit> get outfits => _outfits;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  StreamSubscription<List<Outfit>> _subscribe() {
    return _repository.streamFiltered(_filter).listen(
          (outfits) {
            if (identical(outfits, _outfits)) return;
            _outfits = outfits;
            _isLoading = false;
            _error = null;
            notifyListeners();
          },
          onError: (Object error) {
            _error = error.toString();
            _isLoading = false;
            notifyListeners();
          },
        );
  }

  // -- command methods ------------------------------------------------------
  void setFilter(OutfitFilter filter) {
    if (identical(_filter, filter)) return;
    _filter = filter;
    _subscription?.cancel();
    _subscription = _subscribe(); // re-query with the new filter (FR-4.6)
  }

  void clearFilters() => setFilter(const OutfitFilter()); // FR-4.7

  Future<void> toggleFavorite(String id) => _repository.toggleFavorite(id); // FR-4.8

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
```

And the matching View, which shows how the empty-wardrobe and no-results states are distinguished (FR-4.10, FR-4.11):

```dart
// ui/features/outfits/views/outfit_list_view.dart
class OutfitListView extends StatelessWidget {
  const OutfitListView({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.read<OutfitListViewModel>();
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        if (viewModel.isLoading) return const CenteredLoader();
        if (viewModel.outfits.isEmpty) {
          return viewModel.hasActiveFilters
              ? NoResultsState(onClear: viewModel.clearFilters) // FR-4.10
              : const EmptyWardrobeState();                    // FR-4.11
        }
        return OutfitGrid(items: viewModel.outfits); // lazy grid (NFR-3)
      },
    );
  }
}
```

## Dependency injection

All dependencies are registered with `provider` in a single `MultiProvider` at the app root (`app.dart`), in the order **services → repositories → ViewModels**, because each layer depends only on the one above it:

```dart
// app.dart (abridged)
MultiProvider(
  providers: [
    // 1. Services — stateless, app scope.
    Provider<DatabaseService>(create: (_) => DatabaseService()),
    Provider<ImageFileService>(create: (_) => ImageFileService()),
    Provider<PreferencesService>(create: (_) => PreferencesService()),
    Provider<SyncService>(
      create: (_) => defaultTargetOs == TargetPlatform.iOS ||
              defaultTargetOs == TargetPlatform.macOS
          ? IcloudSyncService()
          : const NoopSyncService(),
    ),

    // 2. Repositories — single source of truth, app scope.
    Provider<WearableRepository>(
      create: (ctx) => WearableRepository(
        database: ctx.read<DatabaseService>(),
        images: ctx.read<ImageFileService>(),
      ),
    ),
    Provider<OutfitRepository>(
      create: (ctx) => OutfitRepository(
        database: ctx.read<DatabaseService>(),
        images: ctx.read<ImageFileService>(),
      ),
    ),
    Provider<SyncRepository>(
      create: (ctx) => SyncRepository(
        sync: ctx.read<SyncService>(),
        preferences: ctx.read<PreferencesService>(),
        wearables: ctx.read<WearableRepository>(),
        outfits: ctx.read<OutfitRepository>(),
      ),
    ),

    // 3. App-level ViewModels.
    ChangeNotifierProvider(
      create: (ctx) => AppViewModel(
        preferences: ctx.read<PreferencesService>(),
        sync: ctx.read<SyncRepository>(),
      ),
    ),
    ChangeNotifierProvider(
      create: (ctx) => HomeViewModel(
        outfits: ctx.read<OutfitRepository>(),
        wearables: ctx.read<WearableRepository>(),
      ),
    ),
    ChangeNotifierProvider(
      create: (ctx) => OnboardingViewModel(app: ctx.read<AppViewModel>()),
    ),
  ],
  child: MaterialApp.router(
    title: 'iWardrobe',
    theme: iwardrobeTheme,
    routerConfig: wardrobeRouter,
  ),
)
```

**Scoping rules.**
- **App scope** (registered once at the root): all services, all repositories, `AppViewModel`, `HomeViewModel` (Home is a shell branch and outlives tab switches), and `OnboardingViewModel`.
- **Route scope** (registered inside the `GoRoute.builder` of the route that owns the screen): the list, detail, and form ViewModels. They are created when the route is built and disposed when it is popped, so a detail page always observes live repository streams instead of a stale copy.

```dart
// app/router.dart (route-scoped ViewModel)
GoRoute(
  path: '/wearables',
  builder: (context, state) => Provider<WearableListViewModel>(
    create: (_) => WearableListViewModel(
      repository: context.read<WearableRepository>(),
    ),
    child: const WearableListView(),
  ),
),
```

**Rule.** Views never instantiate repositories or services directly — they only `context.read` an existing provider, and their only domain conversation partner is their ViewModel. This keeps the dependency graph acyclic and every unit testable: a ViewModel is tested with a fake repository, a repository is tested with an in-memory database.

## Navigation & routing

Navigation uses `go_router` bound to `MaterialApp.router`, configured in `lib/app/router.dart`.

**Route table.**

| Path | Purpose | Branch |
|---|---|---|
| `/` | Entry gate: redirect to `/onboarding` or `/home` (FR-1.1, FR-1.6) | — |
| `/onboarding` | Three-page first-launch flow (FR-1.2 – FR-1.5) | — |
| `/home` | Home dashboard (F-03) | 0 — Home |
| `/outfits` | Outfit list (F-04) | 1 — Outfits |
| `/outfits/new` | Outfit creation form (FR-8.2) | 1 |
| `/outfits/:id` | Outfit detail (F-05) | 1 |
| `/outfits/:id/edit` | Outfit edit form, pre-filled (FR-8.5) | 1 |
| `/wearables` | Wearable list (F-06) | 2 — Wearables |
| `/wearables/new` | Wearable creation form (FR-8.3) | 2 |
| `/wearables/:id` | Wearable detail (F-07) | 2 |
| `/wearables/:id/edit` | Wearable edit form, pre-filled (FR-8.5) | 2 |

**Add/edit as routes, not dialogs.** Creation and editing are full-screen flows with required fields, an image picker, and (for outfits) a wearable multi-select (FR-8.2, FR-8.3). Routes keep the form in the navigation stack — the system back gesture cancels with clear semantics, the form works equally on a 375-px phone and a resizable Mac window (FR-2.5, NFR-6), and each form owns its own route-scoped ViewModel. A dialog would force a modal pattern that degrades on wide windows, so v1 uses routes.

**The tab shell.** The three tabs are a `StatefulShellRoute.indexedStack` with one `StatefulShellBranch` per tab; each branch keeps its own navigation stack, so scroll position, active filters, and loaded content survive tab switches (FR-2.3). Detail and form routes are nested *inside* their branch, so pushing a detail page keeps the tab bar and the active tab (FR-2.4), and `context.pop()` returns to the same branch in the same state (FR-5.5, FR-2.4).

```dart
// app/router.dart
final GoRouter wardrobeRouter = GoRouter(
  initialLocation: '/',
  debugLogDiagnostics: kDebugMode,
  redirect: (context, state) {
    final atOnboarding = state.matchedLocation == '/onboarding';
    // Flag is read from the bootstrap object loaded before runApp,
    // so route evaluation needs no provider lookup.
    if (!appBootstrap.onboardingCompleted && !atOnboarding) return '/onboarding';
    if (appBootstrap.onboardingCompleted && atOnboarding) return '/home';
    return null;
  },
  routes: [
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingView(),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          WardrobeShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(path: '/home', builder: (context, state) => const HomeView()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/outfits',
            builder: (context, state) => const OutfitListView(),
            routes: [
              GoRoute(path: 'new', builder: (context, state) => const OutfitFormView()),
              GoRoute(path: ':id', builder: (context, state) =>
                  OutfitDetailView(id: state.pathParameters['id']!)),
              GoRoute(path: ':id/edit', builder: (context, state) =>
                  OutfitFormView(id: state.pathParameters['id']!)),
            ],
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/wearables',
            builder: (context, state) => const WearableListView(),
            routes: [
              GoRoute(path: 'new',
                  builder: (context, state) => const WearableFormView()),
              GoRoute(path: ':id', builder: (context, state) =>
                  WearableDetailView(id: state.pathParameters['id']!)),
              GoRoute(path: ':id/edit', builder: (context, state) =>
                  WearableFormView(id: state.pathParameters['id']!)),
            ],
          ),
        ]),
      ],
    ),
  ],
);
```

```dart
// ui/core/wardrobe_shell.dart
class WardrobeShell extends StatelessWidget {
  const WardrobeShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _goBranch(int index) {
    navigationShell.goBranch(
      index,
      // Tapping the active tab returns to its initial location.
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: _goBranch,
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.checkroom_outlined),
              selectedIcon: Icon(Icons.checkroom),
              label: 'Outfits'),
          NavigationDestination(
              icon: Icon(Icons.shopping_bag_outlined),
              selectedIcon: Icon(Icons.shopping_bag),
              label: 'Wearables'),
        ],
      ),
    );
  }
}
```

**How this satisfies the navigation requirements.**
- **FR-2.1** — exactly three destinations, in the order Home, Outfits, Wearables.
- **FR-2.2** — selecting a destination calls `goBranch` and marks it selected; the bar stays visible on all tabbed screens.
- **FR-2.3** — `indexedStack` keeps each branch's state (scroll position, active filters, loaded content) alive across switches.
- **FR-2.4** — detail and form routes are pushed on top of the active branch, so the tab stays current and back returns to it in the same state.
- **FR-2.5** — the route tree is form-factor independent; on wide windows (tablet, Mac) the *same paths* are used and only the shell chrome may change (for example a side rail instead of the bottom bar), which [Responsive design](responsive-design.md) defines.

**Onboarding gate.** The onboarding-completed flag is persisted with `shared_preferences` (FR-1.7) and read once during bootstrap before `runApp` into a small `appBootstrap` object; the router's `redirect` reads it, so first launch lands on `/onboarding` and every later launch lands on `/home` (FR-1.1, FR-1.6). Completing onboarding (Skip / Get started — FR-1.4, FR-1.5) persists the flag and navigates to `/home` explicitly; the redirect is not re-evaluated mid-session.

**Wide windows.** No route-level platform forks: the identical `GoRouter` tree is used on every form factor, and only the shell widget's chrome may adapt to window width (FR-2.5; see [Responsive design](responsive-design.md)).

## Cross-platform strategy

One codebase, one behavior, with a single platform branch: the sync service. There are no Android/iOS forks of features, screens, or logic anywhere else (FR-10.6).

| Platform | `SyncService` implementation | Sync UI |
|---|---|---|
| iOS / iPadOS | `IcloudSyncService` (wraps `icloud_storage_sync` 0.0.5) | Last-sync indicator (FR-10.5) |
| macOS | `IcloudSyncService` | Last-sync indicator (FR-10.5) |
| Android | `NoopSyncService` (same interface, no operations) | None (FR-10.5, FR-10.6) |

The branch happens exactly once, at provider registration, using `defaultTargetOs`:

```dart
// app.dart
Provider<SyncService>(
  create: (_) => defaultTargetOs == TargetPlatform.iOS ||
          defaultTargetOs == TargetPlatform.macOS
      ? IcloudSyncService()
      : const NoopSyncService(),
)
```

`IcloudSyncService` and `NoopSyncService` implement the same `SyncService` interface, so `SyncRepository`, `AppViewModel`, and the UI code never branch on platform: `AppViewModel.syncAvailable` (from `SyncRepository`) is simply `false` on Android, which hides the last-sync indicator, and no other code path exists for sync on Android. The sync protocol itself — document order, last-writer-wins conflict resolution (A-10), offline queue (FR-10.4) — is defined in [iCloud sync](icloud-sync.md).

## Error handling & logging

**Typed exceptions.** Repositories throw a small hierarchy of domain exceptions for commands and surface stream errors for reads; ViewModels catch both and convert them into an `error` state. Models throw `FormatException` on malformed input (see [Data model & local database](data-model-and-database.md), JSON wire format).

```dart
// domain/exceptions.dart
sealed class WardrobeException implements Exception {
  const WardrobeException(this.message);
  final String message;
}

/// A required field is missing or invalid (FR-8.4).
class ValidationException extends WardrobeException {
  const ValidationException(super.message);
}

/// An image file could not be read, written, or compressed (A-7).
class ImageFileException extends WardrobeException {
  const ImageFileException(super.message);
}

/// A sync operation failed on an Apple platform (FR-10.4).
class SyncException extends WardrobeException {
  const SyncException(super.message);
}
```

**Policy.**

| Situation | Handled by | User-visible effect |
|---|---|---|
| Read stream error (corrupt row, missing image file) | Repository stream `onError` → ViewModel `error` state | Section shows a retry affordance; one bad row never crashes the app |
| Validation failure on a form | Form ViewModel | Inline error naming the missing requirement (FR-8.4) |
| Write failure (disk full, file I/O) | Command throws `ImageFileException` / `WardrobeException` | Snackbar with a short human-readable message; the draft is kept so the user can retry |
| Sync failure (Apple platforms) | `SyncException` caught by `SyncRepository` | Last-sync indicator keeps the previous timestamp (FR-10.5); retry in the background (FR-10.4); never a blocking dialog |
| Unknown enum value in an incoming sync document | `FormatException` from `fromJson` | The single document is skipped and logged; the rest of the wardrobe loads (forward compatibility) |

**Snackbar policy.** One snackbar per failed action; messages are short, human-readable strings mapped from the exception type; stack traces, ids, and internal paths are never shown to the user. Success is shown by the UI state change itself (the new item appearing, the heart filling) rather than by toasts.

**Logging.** `debugPrint` gated on `kDebugMode`; repositories log failures with the entity id for diagnostics. No logging package, no log files, no telemetry, and nothing ever leaves the device (NFR-2).

## Testing strategy

| Level | What is tested | Tooling |
|---|---|---|
| Unit | ViewModels: state transitions, filter application (A-2), error surfacing — with fake repositories | `flutter test` + hand-written fakes |
| Unit | Repositories: filtered queries, newest-first ordering (A-3), cascade (FR-8.8 – FR-8.10), favorites (FR-9.x) | `flutter test` + in-memory `drift` (`NativeDatabase.memory()`) |
| Unit | Models: `fromJson`/`toJson` round-trips and rejection of malformed input | `flutter test` |
| Widget | List/detail/filter interactions: heart toggle (FR-4.8, FR-6.8), chip selection, empty vs no-results states (FR-3.5, FR-4.10, FR-6.11) | `flutter_test` `WidgetTester` |
| Integration | Smoke flow: add wearable → compose outfit → favorite it → Home reflects it (FR-3.2, FR-3.3, FR-8.12, FR-9.5) | `integration_test` package |

Conventions:

- Fakes, not generated mocks: repositories are small abstract interfaces (see [Data model & local database](data-model-and-database.md), Repository API surface), so hand-written fakes are sufficient and keep the codegen surface to `drift` only.
- Repository tests use an in-memory database and a temporary directory for image files, so they are deterministic and leave no artifacts.
- The acceptance criteria in [Functional specification](functional-specification.md) §10 are the checklist: every unchecked box must map to at least one automated test before a build is accepted.
- Commands:

```bash
flutter test
flutter test integration_test
```

## Code quality

- **`flutter_lints`** is the analysis rule set (`analysis_options.yaml` includes it; no additional rules in v1).
- **`dart format`** — every file is formatted; formatting is part of the commit gate, not a one-off cleanup.
- **`dart analyze`** — zero issues (errors, warnings, and infos) on every commit.
- **`build_runner`** — `drift` accessors are generated, never hand-edited; generated `*.g.dart` files are not committed and are regenerated locally and in CI.
- Commit-time checklist — run in this order before every commit:

```bash
dart run build_runner build --delete-conflicting-outputs
dart format lib test
dart analyze
flutter test
```

Plus, on every PR: no new dependency without a row in the Tech stack table, no layering rule violations (View → ViewModel → Repository), and no platform branching outside the `SyncService` registration.
