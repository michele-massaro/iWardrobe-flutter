# iWardrobe — Responsive design

| | |
|---|---|
| **Version** | 1.0 (v1 / MVP) |
| **Date** | 9 November 2026 |
| **Status** | Reference for layout implementation |
| **Companion documents** | [Documentation index](README.md) · [Functional specification](functional-specification.md) · [Architecture](architecture.md) · [Data model & local database](data-model-and-database.md) · [iCloud sync](icloud-sync.md) · [UI & design language](ui-design.md) |

## 1. Purpose & scope

This document defines **how the layout of iWardrobe v1 adapts to the available window width** across smartphone, tablet, and Mac. It fixes the breakpoints, the navigation-shell strategy, the per-screen layout at each breakpoint, the grid and content-width rules, the input and action model, the orientation and multitasking behavior, the transition behavior when crossing a breakpoint, and the test matrix.

It does **not** redefine product behavior: **what** the app does is fixed in the [functional specification](functional-specification.md) — in particular **NFR-6** (the app adapts to window width, not device type, including resizable Mac windows and iPad multitasking, with no locked orientation) and **FR-2.5** (the three sections, their order, and state preservation are identical on every form factor; on wide windows the *navigation presentation* may adapt, for example a side rail instead of a bottom bar). It does not define the visual system either: **how it looks** — palette, typography, components — is fixed in [UI & design language](ui-design.md).

The governing principle, taken directly from the project's responsive-layout skill and restated here as a hard rule: **every layout decision is based on the available window width, never on device type or screen orientation.** The concrete measurement rule is `LayoutBuilder` and its `constraints.maxWidth`, evaluated at the shell and inside each screen. `MediaQuery.orientationOf` and hardware-type checks are banned for layout switching (see [Breakpoints](#3-breakpoints)).

## 2. Core principles

- **Window over device.** The app renders to whatever window it is given — a 375-px phone, a 744-px iPad in Split View, or a 1600-px Mac window — and every layout decision reads that width. The same `GoRouter` tree and the same ViewModels run at every width ([Architecture](architecture.md), Navigation & routing).
- **No orientation lock.** The app never locks screen orientation. Locking orientation causes letterboxing on foldable devices and breaks the resizable-window model; both portrait and landscape must lay out correctly from the window width alone (NFR-6).
- **Resizable Mac windows and iPad multitasking are first-class.** A Mac window resized from its minimum size to full screen, and an iPad in Split View or Slide Over, are ordinary cases: the app re-lays-out live as the window width changes. There is no "phone mode" or "desktop mode" — only a width.
- **Breakpoints react live to resizing.** Crossing a breakpoint boundary while dragging a window resizes, reflows, and re-chromes the UI in place. No reload, no lost state (see [Transition behavior across breakpoints](#9-transition-behavior-across-breakpoints)).
- **Multiple input methods.** Touch on phones and tablets; mouse, trackpad, and keyboard on Mac. Every control must be reachable and operable by pointer and by keyboard, and every touch target must be at least 44 × 44 logical px (NFR-4).
- **Readability over width.** On wide windows, text-heavy and form content is constrained to a readable measure and centered rather than stretched full-bleed; grids grow their column count instead of their item width.

## 3. Breakpoints

There are exactly three breakpoints, selected by the current window width in logical pixels:

| Name | Window width | Typical contexts | Navigation chrome | List presentation |
|---|---|---|---|---|
| **compact** | `< 600` | Phones in portrait (375 – 430); an iPad in Slide Over (~320); a very narrow Mac window | Bottom `NavigationBar` (3 destinations + labels) | 2-column grids; single-column details; single-column forms |
| **medium** | `600 – 1023` | Phones in landscape; small iPad multitasking (Split View ~540, ~744); narrow-to-medium Mac windows | Bottom `NavigationBar` (3 destinations + labels) | 3-column grids; single-column details; single-column forms |
| **expanded** | `≥ 1024` | Full iPad (11" 834 is medium, 12.9" 1024 is expanded); typical and full Mac windows | Left `NavigationRail` (icon + label) | 4–6-column adaptive grids; two-pane details; centered forms |

**Why the 600 threshold.** `600` logical px is the Material 3 convention for the boundary between phone-class and tablet-class windows, and it is the same value the project's responsive-layout skill uses as its `largeScreenMinWidth = 600`. Using it keeps the app's mental model aligned with the platform's own adaptive guidance and with the skill's reference implementation, so "medium and expanded" behave exactly as the skill's large-screen workflow expects.

**Measurement rule — non-negotiable.**

- The breakpoint is read from `LayoutBuilder` `constraints.maxWidth`, evaluated **at the shell level** (so the navigation chrome can switch) **and inside each screen** (so each screen can switch its own layout independently).
- `MediaQuery.sizeOf(context)` may be used to read the overall window size, but **layout switching must not depend on it alone**, because it does not reflect the constraints a specific subtree actually receives.
- **Never** use `MediaQuery.orientationOf` / `OrientationBuilder` to switch layouts — orientation does not describe the available window space.
- **Never** branch on hardware type ("phone" vs "tablet" vs "desktop"). Flutter apps run in resizable windows, multi-window modes, and picture-in-picture; a device check would mis-render a phone in a wide window and a wide device in a narrow one (for example an iPad in Slide Over is a *wide device* at a *compact width*).

```dart
// Breakpoint selection, shared by the shell and every screen.
enum Breakpoint { compact, medium, expanded }

Breakpoint breakpointFor(double maxWidth) {
  if (maxWidth >= 1024.0) return Breakpoint.expanded;
  if (maxWidth >= 600.0) return Breakpoint.medium;
  return Breakpoint.compact;
}
```

## 4. Navigation shell

The three tabs are one `StatefulShellRoute.indexedStack` with one branch per tab — Home (index 0), Outfits (index 1), Wearables (index 2) — exactly as defined in [Architecture](architecture.md), Navigation & routing. That shell is the **single** navigation shell for the whole app; there is no second shell for wide windows.

The shell widget (`WardrobeShell`) picks its **chrome** by breakpoint using a `LayoutBuilder`, but the **branch indices are identical** in both presentations, so `navigationShell.goBranch(index)` behaves the same whether the chrome is a bottom bar or a side rail:

- **compact / medium** → a bottom `NavigationBar` with the three destinations, each with an icon and a label.
- **expanded** → a left `NavigationRail` (icon + label) for the same three destinations, with the same indices in the same order.

Because the same `StatefulNavigationShell` instance drives both, selecting a destination, the current-index reporting, and the active-tab persistence are form-factor independent — this is exactly the FR-2.5 allowance that "on wide windows the navigation presentation may adapt (for example, a side rail instead of a bottom bar) without changing the functional behavior."

```dart
// ui/core/wardrobe_shell.dart — adaptive chrome, identical branch indices.
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
    return LayoutBuilder(
      builder: (context, constraints) {
        if (breakpointFor(constraints.maxWidth) == Breakpoint.expanded) {
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: navigationShell.currentIndex,
                  onDestinationSelected: _goBranch,
                  leading: const BrandMark(),
                  trailing: const SyncStatusIndicator(), // Apple platforms only (FR-10.5)
                  destinations: const [
                    NavigationRailDestination(
                        icon: Icon(Icons.home_outlined),
                        selectedIcon: Icon(Icons.home),
                        label: Text('Home')),
                    NavigationRailDestination(
                        icon: Icon(Icons.checkroom_outlined),
                        selectedIcon: Icon(Icons.checkroom),
                        label: Text('Outfits')),
                    NavigationRailDestination(
                        icon: Icon(Icons.shopping_bag_outlined),
                        selectedIcon: Icon(Icons.shopping_bag),
                        label: Text('Wearables')),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: navigationShell),
              ],
            ),
          );
        }
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
      },
    );
  }
}
```

The `SyncStatusIndicator` in the rail `trailing` slot is present only on Apple platforms and is hidden on Android, where `AppViewModel.syncAvailable` is `false` (FR-10.5, FR-10.6; see [iCloud sync](icloud-sync.md), §10, and the [Sync status host](#5-screen-by-screen-layout) row below).

## 5. Screen-by-screen layout

Each table states, one line per cell, the layout at compact / medium / expanded. "Grid N" means an adaptive `GridView.builder` with `SliverGridDelegateWithMaxCrossAxisExtent`; the column count shown is the typical result for the breakpoint's width band.

**Home** (FR-3.1 – FR-3.7)

| compact | medium | expanded |
|---|---|---|
| Vertical stack: *Latest outfits* horizontal carousel (cards ≈ 70% of screen width), then *Favorite outfits* 2-column grid, then *Favorite clothes* 2-column grid | Same vertical stack; carousel cards wider; both grids 3 columns | *Latest outfits* carousel with larger cards; *Favorite outfits* and *Favorite clothes* as wider 4+ column grids via `MaxCrossAxisExtent`; whole page centered with `ConstrainedBox(maxWidth: 1200)` + `Center` |

**Outfits list** (FR-4.1 – FR-4.11)

| compact | medium | expanded |
|---|---|---|
| 2-column grid of outfit cards (image, name, heart overlay) — the wardrobe feel is visual, so a 2-up grid is used even in compact rather than a single text row | 3-column grid of the same card | 4–6 column adaptive grid via `SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 260)` |

A single `FilterBar` (search + color + tag chips + *Clear filters*) sits above the grid at every breakpoint (FR-4.3 – FR-4.7).

**Outfit detail** (FR-5.1 – FR-5.7)

| compact | medium | expanded |
|---|---|---|
| Single column: image (dominant, ~4:5), name + details, then the *In this outfit* wearable list as rows (thumbnail, name, type, chevron) | Single column, image slightly wider; *In this outfit* list below | Two-pane: left = image + details in a `ConstrainedBox(maxWidth: 520)`; right = *In this outfit* list panel. Becomes two-pane at the **expanded** breakpoint (≥ 1024) |

**Wearables list** (FR-6.1 – FR-6.11)

| compact | medium | expanded |
|---|---|---|
| 2-column grid (image or type placeholder, name, type, heart) | 3–4 column grid | 4–6 column adaptive grid via `MaxCrossAxisExtent` — the "grid layout on wide windows" of FR-6.1 |

A single `FilterBar` (search + type + color + tag chips + *Clear filters*) sits above the grid at every breakpoint (FR-6.3 – FR-6.7).

**Wearable detail** (FR-7.1 – FR-7.5)

| compact | medium | expanded |
|---|---|---|
| Single column: image (dominant on top, or type placeholder per FR-7.1), info below, tags as chips | Single column, image wider; info + tags below | Two-pane: image (or placeholder) left in a `ConstrainedBox(maxWidth: 520)`; info + tags + actions right |

**Forms — add/edit wearable & add/edit outfit** (FR-8.2, FR-8.3, FR-8.4)

| compact | medium | expanded |
|---|---|---|
| Always a single column, centered, `ConstrainedBox(maxWidth: 480)` + `Center` at **every** breakpoint (readability over width) | Same | Same |

The form fields are laid out consistently at all widths: image picker as a large tile, type as a chip row, color as a swatch grid, and tags as a chip input. See [UI & design language](ui-design.md), Core components.

**Onboarding** (FR-1.2 – FR-1.5)

| compact | medium | expanded |
|---|---|---|
| Full screen at every breakpoint; content centered with `ConstrainedBox(maxWidth: 420)` + `Center` even on Mac — onboarding is a phone-shaped experience, not a dashboard | Same | Same |

Each page shows its title, explanatory text, a position indicator ("1 of 3"), and the per-page actions (Next/Skip on pages 1–2, Get started/Skip on page 3) (FR-1.3 – FR-1.5).

**Sync status host** (FR-10.5) — Apple platforms only

| compact | medium | expanded |
|---|---|---|
| App bar trailing slot: clock glyph + short text (icon + tooltip when very narrow) | App bar trailing slot: clock glyph + short text | `NavigationRail` footer (`trailing` slot) or app bar trailing, as space allows |

On Android the indicator does not exist at all — `AppViewModel.syncAvailable` is `false` (FR-10.5, FR-10.6; [iCloud sync](icloud-sync.md), §10).

## 6. Lists, grids & content width

These rules apply to every screen and are the concrete expression of NFR-3 (lazy rendering, smooth scrolling) and the skill's large-screen workflow:

- **Lazy lists always.** Use `ListView.builder` / `GridView.builder` for any list or grid with an unknown or large number of items. Never materialize the whole wardrobe at once (NFR-3).
- **Grid strategy: `MaxCrossAxisExtent`.** Use `SliverGridDelegateWithMaxCrossAxisExtent` so the column count is derived from the window width rather than hard-coded per screen. The item width is bounded, so a wider window yields more columns automatically, and the same delegate works from compact to full-screen Mac.

```dart
// Adaptive grid used by the Outfits and Wearables lists (FR-4.1, FR-6.1).
GridView.builder(
  padding: const EdgeInsets.all(16),
  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
    maxCrossAxisExtent: 260, // bounds item width; columns grow with the window
    mainAxisSpacing: 16,
    crossAxisSpacing: 16,
    childAspectRatio: 0.78,  // 4:5 image + a name strip
  ),
  itemCount: items.length,
  itemBuilder: (context, index) => WardrobeCard(item: items[index]),
)
```

- **Readable measure for text and forms.** Wrap forms and detail text in a `ConstrainedBox` with a `maxWidth`, then center it, so a Mac window never stretches a paragraph or a form edge-to-edge.

```dart
// Constrained, centered form (used at every breakpoint).
Center(
  child: ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 480.0),
    child: const WearableFormView(),
  ),
)
```

- **Two-pane splits with `Expanded` / `Flexible`.** The expanded two-pane layouts (Outfit detail, Wearable detail) use a `Row` with the image pane in a `ConstrainedBox(maxWidth: 520)` and the list/info pane in an `Expanded`, so the right pane absorbs all remaining width while the image keeps a readable width.
- **No full-bleed text on Mac.** A line of body copy should never span the full width of a large window; the `ConstrainedBox` + `Center` pattern above is the fix.

## 7. Actions & input

- **Primary add action.** The Outfits and Wearables pages each expose a primary *add* action that opens the creation form: a **floating action button (FAB) on compact and medium**, and an **equivalent toolbar action on expanded** (FR-8.1). The two are functionally identical — same command, same destination route — only the chrome differs by breakpoint.
- **Pointer affordances.** All interactive elements expose **hover states and focus rings** for mouse/trackpad use on Mac and iPad-with-pointer, and remain fully operable by touch (NFR-4).
- **Keyboard (optional polish on Mac).** The app may register: **⌘N** for a new item on the current list, **⌘F** to focus the search field, and **Esc** to go back. These are optional polish (P2) and must never be the only way to perform an action.
- **Touch targets.** Every interactive element — including the heart on a card, chip selection, and list-row chevrons — must be at least 44 × 44 logical px (NFR-4). Where the visible icon is smaller (for example a 24-px heart), the hit area is padded to the 44-px minimum.

## 8. Orientation & multitasking

- **Never lock orientation.** The app supports both portrait and landscape from the window width alone. Locking orientation is explicitly rejected because it causes letterboxing on foldable devices and conflicts with the resizable-window model (NFR-6).
- **iPad multitasking is the proof case.** In Split View or Slide Over, an iPad presents a **compact** or **medium** window on a physically wide device. The breakpoint system reads that narrow width and lays out accordingly — which is precisely why device-type checks are banned: a device check would see "tablet" and mis-render, while the width check is always right.
- **Mac window range.** A Mac window must stay usable from its minimum size (roughly 800 × 600) to full screen, with the chrome and grid rules above adapting continuously as it is resized.
- **Validation workflow (per the skill).** For any layout change: resize the app window across each breakpoint boundary (just below / just above 600 and 1024) → review the transitions → fix any overflow or abrupt content loss. A layout is not done until it survives this sweep on a real resizable window.

## 9. Transition behavior across breakpoints

When the window crosses a breakpoint boundary, **state must not change; presentation may**:

**Must NOT change** (identity and state are preserved):
- **Tab identity** — the currently selected tab (Home / Outfits / Wearables) and its index (FR-2.1, FR-2.2).
- **Branch state** — each branch keeps its own stack and state, so scroll position, active filters, and loaded content survive a chrome change (FR-2.3).
- **Filter state** — the active `OutfitFilter` / `WearableFilter` is unchanged (A-2).
- **Scroll position** — the list stays where the user left it.
- **Route stack** — the current route (list, detail, form) and its position in the branch stack are unchanged (FR-2.4).

**May change** (presentation only):
- **Chrome** — bottom `NavigationBar` ↔ left `NavigationRail`.
- **Grid columns** — 2 → 3 → 4–6 columns, and card/tile size.
- **Two-pane splits** — single-column detail ↔ two-pane detail.

**Transition style.** The chrome switch and the layout reflow should be **animated**, not instant: an `AnimatedBuilder`/`AnimatedContainer` (or `AnimatedSwitcher`) over the shell chrome, roughly 200 ms, so the rail growing from the bar reads as a deliberate change. There are **no page reloads** and **no re-navigation** — the same widget tree re-lays-out, so no state is lost and no route is re-pushed.

## 10. Test matrix

The layout is accepted when every row below passes on the named surface, plus the resize sweep. Cross-reference NFR-6 and the [Architecture](architecture.md) testing strategy (widget tests with `WidgetTester`; integration smoke flow).

| Surface | Width (logical px) | Breakpoint | What to verify |
|---|---|---|---|
| iPhone SE | 375 | compact | 2-col grids, bottom bar, FAB, single-column detail |
| iPhone 15 Pro | 393 | compact | as above; no overflow at this width |
| iPhone 15 Pro Max | 430 | compact | as above |
| iPhone Pro Max, landscape | ~932 | medium | 3-col grids, bottom bar, wider carousel |
| iPad mini, portrait | 744 | medium | 3-col grids, bottom bar, single-column detail |
| iPad Pro 11", portrait | 834 | medium | as above |
| iPad Pro 12.9", portrait | 1024 | expanded | 4+ col grids, rail chrome, two-pane detail |
| iPad Split View | ~540 and ~744 | compact / medium | narrow window on a wide device renders compact/medium correctly (no device check) |
| Mac window, minimum | ~800 × 600 | medium | usable at minimum size; no overflow |
| Mac window, half-screen | ~half of display | medium | reflows correctly on resize |
| Mac window, full screen | ≥ 1440 | expanded | rail chrome, 4–6 col grids, two-pane, centered forms |

**Resize sweep.** On a Mac, drag the window continuously from **350 → 1600** logical px and verify: transitions across 600 and 1024 are smooth and animated; no overflow, no clipped content, no abrupt loss of content or state; tab identity, filters, and scroll position are preserved at every width. This single sweep is the acceptance gate for NFR-6.
