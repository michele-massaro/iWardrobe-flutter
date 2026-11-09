# Task 016 — Onboarding flow

| | |
|---|---|
| **Phase** | 4 — Features |
| **Depends on** | 005, 013 |
| **Primary references** | [Functional specification](../functional-specification.md) FR-1.1 – FR-1.7, §7.1 flow · [UI & design language](../ui-design.md) §10 (onboarding copy) · [Responsive design](../responsive-design.md) §5 (Onboarding row) |

## Objective

Deliver the three-page first-launch introduction (F-01) that runs once after installation, with the exact documented copy and page actions, and that — via the router gate already in place (task 013) — is never shown again after completion. The user story: *as a new user, I want a short onboarding on my first launch so I understand what the app can do before I start adding clothes.*

## What the agent must deliver

### 1. `OnboardingView` — `lib/ui/features/onboarding/views/onboarding_view.dart`

Exactly three pages, in this order, each with a title, short explanatory text, and a position indicator ("1 of 3", "2 of 3", "3 of 3") (FR-1.2, FR-1.3). **Frozen copy** (UI doc §10):

| Page | Title | Body |
|---|---|---|
| 1 | "Catalog your wardrobe" | "Add a photo and the details of every item you own." |
| 2 | "Compose outfits" | "Combine wearables into named, reusable looks." |
| 3 | "Stay in sync" | "On iPhone, iPad, and Mac, your wardrobe and its images are kept in your iCloud and available on every device signed in to the same Apple account." |

- **Page 1 & 2:** **Next** (advances) + **Skip** (dismisses onboarding and opens Home — FR-1.4).
- **Page 3:** **Get started** + **Skip**; both dismiss onboarding and open Home (FR-1.5).
- Page transitions: the documented 250 ms fade + slight slide (UI doc §7), reduced-motion aware.

### 2. `OnboardingViewModel` — `lib/ui/features/onboarding/view_models/onboarding_view_model.dart`

`ChangeNotifier`, app-scoped (registered in the root `MultiProvider` per task 013's structure — this task adds the row). Owns the page index and exposes: `pageIndex`, `totalPages`, `positionLabel` ("N of 3"), commands `next()`, `skip()`, `getStarted()`. `skip()`/`getStarted()` call `AppViewModel.completeOnboarding()` (persists the flag — FR-1.7) and the view navigates to `/home` explicitly (the redirect is not re-evaluated mid-session — Architecture §Navigation).

### 3. Layout

Full screen at **every** breakpoint; content centered with `ConstrainedBox(maxWidth: 420)` + `Center` even on Mac — onboarding is a phone-shaped experience, not a dashboard (Responsive design doc §5).

## Definition of done

**Build** (standard gate): all items pass.

**Widget test constraints** — `test/ui/features/onboarding/`:

- [ ] **Sequence:** the view shows page 1 ("Catalog your wardrobe", "1 of 3") initially; **Next** → page 2 ("Compose outfits", "2 of 3"); **Next** → page 3 ("Stay in sync", "3 of 3").
- [ ] **Copy:** all six frozen strings (3 titles + 3 bodies) render verbatim (asserted against the UI doc §10 values).
- [ ] **Skip on page 1:** lands on `/home`, the onboarding-completed flag is persisted (a fresh `PreferencesService` read returns true).
- [ ] **Skip on page 2 / Get started on page 3:** same persistence + navigation.
- [ ] **Gate integration:** with the flag set, the router never presents `/onboarding` on a new app instance (FR-1.1/FR-1.6) — end-to-end through the router from task 013.
- [ ] **Layout:** at 375 px and 1440 px the content is centered in a 420-px max-width column (same presentation, different window).
- [ ] **Motion:** page transition respects reduced motion (instant/crossfade when enabled).

**Functional acceptance**

- [ ] Completing onboarding does not alter any wardrobe data (A-11: re-showing onboarding, FR-1.8, is **out of scope** — no setting is added).
- [ ] The flag is device-local: no sync code touches it (iCloud doc §4 "What is not synchronized").

**Out of scope for this task:** FR-1.8 (re-present onboarding) — explicitly excluded from the v1 baseline.
