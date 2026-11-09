# Task 013 — App entry, DI tree, router & adaptive shell

| | |
|---|---|
| **Phase** | 3 — Shell & UI core |
| **Depends on** | 005, 010, 011, 012 |
| **Primary references** | [Architecture](../architecture.md) §Project structure, §State management, §Dependency injection, §Navigation & routing · [Responsive design](../responsive-design.md) §3 Breakpoints, §4 Navigation shell, §9 Transitions · [Functional specification](../functional-specification.md) FR-1.1, FR-1.6, FR-2.1 – FR-2.5 |

## Objective

Wire the app together: the real `main.dart` (bootstrap before `runApp`), the root `MultiProvider` tree in the documented order, the complete `GoRouter` (onboarding gate + three-branch `StatefulShellRoute` + detail/form routes), and the adaptive `WardrobeShell` whose chrome switches from a bottom `NavigationBar` to a left `NavigationRail` on window width — with per-branch state preservation. Features not yet built get titled placeholder screens; each feature task (016–024) then replaces its placeholder in place.

## What the agent must deliver

### 1. `lib/main.dart`

- `Future<void> main()`: `WidgetsFlutterBinding.ensureInitialized()`, `await loadAppBootstrap(...)` (task 005), then `runApp(const App())`. No business logic beyond this.

### 2. `lib/app.dart` — `MaterialApp.router` + `MultiProvider`

The provider tree in the documented order **services → repositories → ViewModels** (Architecture §Dependency injection):

```dart
// 1. Services — stateless, app scope.
Provider<DatabaseService>, Provider<ImageFileService>, Provider<PreferencesService>,
Provider<SyncService>(create: (_) => defaultTargetOs == TargetPlatform.iOS ||
        defaultTargetOs == TargetPlatform.macOS
    ? IcloudSyncService() : const NoopSyncService()),   // the ONLY platform branch (006)

// 2. Repositories — app scope.
Provider<WearableRepository>, Provider<OutfitRepository>,
Provider<SyncRepository>(sync, preferences, wearables, outfits, bookkeeping),

// 3. App-level ViewModels.
ChangeNotifierProvider<AppViewModel>, ChangeNotifierProvider<OnboardingViewModel? — added by 016>,
ChangeNotifierProvider<HomeViewModel? — added by 017>
```

- `title: 'iWardrobe'`, `theme: AppTheme.light`, `darkTheme: AppTheme.dark`, `routerConfig: wardrobeRouter`.
- **Scoping rules (binding):** services + repositories + `AppViewModel` are app scope (registered at the root). List/detail/form ViewModels are **route scope** — created inside the owning route's `builder` (pattern in the Architecture doc) so a detail page always observes live streams and is disposed on pop. Feature tasks add their rows; this task creates the structure and the app-scope ViewModels that exist now.
- **`AppViewModel`** (`ChangeNotifier`): exposes `onboardingCompleted`, `completeOnboarding()` (persists the flag via `PreferencesService` + notifies), `syncAvailable` (from `SyncRepository` — `false` on Android, hides the indicator), and the last-sync status passthrough (data for task 025).

### 3. `lib/app/router.dart` — the `GoRouter`

Exactly the route table of the Architecture doc (the doc contains the full code):

| Path | Purpose | Branch |
|---|---|---|
| `/` | Entry gate: redirect to `/onboarding` or `/home` (FR-1.1, FR-1.6) | — |
| `/onboarding` | Three-page flow (FR-1.2 – FR-1.5) | — |
| `/home` | Home dashboard (F-03) | 0 |
| `/outfits`, `/outfits/new`, `/outfits/:id`, `/outfits/:id/edit` | List, create, detail, edit | 1 |
| `/wearables`, `/wearables/new`, `/wearables/:id`, `/wearables/:id/edit` | List, create, detail, edit | 2 |

- **Redirect (gate):** reads `appBootstrap.onboardingCompleted` (loaded before `runApp` — no provider lookup): not completed and not at `/onboarding` → `/onboarding`; completed and at `/onboarding` → `/home`; otherwise `null`.
- **Shell:** `StatefulShellRoute.indexedStack` with one `StatefulShellBranch` per tab; detail/form routes nested **inside** their branch (pushing a detail keeps the tab bar + active tab; `context.pop()` returns to the same branch in the same state — FR-2.4).
- **Add/edit as routes, not dialogs** (FR-8.2/8.3; Architecture §Navigation): each form owns a route-scoped ViewModel (feature tasks provide them).
- **No route-level platform forks:** the identical tree on every form factor (FR-2.5).

### 4. `lib/ui/core/breakpoints.dart`

```dart
enum Breakpoint { compact, medium, expanded }

Breakpoint breakpointFor(double maxWidth) {
  if (maxWidth >= 1024.0) return Breakpoint.expanded;
  if (maxWidth >= 600.0) return Breakpoint.medium;
  return Breakpoint.compact;
}
```

Read **only** from `LayoutBuilder` `constraints.maxWidth` (shell-level and per-screen). Never `MediaQuery.orientationOf`, never device-type checks (Responsive design doc §3 — non-negotiable).

### 5. `lib/ui/core/wardrobe_shell.dart` — the adaptive chrome

Per the Responsive design doc §4 (full code in the doc):

- **compact / medium (`< 1024`):** `Scaffold` + bottom `NavigationBar`, three destinations with icons + labels: Home (`home`/`home_outlined`), Outfits (`checkroom`/`checkroom_outlined`), Wearables (`shopping_bag`/`shopping_bag_outlined`).
- **expanded (`≥ 1024`):** `Row(NavigationRail(icon + label, same three destinations, same indices, `leading: BrandMark()`, `trailing` slot reserved for the sync indicator — task 025) + VerticalDivider + Expanded(navigationShell))`.
- `_goBranch(index)` with `initialLocation: index == navigationShell.currentIndex` (tapping the active tab returns to its initial location).
- **Same `StatefulNavigationShell` instance drives both chromes** — `goBranch`, current-index reporting, and active-tab persistence are form-factor independent (FR-2.5).
- **Animated chrome transition (~200 ms)** when crossing 1024: `AnimatedSwitcher`/`AnimatedBuilder` over the chrome; no reload, no re-navigation, no lost state (doc §9).

### 6. Placeholder screens

For routes whose feature task hasn't run yet: a minimal `Scaffold` with the screen title (e.g. "Home", "Outfit detail"), each in its own file under the planned `lib/ui/features/<feature>/views/` path so feature tasks replace content, not location.

## Definition of done

**Build** (standard gate): all items pass.

**Widget test constraints** — `test/ui/` (router + shell with fake ViewModels/repositories):

- [ ] **Gate:** fresh launch (flag false) lands on `/onboarding`; completed flag lands on `/home`; navigating to `/onboarding` while completed redirects to `/home`.
- [ ] **Tabs:** exactly three destinations in the order Home, Outfits, Wearables (FR-2.1); selecting a tab marks it selected (FR-2.2).
- [ ] **Branch state:** switching tabs and back preserves each branch's state (a fake list VM's scroll/filter survives — FR-2.3).
- [ ] **Detail routes:** pushing `/outfits/:id` keeps the Outfits tab active; popping returns to the Outfits list in the same state (FR-2.4, FR-5.5).
- [ ] **Active-tab tap:** tapping the current tab returns to its initial location.
- [ ] **Breakpoint switch:** at width 375 → bottom `NavigationBar` present, no rail; at 1024 → `NavigationRail` present, no bottom bar; the switch happens live on a `LayoutBuilder` constraint change with the ~200 ms animation (no route re-push; tab identity unchanged).
- [ ] **Branch indices:** `goBranch(index)` behaves identically in both chromes (same destination reached at each index).
- [ ] **DI scoping:** a route-scoped ViewModel is created on route build and disposed on pop (fake VM tracking construction/disposal); app-scope ViewModels survive navigation.
- [ ] **AppViewModel:** `completeOnboarding()` persists the flag (visible through a fresh `PreferencesService` read) and `syncAvailable` reflects the `SyncRepository` value.

**Functional acceptance**

- [ ] The single platform branch in the codebase is the `SyncService` registration (grep: no other `TargetPlatform` references in `lib/`).
- [ ] Views contain no `setState` for domain state; `main.dart`/`app.dart` contain no business logic beyond wiring.
- [ ] The placeholder screens are the **only** feature content; no feature logic is implemented here (features are 016–024).

**Out of scope for this task:** feature screens/ViewModels (016–024), the sync indicator (025), breakpoint behavior *inside* screens (each screen's task + the 027 pass).
