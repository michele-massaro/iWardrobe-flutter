# Task 011 — AppTheme, typography & design tokens

| | |
|---|---|
| **Phase** | 3 — Shell & UI core |
| **Depends on** | 001 |
| **Primary references** | [UI & design language](../ui-design.md) §2 Color system, §3 Typography, §4 Design tokens · [Functional specification](../functional-specification.md) NFR-5, NFR-4 |

## Objective

Deliver the single visual source of truth — `AppTheme` with the complete cozy light + dark design system: the terracotta-seeded Material 3 color scheme, the explicit token overrides, the Nunito type scale, spacing/radii/elevation tokens, the 14 wardrobe color swatches, and the derived `CardTheme`/`ChipTheme`/`NavigationBarTheme`/`NavigationRailTheme`. Every widget in later tasks renders from this object; nothing hard-codes colors or sizes.

## What the agent must deliver

### 1. `lib/ui/core/theme.dart` — the `AppTheme`

- **ColorScheme (Material 3), seeded from `primary`** (light `#B5551F`, dark `#E08B5B`) **then overridden with the explicit tokens** of the UI doc §2 table (so the cozy values are guaranteed, not approximated): `background` `#FAF6F0`/`#1C1917`, `surface` `#FFFFFF`/`#292420`, `primary` + `on-primary`, `secondary` (sage) + `on-secondary`, `favorite` `#C2452D`/`#F08A70`, `text-primary` `#2B2622`/`#F2EDE7`, `text-secondary` `#6E655C`/`#A79E93`, `outline` `#E2D9CE`/`#4A423A`, `success`, `warning`, `error` (deliberately distinct from `favorite`).
- Two `ThemeData`s (light + dark) built from the schemes; dark mode is first-class (warm charcoal, never pure black — UI doc §8).
- **Wardrobe color swatches:** the 14 values of the `Color` enum (task 002) mapped to the documented swatch hexes (`Black #1F1B18` … `Pink #D48CA0`), exposed so filter chips and the form swatch grid render identically everywhere (UI doc §2).

### 2. Typography

- **Nunito** bundled as a font asset (Google Fonts, SIL OFL — the license permits bundling; add the license text alongside). Weights needed: 400, 600, 700, 800. System fallbacks: `-apple-system` (Apple platforms), `Roboto` (Android).
- The documented scale (UI doc §3), with slightly larger sizes at the expanded breakpoint: Display 28/32 (800, 1.25), Headline 22/24 (700, 1.3), Title 17/18 (600, 1.4), Body 15/16 (400, 1.5), Label 13/14 (600, 1.4). Expose a breakpoint-aware text-theme helper (the `Breakpoint` enum arrives in task 013; until then, accept a size class parameter — compact vs expanded).
- **Tabular figures** for numerals and dates (sync timestamp, date columns).

### 3. Design tokens (UI doc §4)

- Spacing scale constants: `4 · 8 · 12 · 16 · 24 · 32 · 48`.
- Corner radii: chips 8, cards 16, modals/dialogs/FAB 24, image tiles 12.
- Elevation: one soft resting level + one deeper level (hover/pressed, snackbars); in dark mode shadows are replaced by **elevation overlays** (lightening tint).
- **Image aspect ratio token: 4:5** (detail images and every card).

### 4. Derived component themes

`CardTheme` (16 radius, soft elevation), `ChipTheme` (8 radius; selected state on `primary`; swatch-style color chips), `NavigationBarTheme` + `NavigationRailTheme` (selected on `primary`, label/icon tinting), `SnackbarTheme` (16 radius, `surface`-elevated — used by task 024), `DialogTheme` (24 radius).

## Definition of done

**Build** (standard gate): all items pass (the placeholder app from task 001 is wrapped in `AppTheme` in both light and dark mode).

**Unit/widget test constraints** — `test/ui/theme/`:

- [ ] **Palette fidelity:** both `ColorScheme`s expose the exact documented hex values for every token (assert programmatically against the UI doc §2 table).
- [ ] **Dark ≠ pure black/white:** background/surface are the warm charcoal/cream values.
- [ ] **Swatch map:** all 14 `Color` enum values map to the documented swatch hexes (complete coverage, no default fallback).
- [ ] **Typography:** the font family is applied and the asset loads (text renders with Nunito); the five styles exist with documented sizes/weights/line-heights at both compact and expanded sizes; tabular figures flag set for date styles.
- [ ] **Contrast:** a helper test computes WCAG 2.1 relative-luminance contrast for the measured pairs of the UI doc §9 table and asserts ≥ 4.5:1 (body/secondary in both modes, on-primary in both modes; graphics pairs ≥ the documented values).
- [ ] **Tokens:** spacing/radii constants exist and the card/chip/nav themes carry them (16/8/24/12 radii, 4:5 image ratio token).
- [ ] **Elevation modes:** dark theme uses overlay-based elevation (assert the theme config, not pixel output).

**Functional acceptance**

- [ ] A single `AppTheme` object is the only place the palette exists (no hex literals outside it, including swatches).
- [ ] Light and dark are both switchable via `MaterialApp.theme`/`darkTheme` with no per-widget forking.

**Out of scope for this task:** widgets, screens, breakpoint evaluation (013), motion (012/028).
