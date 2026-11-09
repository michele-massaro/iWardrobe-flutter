# iWardrobe — UI & design language

| | |
|---|---|
| **Version** | 1.0 (v1 / MVP) |
| **Date** | 9 November 2026 |
| **Status** | Reference for visual implementation |
| **Companion documents** | [Documentation index](README.md) · [Functional specification](functional-specification.md) · [Architecture](architecture.md) · [Data model & local database](data-model-and-database.md) · [iCloud sync](icloud-sync.md) · [Responsive design](responsive-design.md) |

## 1. Purpose & design principles

This document defines the **cozy visual language** of iWardrobe v1: the design principles, the color system for light and dark mode, typography, design tokens, the core component set with their states and behaviors, iconography, motion, dark mode, accessibility, the exact copy for empty and error states, and the mapping of every component to its planned code location.

The brief it serves is NFR-5: *"The interface shall feel warm, personal, and calm, aligned with a personal wardrobe rather than a generic productivity tool."*

**Design principles.**

1. **Warm & personal, not corporate.** Warm cream and terracotta tones, soft shapes, and friendly copy. The app is a closet, not a dashboard — no cold greys, no clinical blue, no corporate gradient.
2. **Calm & legible.** Generous whitespace, a limited palette, and a single type family. Nothing competes with the user's own photos, which are the visual heroes (FR-5.1, FR-7.1).
3. **Tactile.** Soft shadows, rounded corners, and a fabric-inspired warmth in the surfaces. Cards feel like they could be touched; the heart feels like it could be stamped.
4. **Consistent & predictable.** One card, one heart, one filter bar, one empty-state pattern, reused across every screen. The user learns once.
5. **Accessible by default.** 44 × 44 logical px targets, ≥ 4.5:1 contrast for body text, screen-reader labels on every icon-only control, and full support for the system text-size setting (NFR-4). Accessibility is not a mode; it is the baseline.

## 2. Color system

The palette is a warm, earthy set. Light mode is a warm cream; dark mode is a warm charcoal — never pure black, never pure white. A single seed color (the terracotta primary) drives the Material 3 `ColorScheme`; the named tokens below are the source of truth and are applied through `CardTheme`, `ChipTheme`, `NavigationBarTheme`, and `NavigationRailTheme`.

**Core palette (light and dark).**

| Token | Light | Dark | Use |
|---|---|---|---|
| `background` | `#FAF6F0` | `#1C1917` | App background, page surface behind cards |
| `surface` | `#FFFFFF` | `#292420` | Cards, dialogs, app bar, snackbar |
| `primary` | `#B5551F` | `#E08B5B` | Primary actions, selected states (warm terracotta; the light value is deepened from ≈ `#C4622D` so white `on-primary` reaches ≥ 4.5:1) |
| `on-primary` | `#FFFFFF` | `#1C1917` | Text/icons on primary fills |
| `secondary` | `#7A8450` | `#A3AD7D` | Sage/olive accent: selected chips, type placeholders, muted illustrations |
| `on-secondary` | `#FFFFFF` | `#1C1917` | Text/icons on secondary fills |
| `favorite` | `#C2452D` | `#F08A70` | The heart — filled state, favorite indicators |
| `text-primary` | `#2B2622` | `#F2EDE7` | Headings, primary labels |
| `text-secondary` | `#6E655C` | `#A79E93` | Captions, dates, helper text |
| `outline` | `#E2D9CE` | `#4A423A` | Dividers, outlined chip/field strokes |
| `success` | `#5C7A46` | `#A9C78F` | Warm olive green (not pure green) |
| `warning` | `#B07C2A` | `#D9A94E` | Warm amber |
| `error` | `#A63A31` | `#E5735F` | Warm crimson, deliberately distinct from `favorite` |

The Material 3 `ColorScheme` is **seeded from `primary`** (light `#B5551F`, dark `#E08B5B`) and then overridden with the explicit `favorite`, `secondary`, and semantic tokens above, so the cozy values are guaranteed rather than derived by approximation.

**Wardrobe color swatches.** The 14 predefined wardrobe colors (the `Color` set of [Data model & local database](data-model-and-database.md)) each render as a single swatch so that filter chips and the form's swatch grid are visually consistent everywhere. The swatch is a circular fill of the hex below, with a 1-px `outline` ring so `White` reads against a cream background. These swatches represent *the user's item colors*; they are chosen to be mutually distinguishable, not to be accessible text colors (the chip label beside them is).

| Wardrobe color | Swatch hex |
|---|---|
| Black | `#1F1B18` |
| White | `#F4EFE6` |
| Grey | `#8C857C` |
| Beige | `#D9C7A7` |
| Brown | `#6B4A32` |
| Red | `#B33A2E` |
| Orange | `#D97738` |
| Yellow | `#E3B23C` |
| Green | `#5F7A4E` |
| Teal | `#3F7E75` |
| Blue | `#4A6FA5` |
| Navy | `#2C3E5C` |
| Purple | `#6E5A8C` |
| Pink | `#D48CA0` |

## 3. Typography

**Typeface.** **Nunito** — a rounded, friendly humanist sans that reads as warm rather than corporate. Nunito is on Google Fonts under the SIL Open Font License (OFL), so it can be bundled with the app. System fallbacks are `-apple-system` (Apple platforms) and `Roboto` (Android), so text is always legible even before the font asset loads.

**Scale.** Sizes are slightly larger on the **expanded** breakpoint (see [Responsive design](responsive-design.md), Breakpoints) so Mac and full-iPad reading is comfortable. Line heights are unitless ratios.

| Style | Compact | Expanded | Weight | Line height | Use |
|---|---|---|---|---|---|
| Display | 28 | 32 | 800 (ExtraBold) | 1.25 | Onboarding titles, empty-state titles |
| Headline | 22 | 24 | 700 (Bold) | 1.3 | Screen titles, section headers (*Latest outfits*) |
| Title | 17 | 18 | 600 (SemiBold) | 1.4 | Card names, list-row names, dialog titles |
| Body | 15 | 16 | 400 (Regular) | 1.5 | Details, descriptions, notes, body copy |
| Label | 13 | 14 | 600 (SemiBold) | 1.4 | Chips, buttons, helper labels |

**Rules.**

- **Numerals and dates use tabular figures** (e.g. "12:30", "2026-11-05") so columns of dates and the sync timestamp align and do not jitter as they update.
- **Every icon-only control exposes a screen-reader label** (NFR-4); an icon without a label is a defect.
- **All text supports the system text-size setting** (NFR-4): the app never hard-codes a size that truncates, and layout reacts to a scaled font (cards wrap, grids drop a column) rather than clipping.

## 4. Design tokens

**Spacing scale** (logical px). All padding, margins, and gaps draw from this set:

`4 · 8 · 12 · 16 · 24 · 32 · 48`

**Corner radii.**

| Element | Radius |
|---|---|
| Chips (filter, tag) | 8 |
| Cards | 16 |
| Modals, dialogs, FAB | 24 |
| Image tiles | 12 |

**Elevation / shadow.** Soft, low-contrast shadows that lift a card off the cream background without a hard edge — cozy, not corporate. One level for resting cards, one slightly deeper level for hover/pressed and for snackbars. In dark mode shadows are replaced by **elevation overlays** (a lightening tint) so surfaces read as raised on the charcoal background.

**Image aspect ratios.** A single ratio for visual consistency: **4:5** for detail images and for every card image (outfit and wearable). A 4:5 tile reads as a garment photo rather than a landscape shot, and using one ratio keeps grids and carousels rhythmically even. Thumbnails are the 512-px files from [Data model & local database](data-model-and-database.md), Image storage; the detail page decodes the ≈1600-px original.

**Placeholder illustration style.** Where an image is absent (a wearable with no photo — A-7), the placeholder is a **rounded, single-weight line icon** of the item's type in a muted `secondary` (sage) color, centered on a soft `secondary`-tinted tile. The style is friendly and unapologetic — a "no photo yet" mark, not a broken-image box.

## 5. Core components

Each component lists its states, sizes, behavior, and the requirement(s) it serves. Component visuals follow the tokens above; component code locations are in [Component → code mapping](#11-component--code-mapping).

### 5.1 `WardrobeImage`

The single image widget used everywhere an outfit or wearable photo is shown.

| Aspect | Spec |
|---|---|
| States | *loading* (neutral `surface` tile, no spinner), *loaded* (photo), *missing/failed* (→ `WearableTypePlaceholder` for wearables, or a neutral garment mark for an outfit whose file is absent) |
| Sizes | Grid tile (4:5), Home carousel card (4:5), detail image (4:5, full width of its pane) |
| Behavior | **Lazy-loads** and shows a placeholder while decoding (NFR-3); when the file is absent at display time it renders the type-based placeholder (FR-7.1, FR-5.4, A-7) rather than an error; a failed decode is treated as missing |
| FR refs | FR-7.1, FR-5.4, A-7, NFR-3 |

### 5.2 `WardrobeCard`

The tappable card for an outfit or a wearable in any list, grid, or Home section.

| Variant | Content |
|---|---|
| Outfit card | 4:5 image, outfit name (Title), `FavoriteHeart` overlaid top-right |
| Wearable card | 4:5 image **or type placeholder**, name (Title), type (Label), `FavoriteHeart` overlaid top-right |

| Aspect | Spec |
|---|---|
| States | resting, hover (pointer), pressed, favorite on/off |
| Target | The card is the tap target to open detail (FR-4.9, FR-6.9); the heart is an independent 44 × 44 target on top (NFR-4) |
| Behavior | Tapping anywhere except the heart opens the detail page; tapping the heart toggles favorite without navigating (FR-4.8, FR-6.8); card uses 16 radius, soft elevation |
| FR refs | FR-4.2, FR-4.8, FR-4.9, FR-6.2, FR-6.8, FR-6.9, NFR-4 |

### 5.3 `FavoriteHeart`

The favorite toggle, identical on list cards and detail pages.

| Aspect | Spec |
|---|---|
| States | outlined (`outline` stroke) ↔ filled (`favorite` rose) |
| Feedback | Toggling applies **immediately** with a subtle scale-bounce (200 ms, ease-out) and no navigation (FR-4.8, FR-6.8, FR-9.3) |
| Target | 24-px icon inside a **44 × 44** hit area (NFR-4) |
| Screen reader | Label is **"Add to favorites"** when off and **"Remove from favorites"** when on |
| FR refs | FR-4.8, FR-6.8, FR-9.2, FR-9.3 |

### 5.4 `FilterBar`

The single filter control above the Outfits and Wearables lists.

| Aspect | Spec |
|---|---|
| Structure | A name **search field** plus a **chip row** for the page's dimensions, plus a **Clear filters** action |
| Selection semantics | Color and type are **single-select** chips with an "All" default; tags are **multi-select** combining with OR; active dimensions combine with AND (A-2, FR-4.4, FR-4.5, FR-6.5, FR-6.6, FR-6.7) |
| Clear | *Clear filters* resets all dimensions and restores the full list (FR-4.7, FR-6.7) |
| Layout | Chips **scroll horizontally** in compact/medium; chips **wrap** in expanded (see [Responsive design](responsive-design.md), Screen-by-screen layout) |
| Behavior | Applying a filter updates the visible list with no perceptible delay (NFR-3); the active set is preserved across tab switches (FR-2.3) |
| FR refs | A-2, FR-4.3 – FR-4.7, FR-6.3 – FR-6.7 |

### 5.5 `EmptyState`

Shown when a collection genuinely has no items (the wardrobe is empty), distinct from a filtered no-result.

| Aspect | Spec |
|---|---|
| Structure | A friendly placeholder illustration + one line of copy + a primary CTA button |
| Per-screen copy | Home welcome, *Favorite outfits*, *Favorite clothes*, Outfits empty, Wearables empty — exact strings in [Empty & error state copy](#10-empty--error-state-copy) |
| Behavior | The CTA opens the matching creation flow (FR-3.6, FR-4.11, FR-6.11); a Home section without items stays visible with its short message and does not affect other sections (FR-3.5) |
| FR refs | FR-3.5, FR-3.6, FR-4.11, FR-6.11 |

### 5.6 `NoResultsState`

Shown when active filters exclude every item. Visually distinct from `EmptyState`.

| Aspect | Spec |
|---|---|
| Structure | A "no match" illustration + copy that **names the active filters** + a **Clear filters** action |
| Behavior | *Clear filters* resets the dimensions and restores the full list; it never offers a "create" CTA (the wardrobe is not empty) |
| FR refs | FR-4.10, FR-6.10, FR-4.7, FR-6.7 |

### 5.7 `WearableTypePlaceholder`

The type-based placeholder rendered by `WardrobeImage` when a wearable has no photo.

| Type | Icon (rounded line style) |
|---|---|
| Top | shirt |
| Bottom | pants |
| Dress | dress |
| Jacket | jacket |
| Shoes | sneaker |
| Accessory | scarf |

| Aspect | Spec |
|---|---|
| Style | Single-weight rounded line icon in muted `secondary`, on a soft `secondary`-tinted tile |
| Size | Fills its 4:5 tile; icon ≈ 40–48 px |
| FR refs | FR-7.1, FR-5.4, A-5, A-7 |

### 5.8 Form components

Shared by the wearable and outfit creation/edit forms (FR-8.2, FR-8.3, FR-8.5).

| Component | Spec |
|---|---|
| Name field | Single-line text field; required for both forms; inline error when missing (FR-8.4) |
| Type chip row | Six single-select chips: Top, Bottom, Dress, Jacket, Shoes, Accessory (A-5, FR-6.4); required for wearables |
| Color swatch grid | 7 × 2 grid of the 14 swatches from [Color system](#2-color-system); single-select, optional (A-8); "No color" clears it |
| Size / Brand / Material / Notes | Optional text fields; shown only as needed |
| Tag chip input | Type-ahead chip input; add on entry, remove on tap; multi-value (FR-8.3) |
| Image picker tile | Large 4:5 tile with **Take photo** and **Choose from album** options (`image_picker`, FR-8.2, FR-8.3); **required** for outfits, optional for wearables (A-7); on edit an outfit image may be replaced but never removed (FR-8.6) |
| Season selector | Single-select: Spring, Summer, Autumn, Winter, All seasons (A-9, FR-8.2) |

| Aspect | Spec |
|---|---|
| Validation | The form does not submit while a required field is missing and shows an **inline error naming the missing requirement** (FR-8.4) |
| Layout | Always a single column, centered, `ConstrainedBox(maxWidth: 480)` + `Center` at every breakpoint (see [Responsive design](responsive-design.md), Forms) |

### 5.9 `SyncStatusIndicator`

The lightweight last-sync indicator. **Apple platforms only** — it does not exist on Android (FR-10.5, FR-10.6).

| State | Text (with clock glyph) |
|---|---|
| Idle — last sync succeeded | `Last synced 12:30` |
| Idle — never succeeded | `Not synced yet` |
| Syncing | `Syncing…` |
| Error | `Sync paused — no connection` / `Sync error — remote data quarantined`, always alongside the last successful time |

| Aspect | Spec |
|---|---|
| Placement | Per breakpoint: app-bar trailing (compact/medium), rail footer or app-bar trailing (expanded) — see [Responsive design](responsive-design.md), Sync status host |
| Behavior | A passive indicator, not a menu or settings page; on error it reveals the short reason plus the last successful time; never a blocking dialog (FR-10.5; [iCloud sync](icloud-sync.md), §9–§10) |
| Target | 44 × 44 when tappable (NFR-4) |

### 5.10 Snackbar

| Aspect | Spec |
|---|---|
| Style | Rounded (16), `surface`-elevated, one line of short human-readable copy |
| Duration | 4 s |
| Behavior | One snackbar per failed action; success is shown by the UI state change itself (the item appearing, the heart filling), not a toast; internal ids, paths, and stack traces are never shown (see [Architecture](architecture.md), Error handling & logging) |

## 6. Iconography

**Icon set.** **Material Symbols Rounded** — the rounded variant, chosen for the friendly, consistent, non-clinical look that matches the cozy language. One weight (400) and one size per context keep the set uniform.

**App-bar action icons.**

| Action | Icon |
|---|---|
| Add | `add` |
| Search | `search` |
| Close / clear | `close` |
| Favorite | `favorite` / `favorite_border` |
| Edit | `edit` |
| Delete | `delete` |
| Back / drill-in | `chevron_right`, `arrow_back` |

**Rules.**

- **Icon-only buttons always get a screen-reader label** (NFR-4); the icon alone is never the accessible name.
- Icons inside **chips and type placeholders** render at **20 px** (in chips) or **24 px** (type placeholders, per 5.7).
- Icons are tinted with `text-primary` by default and `favorite` for the filled heart; selected/active states use `primary`.

## 7. Motion & micro-interactions

Motion is **subtle and calm** — it confirms an action, it never performs. Nothing bounces or spins in a steady state.

| Interaction | Treatment |
|---|---|
| Heart toggle | Scale-bounce: 1.0 → 1.15 → 1.0 over **200 ms, ease-out** |
| Page transition | **250 ms** fade + slight slide (detail pushes in, back reverses) |
| Shell chrome change (bar ↔ rail) | **200 ms** animated reflow (see [Responsive design](responsive-design.md), Transition behavior) |
| List item enter | Staggered **30 ms** fade-up, applied to at most **8** visible items so a large wardrobe still loads fast |
| Snackbar | Slide-up from the bottom edge, then auto-dismiss at 4 s |

**Reduced motion.** All of the above respect the system reduced-motion setting (and `Theme.of(context).useAnimations`): when reduced motion is on, animations collapse to a plain crossfade or an instant swap. There is always a fully usable, animation-free path (NFR-4).

## 8. Dark mode

Dark mode is **first-class**, not an afterthought.

- **Warm charcoal, not pure black.** The dark palette (background `#1C1917`, surface `#292420`) keeps the warm undertone, so the cozy feel survives on a dark canvas.
- **Images keep their tone.** Wardrobe photos are user content and are never re-tinted; the surrounding warm surfaces frame them.
- **Shadows become elevation overlays.** Because shadows do not read on a dark background, elevation is expressed as a lightening tint (see [Design tokens](#4-design-tokens)).
- **The rose favorite stays legible.** `favorite` shifts from `#C2452D` (light) to `#F08A70` (dark) so the filled heart and favorite indicators remain clearly readable on the charcoal surfaces (measured in [Accessibility](#9-accessibility)).
- **Contrast is re-checked per mode.** Every text/background pair is validated in both light and dark, not assumed to carry over.

## 9. Accessibility

The NFR-4 baseline, implemented as a checklist. Every item is a release gate, not a goal.

- **Touch targets ≥ 44 × 44 logical px.** Every interactive element, including the heart (a 24-px icon inside a 44-px hit area), chip selection, and list-row chevrons.
- **Contrast ≥ 4.5:1 for body text.** Measured pairs from the palette (WCAG 2.1 relative-luminance contrast):

| Pair | Mode | Measured |
|---|---|---|
| `#2B2622` on `#FAF6F0` (body) | light | ≈ 13.9 : 1 |
| `#6E655C` on `#FAF6F0` (secondary) | light | ≈ 5.3 : 1 |
| `#F2EDE7` on `#1C1917` (body) | dark | ≈ 15.0 : 1 |
| `#A79E93` on `#1C1917` (secondary) | dark | ≈ 6.6 : 1 |
| `#FFFFFF` on `#B5551F` (on-primary) | light | ≈ 4.9 : 1 |
| `#1C1917` on `#E08B5B` (on-primary) | dark | ≈ 6.7 : 1 |
| `#C2452D` on `#FAF6F0` (favorite, graphics) | light | ≈ 4.7 : 1 |
| `#F08A70` on `#292420` (favorite, graphics) | dark | ≈ 6.3 : 1 |

- **Screen-reader label on every icon control.** The heart, add, search, edit, delete, close, and chevron all expose an accessible name (see 5.3, 6).
- **Focus order follows visual order.** Keyboard focus moves in the same top-to-bottom, left-to-right order the eye reads; focus is always visible (a focus ring).
- **Text scaling to 200% without truncation.** With the system font scaled to 200%, cards wrap to fit and grids drop a column rather than clipping; no fixed-height text box is allowed to overflow.
- **Reduced-motion fallback.** All animations (5, 7) have an instant or crossfade fallback when reduced motion is enabled.

## 10. Empty & error state copy

Exact, final user-facing strings. Do not paraphrase in the UI.

| Where | Title | Body / action | Source |
|---|---|---|---|
| Home — empty wardrobe | "Your wardrobe is waiting" | "Add a few pieces and compose your first look — everything stays on your device." · [Add your first wearable] · [Compose your first outfit] | FR-3.6 |
| Home — *Favorite outfits* empty | "No favorite outfits yet — tap the heart on any outfit" | (short message, section stays visible) | FR-3.5 |
| Home — *Favorite clothes* empty | "No favorite clothes yet — tap the heart on any item" | (short message, section stays visible) | FR-3.5 |
| Outfits — empty | "No outfits yet" | "Combine wearables into a named look." · [Create your first outfit] | FR-4.11 |
| Outfits — no results | "No outfits match" | "Nothing matches your filters." · [Clear filters] | FR-4.10, FR-4.7 |
| Wearables — empty | "No clothes yet" | "Add the first piece of your wardrobe." · [Add your first wearable] | FR-6.11 |
| Wearables — no results | "No clothes match" | "Nothing matches your filters." · [Clear filters] | FR-6.10, FR-6.7 |
| Form — name missing | — | "Give it a name." | FR-8.4 |
| Form — outfit image missing | — | "An outfit needs a photo." | FR-8.4, A-7 |
| Form — no wearable selected | — | "Pick at least one wearable." | FR-8.4, A-6 |
| Sync — synced | — | "Last synced 12:30" | FR-10.5 |
| Sync — never synced | — | "Not synced yet" | FR-10.5 |
| Sync — in progress | — | "Syncing…" | FR-10.5 |
| Sync — offline | — | "Sync paused — no connection" | FR-10.4, FR-10.5 |
| Sync — quarantined | — | "Sync error — remote data quarantined" | FR-10.5 |
| Delete — confirm (wearable) | "Delete <name>?" | "It will be removed from N outfits. An outfit left with no wearables is deleted too." · [Cancel] · [Delete] | FR-8.7, FR-8.8, FR-8.9 |
| Delete — confirm (outfit) | "Delete <name>?" | "Its wearables are kept." · [Cancel] · [Delete] | FR-8.7, FR-8.10 |
| Onboarding 1 | "Catalog your wardrobe" | "Add a photo and the details of every item you own." · 1 of 3 | FR-1.2, FR-1.3 |
| Onboarding 2 | "Compose outfits" | "Combine wearables into named, reusable looks." · 2 of 3 | FR-1.2, FR-1.3 |
| Onboarding 3 | "Stay in sync" | "On iPhone, iPad, and Mac, your wardrobe and its images are kept in your iCloud and available on every device signed in to the same Apple account." · 3 of 3 | FR-1.2, FR-1.3 |

## 11. Component → code mapping

Components map to the `lib/ui/core` shared set and the feature views, consistent with the project structure in [Architecture](architecture.md). The theme is a **single `AppTheme`** exposing light and dark `ColorScheme`s (and the derived `CardTheme`, `ChipTheme`, `NavigationBarTheme`, `NavigationRailTheme`), so there is one source of truth for the visual language.

| Component | Planned location | Note |
|---|---|---|
| `AppTheme` (palette, typography, tokens, light + dark) | `lib/ui/core/theme.dart` | Single theme object; light/dark schemes |
| `WardrobeImage` | `lib/ui/core/widgets/wardrobe_image.dart` | Named in [Architecture](architecture.md), Project structure |
| `FavoriteHeart` | `lib/ui/core/widgets/favorite_heart.dart` | Named in [Architecture](architecture.md), Project structure |
| `FilterBar` | `lib/ui/core/widgets/filter_bar.dart` | Named in [Architecture](architecture.md), Project structure |
| `EmptyState` | `lib/ui/core/widgets/empty_state.dart` | Named in [Architecture](architecture.md), Project structure |
| `WardrobeCard` | `lib/ui/core/widgets/wardrobe_card.dart` | Shared by Home + both lists |
| `WearableTypePlaceholder` | `lib/ui/core/widgets/wearable_type_placeholder.dart` | Used by `WardrobeImage` fallback |
| `NoResultsState` | `lib/ui/core/widgets/no_results_state.dart` | Distinct from `EmptyState` |
| `SyncStatusIndicator` | `lib/ui/core/widgets/sync_status_indicator.dart` | Apple platforms only (FR-10.5) |
| Form fields (name, type row, swatch grid, tag input, image tile, season) | `lib/ui/core/widgets/form/` | Shared by both forms |
| `WardrobeShell` (adaptive chrome) | `lib/ui/core/wardrobe_shell.dart` | Named in [Architecture](architecture.md); breakpoint switch per [Responsive design](responsive-design.md) |
| Home sections, list views, detail views, form views | `lib/ui/features/<feature>/views/` | Per feature, as in [Architecture](architecture.md) |
