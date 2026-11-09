# Task 014 — FilterBar, EmptyState & NoResultsState

| | |
|---|---|
| **Phase** | 4 — Features |
| **Depends on** | 011 |
| **Primary references** | [UI & design language](../ui-design.md) §5.4–5.6, §10 Empty & error state copy · [Functional specification](../functional-specification.md) FR-4.3 – FR-4.7, FR-6.3 – FR-6.7, FR-4.10/4.11, FR-6.10/6.11, A-2 |

## Objective

Deliver the three shared state/filter components that both list pages reuse: the single `FilterBar` (search + chips + clear), the empty-wardrobe `EmptyState`, and the visually distinct `NoResultsState`. Filter semantics (A-2) and the frozen copy (UI doc §10) are binding.

## What the agent must deliver

### 1. `FilterBar` — `lib/ui/core/widgets/filter_bar.dart` (UI doc §5.4)

- **Structure:** a name **search field** (case-insensitive substring — FR-4.3/FR-6.3) + a **chip row** for the page's dimensions + a **Clear filters** action.
- **Chip semantics (A-2, binding):** color and type are **single-select** chips with an "All" default; tags are **multi-select** chips combining with **OR**; active dimensions combine with **AND**. The bar renders only the dimensions its page uses (Outfits: name, color, tags — color/tags derived; Wearables: name, type, color, tags).
- **Layout:** chips **scroll horizontally** in compact/medium; chips **wrap** in expanded (Responsive design doc §5).
- **Behavior:** applies filters with no perceptible delay (NFR-3); the active set is preserved across tab switches (FR-2.3 — the filter state lives in the page ViewModel, the bar renders it).
- API: renders an immutable filter (task 002) and reports changes via `onFilterChanged(WearableFilter | OutfitFilter)` + `onClear` — the ViewModel owns the state, the bar owns no domain state (Architecture rule 2).
- Color chips show the 14 documented swatches (011) + label; type chips use the 6 documented labels; tag chips are generated from the wardrobe's tag vocabulary (exposed as an input).

### 2. `EmptyState` — `lib/ui/core/widgets/empty_state.dart` (UI doc §5.5)

- Friendly placeholder illustration + one line of copy + a primary CTA button.
- **Per-screen copy — frozen, do not paraphrase** (UI doc §10):
  - Home welcome: "Your wardrobe is waiting" / "Add a few pieces and compose your first look — everything stays on your device." + CTAs [Add your first wearable] · [Compose your first outfit] (FR-3.6)
  - Outfits empty: "No outfits yet" / "Combine wearables into a named look." + [Create your first outfit] (FR-4.11)
  - Wearables empty: "No clothes yet" / "Add the first piece of your wardrobe." + [Add your first wearable] (FR-6.11)
  - Home sections: "No favorite outfits yet — tap the heart on any outfit" / "No favorite clothes yet — tap the heart on any item" (short message, section stays visible — FR-3.5)
- The CTA opens the matching creation flow (route navigation via callback); section-level emptiness shows only the short message with **no** CTA.

### 3. `NoResultsState` — `lib/ui/core/widgets/no_results_state.dart` (UI doc §5.6)

- "No match" illustration + copy that **names the active filters** + a **Clear filters** action.
- Frozen copy: Outfits — "No outfits match" / "Nothing matches your filters." + [Clear filters] (FR-4.10, FR-4.7); Wearables — "No clothes match" / same body + [Clear filters] (FR-6.10, FR-6.7).
- **Never** offers a "create" CTA (the wardrobe is not empty) and is **visually distinct** from `EmptyState` (FR-4.10/FR-6.10).

## Definition of done

**Build** (standard gate): all items pass.

**Widget test constraints** — `test/ui/widgets/`:

- [ ] **Single-select:** selecting a color chip deselects the previously selected color; "All" resets the dimension; type behaves the same on the wearable variant.
- [ ] **Multi-select OR:** selecting two tag chips keeps both active; the reported `OutfitFilter`/`WearableFilter` carries both ids (OR is the repository's job — the bar must not collapse them).
- [ ] **AND across dimensions:** with name + color + tags active, the reported filter has all three set (the ViewModel passes it to `streamFiltered`).
- [ ] **Search:** typing updates the `nameSubstring` (case-insensitive matching is asserted at the repository level, 008/009; the bar only reports).
- [ ] **Clear:** *Clear filters* reports the const default filter (all dimensions reset, FR-4.7/FR-6.7).
- [ ] **Layout:** at 375 px the chip row is horizontally scrollable; at 1024 px chips wrap (no horizontal scroll).
- [ ] **EmptyState:** each of the documented variants renders the **exact** frozen strings; section-level variants render no CTA; the CTA callback fires.
- [ ] **NoResultsState:** renders the exact frozen copy, names the active filters (assert the filter summary text changes with the active set), offers *Clear filters* and **no** create CTA; visually distinct from `EmptyState` (different illustration + structure asserted by widget type/keys).

**Functional acceptance**

- [ ] The components hold no domain state — filter state comes in as a value, changes go out as events (testable with a stateless harness).
- [ ] All strings come verbatim from the UI doc §10 table (a test compares against the documented strings).

**Out of scope for this task:** the list pages themselves (018/019), Home sections (017), filter *evaluation* (repositories).
