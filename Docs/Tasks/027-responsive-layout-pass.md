# Task 027 — Responsive layout pass

| | |
|---|---|
| **Phase** | 6 — Quality & acceptance |
| **Depends on** | 013, 017–024 |
| **Primary references** | [Responsive design](../responsive-design.md) §3 Breakpoints, §5 Per-screen table, §6 Grid & content width, §8 Test matrix, §9 Transitions · [Functional specification](../functional-specification.md) NFR-6, FR-2.5 |

## Objective

A whole-app audit + completion pass so **every screen** conforms to the documented breakpoint system — the final gate for NFR-6 (*the app adapts to window width, not device type*). The user story: *as a user on a phone, an iPad in Split View, or a full-screen Mac, I want the same app to lay out correctly for my window — live, as I resize it.*

## What the agent must do

### 1. Audit every screen against the per-screen table (Responsive doc §5)

For each screen — Home, Outfits list, Wearables list, Outfit detail, Wearable detail, both forms, onboarding — verify the documented row is implemented:

| Screen | Expected behavior (doc §5) |
|---|---|
| Home | Sections in order at all widths; carousel card width ~70% (compact) → larger (expanded); grids 2/3/4+ columns; page centered `maxWidth: 1200` (expanded) |
| Outfits / Wearables lists | FilterBar (chips scroll compact/medium, wrap expanded); grid 2/3/4–6 columns (`MaxCrossAxisExtent`); FAB (compact/medium) ↔ toolbar action (expanded) |
| Outfit / Wearable detail | Single column + full-width 4:5 image (compact/medium) ↔ two-pane: image + details `maxWidth: 520` left, list/attributes panel right (expanded) |
| Both forms | Single column, centered, `maxWidth: 480` at **every** breakpoint |
| Onboarding | Centered `maxWidth: 420` at every breakpoint |
| Shell chrome | `NavigationBar` bottom (compact/medium) ↔ `NavigationRail` left (expanded); sync indicator in the app-bar trailing (compact/medium) ↔ rail trailing (expanded) |

Fix any deviation **in place** (each screen's own code — no cross-screen refactors beyond what the doc requires).

### 2. Grid & content-width rules (doc §6)

- Grids grow their **column count**, never their item width, as the window widens (assert the `MaxCrossAxisExtent` delegate, not fixed column counts).
- Text-heavy / form content is constrained to a readable measure and centered — never stretched full-bleed.
- Every layout decision reads `LayoutBuilder` `constraints.maxWidth` through the shared `breakpointFor` (013). **Grep-level check:** no `MediaQuery.of(context).size.width` / `orientation` / `defaultTargetPlatform`-based layout switching anywhere in `lib/ui` (the banned pattern, doc §3).

### 3. Resize sweep — the acceptance gate for NFR-6

On a Mac (full-screen build), drag the window continuously from **350 → 1600** logical px and verify (manual, recorded in the Verification log below):

- Transitions across 600 and 1024 are **smooth and animated** (~200 ms chrome swap — 013), no reload.
- **No overflow, no clipped content, no abrupt loss of content or state** at any width.
- Tab identity, active filters, and scroll position are preserved **at every width**.

### 4. Test matrix (doc §8) — automated

Implement widget tests (or extend existing ones) covering the documented matrix rows at named widths: 375 (phone portrait), 393, 430, 932 (iPad landscape), 744 (iPad portrait), 834, 1024, ~540 + ~744 (Split View pairs), ~800 (Mac minimum window), Mac half-screen, Mac full-screen (≥ 1440). For each: the correct chrome + per-screen layout renders, no overflow exceptions.

## Definition of done

**Build** (standard gate): all items pass, including the new matrix tests.

**Verification constraints:**

- [ ] Per-screen table: all rows verified compliant (or fixed + tested) — checked against doc §5 line by line.
- [ ] Grid rule: column count grows with width (asserted in tests at 375/744/1024).
- [ ] Content-width: forms 480 / onboarding 420 / Home 1200 / detail left pane 520 — asserted in tests.
- [ ] **No banned layout APIs** in `lib/ui` (grep: zero hits for `orientation`-based or device-type layout switching).
- [ ] **Resize sweep executed** on a Mac build (350 → 1600), logged in the Verification log below with pass/fail + notes.
- [ ] Test matrix (doc §8): all rows present as automated tests and passing.

## Verification log (resize sweep)

| Date | Window sizes swept | Result | Notes (overflow/state/chrome) |
|---|---|---|---|
| — | 350 → 1600 | ☐ | |

## Out of scope

Visual redesign (the UI doc is the reference — 028 for the a11y overlay), performance tuning (029), anything product-level (new layouts are doc changes first).
