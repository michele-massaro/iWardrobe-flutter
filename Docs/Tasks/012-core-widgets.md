# Task 012 — Core widgets: image, placeholder, card, heart

| | |
|---|---|
| **Phase** | 3 — Shell & UI core |
| **Depends on** | 011 |
| **Primary references** | [UI & design language](../ui-design.md) §4 Design tokens, §5.1–5.3, §7 Motion · [Functional specification](../functional-specification.md) FR-4.2/4.8/4.9, FR-6.2/6.8/6.9, FR-7.1, FR-5.4, A-7, NFR-3, NFR-4 |

## Objective

Deliver the four shared widgets that every screen reuses: the lazy image with placeholder fallback, the type-based placeholder, the tappable wardrobe card (both variants), and the favorite heart. These are the "learn once" components of the cozy language — one card, one heart, one image, reused across Home and both lists (UI doc §5, design principle 4).

## What the agent must deliver

### 1. `WardrobeImage` — `lib/ui/core/widgets/wardrobe_image.dart` (UI doc §5.1)

- **States:** *loading* (neutral `surface` tile, no spinner) · *loaded* (photo) · *missing/failed* → `WearableTypePlaceholder` for wearables, or a neutral garment mark for an outfit whose file is absent.
- **Sizes:** grid tile (4:5), Home carousel card (4:5), detail image (4:5, full width of its pane) — driven by the 4:5 token (011).
- **Behavior:** lazy-loads with a placeholder while decoding (NFR-3); loads the **512 px thumbnail** for grid/carousel tiles and the **≈1600 px original** for detail pages (paths from the documented layout, task 004); a missing file renders the placeholder (FR-7.1, FR-5.4, A-7), never an error box; a failed decode is treated as missing.
- Input: the entity `imagePath?` + `kind` + (for the fallback) the `WearableType`.

### 2. `WearableTypePlaceholder` — `lib/ui/core/widgets/wearable_type_placeholder.dart` (UI doc §5.7)

- Rounded, single-weight line icon of the item's type in muted `secondary`, centered on a soft `secondary`-tinted tile, filling its 4:5 tile; icon ≈ 40–48 px.
- Icon per type: Top → shirt, Bottom → pants, Dress → dress, Jacket → jacket, Shoes → sneaker, Accessory → scarf.
- A "no photo yet" mark, not a broken-image box. (If a Material Symbols Rounded glyph doesn't exist for a type, add a local asset icon in the same rounded line style.)

### 3. `WardrobeCard` — `lib/ui/core/widgets/wardrobe_card.dart` (UI doc §5.2)

| Variant | Content |
|---|---|
| Outfit | 4:5 image, outfit name (Title), `FavoriteHeart` overlaid top-right |
| Wearable | 4:5 image **or type placeholder**, name (Title), type (Label), `FavoriteHeart` overlaid top-right |

- **States:** resting, hover (pointer), pressed, favorite on/off. Card radius 16, soft elevation.
- **Targets:** the card is the tap target to open detail (FR-4.9, FR-6.9); the heart is an **independent 44 × 44 target on top** (NFR-4) — tapping it never triggers the card navigation (FR-4.8, FR-6.8).
- Exposes `onTap` (open detail) and `onToggleFavorite` callbacks; renders from immutable model inputs (task 002).

### 4. `FavoriteHeart` — `lib/ui/core/widgets/favorite_heart.dart` (UI doc §5.3)

- Outlined (`outline` stroke) ↔ filled (`favorite` rose); 24-px icon inside a **44 × 44** hit area.
- Toggle applies **immediately** with a subtle scale-bounce (1.0 → 1.15 → 1.0, **200 ms, ease-out**) and no navigation (FR-4.8, FR-6.8, FR-9.3).
- **Screen-reader label:** "Add to favorites" when off, "Remove from favorites" when on (exact strings).
- Respects reduced motion (UI doc §7: collapses to a plain swap/crossfade).

## Definition of done

**Build** (standard gate): all items pass.

**Widget test constraints** — `test/ui/widgets/` (`WidgetTester`):

- [ ] **WardrobeImage (loaded):** given an existing image file (temp dir), renders the photo; grid and detail sizes both hold the 4:5 ratio.
- [ ] **WardrobeImage (lazy):** shows the neutral `surface` tile while decoding (no spinner).
- [ ] **WardrobeImage (missing):** `imagePath == null` (wearable) renders the type placeholder; an absent file renders the same (no error widget, no exception).
- [ ] **WearableTypePlaceholder:** each of the 6 `WearableType` values renders its own icon on the `secondary`-tinted tile (6 assertions).
- [ ] **WardrobeCard (outfit/wearable):** renders image + name (+ type for wearables) and the heart top-right; missing wearable image falls back to the placeholder.
- [ ] **Card targets:** tapping the card fires `onTap` exactly once and `onToggleFavorite` zero times; tapping the heart fires `onToggleFavorite` exactly once and `onTap` zero times (the 44 × 44 independence).
- [ ] **Hover/pressed:** hover state activates on pointer enter (simulated), pressed state on tap-down.
- [ ] **FavoriteHeart:** outline → filled on toggle; the semantic label switches between "Add to favorites" / "Remove from favorites"; the bounce animation runs 200 ms ease-out (and is skipped when reduced motion is enabled).
- [ ] **Hit area:** the heart's tappable region is ≥ 44 × 44 logical px (hit-test at the padded corners).

**Functional acceptance**

- [ ] All four widgets live in `lib/ui/core/widgets/` and consume only `AppTheme` tokens (011) + immutable domain models (002) — no repository access, no `setState` for domain state.
- [ ] Both light and dark themes render correctly (one test per widget in each mode).

**Out of scope for this task:** lists/grids (018/019), Home (017), the filter bar (014), motion beyond the documented micro-interactions (the full audit is 028).
