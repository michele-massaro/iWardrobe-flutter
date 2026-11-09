# Task 028 — Accessibility & motion audit

| | |
|---|---|
| **Phase** | 6 — Quality & acceptance |
| **Depends on** | 011–024 |
| **Primary references** | [UI & design language](../ui-design.md) §7 Motion, §9 Accessibility, §8 Dark mode, §10 copy · [Functional specification](../functional-specification.md) NFR-4, NFR-5 |

## Objective

A whole-app audit + fix pass so the app meets the documented accessibility baseline ("accessible by default — not a mode") and the motion rules. The user story: *as a user with a screen reader, with larger text, or with reduced motion on, I want the app to be fully usable and pleasant — without changing any setting myself.*

## What the agent must do

### 1. Touch & pointer targets (NFR-4)

- Every interactive element ≥ **44 × 44 logical px** — audit and pad as needed: `FavoriteHeart` (44-px hit area around the 24-px icon — 012), filter chips, tag chips, search field, edit/delete actions on detail pages, dialog Cancel/Delete (024), chevrons, FAB/toolbar add, nav destinations, the onboarding actions (016).
- On Mac (pointer) every control is reachable by mouse; on iPad/phone by touch. The indicator (025) is passive and needs no target — but its screen-reader label is required.

### 2. Screen-reader labels

- Every icon-only control carries its documented semantic label (UI doc §9): heart "Add to favorites" / "Remove from favorites" (012), add, search, edit, delete, cancel, close, chevron, the sync indicator's state label (025), nav destinations.
- Image tiles: the wardrobe image is decorative when the name is adjacent — but the detail page's image + name combination must read sensibly; placeholder tiles are labeled with the type.
- Announce favorite toggles and filter changes (live region / semantic announcement).

### 3. Contrast (UI doc §9, WCAG 2.1)

- Body text ≥ **4.5:1**, large text ≥ **3:1** — light **and** dark mode: `text-primary` on `surface`, `text-secondary` on `surface`/`background`, `on-primary` on `primary` (both modes), chip selected/outline states, the 14 swatch labels if any.
- The 011 contrast test already asserts the palette pairs — extend it to any new pair introduced by 014–024 (chip strokes, outline fields, error text).

### 4. Focus & keyboard (Mac)

- Focus order = visual order; a visible focus ring on every focusable control; keyboard-navigable: tabs (shell), chips, form fields, dialog actions, list items.

### 5. Dynamic text scaling

- With the system text size at **200%**: no truncation or clipping anywhere — cards wrap, grids drop a column (via `MaxCrossAxisExtent`), forms reflow. Test at 375 px and 1024 px.

### 6. Motion (UI doc §7)

- Respect `MediaQuery.disableAnimations` / reduced motion: the heart bounce, card hover transitions, the 250 ms onboarding page slide, and the ~200 ms chrome swap all collapse to a plain swap/crossfade/instant when enabled.
- Duration inventory matches the doc: heart bounce 200 ms ease-out; onboarding page 250 ms fade + slight slide; chrome swap ~200 ms; card hover/pressed subtle elevation transition.

### 7. Dark mode parity (UI doc §8)

- Every screen/section renders in dark mode with the warm charcoal values (no pure black/white, no shadow-only elevation — overlays per 011). Spot-check each screen in both modes.

## Definition of done

**Build** (standard gate): all items pass, including the new audit tests.

**Audit constraints:**

- [ ] **Targets:** every interactive element ≥ 44 × 44 — widget tests with hit-test assertions for each audited control (heart, chips, actions, dialog buttons, chevrons, FAB).
- [ ] **Labels:** semantic labels asserted for every icon-only control (widget tests comparing the `Semantics` label strings against the doc).
- [ ] **Contrast:** the 011 contrast helper covers all pairs in use; ≥ 4.5:1 body / ≥ 3:1 large asserted in light **and** dark.
- [ ] **Focus:** keyboard focus traversal test on the Mac build (or widget-level focus test) — order matches visual order; focus ring visible (assert).
- [ ] **Text scaling:** at 200% text size, no overflow/clipping at 375 and 1024 px (widget tests pumping with `TextScaleFactor(2.0)`).
- [ ] **Reduced motion:** with animations disabled, each documented animation is replaced (assert no `AnimationController`-driven bounce; crossfade/instant instead).
- [ ] **Dark mode:** one screenshot/structure test per screen in dark mode asserting the documented surface/background values (011 tokens, no exceptions).
- [ ] **Motion inventory:** a test asserting the documented durations exist in the widget tree for the four motion points (or are correctly suppressed).

**Verification:** the audit's fixes are committed with a summary message; any doc deviation found (e.g. an undocumented label) is either fixed to the doc value or the doc updated first (`instructions.md` §5).

## Out of scope

Reworking the visual language (UI doc is the reference — changes go through the doc), platform-specific a11y beyond the app controls, VoiceOver testing beyond label/correctness assertions (noted as a limitation).
