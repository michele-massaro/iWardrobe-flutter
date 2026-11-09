# iWardrobe — Functional specification

| | |
|---|---|
| **Version** | 1.0 (v1 / MVP) |
| **Date** | 8 November 2026 |
| **Status** | Approved as the reference for design and implementation |
| **Companion documents** | [Documentation index](README.md) · [Architecture](architecture.md) · [Data model & local database](data-model-and-database.md) · [iCloud sync](icloud-sync.md) · [Responsive design](responsive-design.md) · [UI & design language](ui-design.md) |

## 1. Overview & purpose

iWardrobe is a personal wardrobe management app for smartphones, tablets, and Mac. A user catalogs their clothing items — each called a **wearable** — with a photo and details (type, color, size, brand, material, tags), composes those wearables into named **outfits**, and marks the outfits and clothes they love as **favorites**. A Home dashboard surfaces the latest added outfits, the favorite outfits, and the favorite clothes, so the app opens directly on what the user cares about.

The app is built around three values:

- **Private by design.** There is no account, no server, and no remote API. The wardrobe lives in an internal database on the device, and images are stored as local files. The only replication is the user's own iCloud on Apple platforms (see [iCloud sync](icloud-sync.md)).
- **Useful every day.** Fast discovery through name, type, color, and tag filters, and one-tap favorites keep preferred looks reachable in two taps.
- **Cozy and personal.** The interface is warm, approachable, and aligned with a personal wardrobe, not a productivity tool (see [UI & design language](ui-design.md)).

The audience is the individual user of a single device (or a set of Apple devices under one Apple account) who wants one complete, searchable place for their wardrobe and their outfit ideas.

This document defines **what** iWardrobe does. It is intentionally free of implementation detail; **how** the app is built is covered by [Architecture](architecture.md) (MVVM + Repository layering, `provider` state management, `go_router` navigation), [Data model & local database](data-model-and-database.md) (`drift`/SQLite storage and local image files), [iCloud sync](icloud-sync.md), [Responsive design](responsive-design.md), and [UI & design language](ui-design.md).

## 2. Target platforms & form factors

iWardrobe is a single Flutter codebase targeting four platform/form-factor combinations. The smartphone experience is the primary design target; tablet and desktop experiences must be equally first-class.

| Platform | Form factor | Role | iCloud sync |
|---|---|---|---|
| iOS (iPhone) | Smartphone | **Primary target** | Yes |
| iPadOS (iPad) | Tablet | Supported, first-class | Yes |
| macOS | Desktop (Mac) | Supported, first-class | Yes |
| Android | Smartphone / tablet | Supported | **No — local data only** |

- **Mobile-first, responsive everywhere.** The app is designed for the phone first, but must adapt its layout to tablet and Mac window sizes (breakpoints on window width, not device type; see [Responsive design](responsive-design.md)).
- **iCloud sync is Apple-platforms only.** On iOS, iPadOS, and macOS the app syncs the database and the images to the user's iCloud with the `icloud_storage_sync` package so the wardrobe is available on every device signed in to the same Apple account (see [iCloud sync](icloud-sync.md)). Android builds contain the full feature set **except** sync: all data stays on the device, and no sync settings or status UI is shown.
- **Orientation and windows.** The app never locks screen orientation and adapts to any window size, including resizable Mac windows and iPad multitasking (Split View, Slide Over).
- **Input methods.** Touch on phones and tablets; mouse, trackpad, and basic keyboard operation on Mac. All interactive elements must work with pointer input and meet the touch-target rules in Section 8.

## 3. Glossary

| Term | Definition |
|---|---|
| **Wardrobe** | The complete collection of wearables belonging to the user in this installation of the app. |
| **Wearable** | A single clothing item or accessory owned by the user (for example, a shirt, trousers, a dress, sneakers, or a scarf). In UI copy aimed at users, wearables may also be called "clothes" (as in the "Favorite clothes" section). |
| **Outfit** | A named, saved combination of wearables that represents a complete look. An outfit always contains at least one wearable. |
| **Color** | A predefined color value (for example, Black, White, Navy, Blue) assigned to a wearable and used by the color filters. |
| **Tag** | A short user-defined label (for example, "work", "summer", "denim") that can be attached to a wearable for organization and filtering. |
| **Favorite** | A persistent "heart" flag on an outfit or a wearable that pins it to the Home dashboard. |
| **Onboarding** | The three-page introduction shown once, on the first launch after installation. |
| **Sync** | The automatic, bidirectional replication of the wardrobe database and image files to the user's iCloud on Apple platforms. |

## 4. Feature inventory

Priority legend: **P0** = core, must be present in v1; **P1** = MVP feature, platform-bounded; **P2** = optional stretch (marked "Optional" where used).

| ID | Feature | Description | Priority | Requirements |
|---|---|---|---|---|
| F-01 | Onboarding | Three-page first-launch introduction to the app's purpose | P1 | FR-1.1 – FR-1.8 |
| F-02 | Main navigation | Three-tab navigation (Home, Outfits, Wearables) with per-tab state preservation | P0 | FR-2.1 – FR-2.5 |
| F-03 | Home dashboard | Latest outfits carousel, favorite outfits, favorite clothes, empty states | P0 | FR-3.1 – FR-3.7 |
| F-04 | Outfit list | Scrollable list of all outfits, filterable by name, color, and tag | P0 | FR-4.1 – FR-4.11 |
| F-05 | Outfit details | Image, outfit details, and the list of composing wearables | P0 | FR-5.1 – FR-5.7 |
| F-06 | Wearable list | Scrollable list of all wearables, filterable by type, color, name, and tag | P0 | FR-6.1 – FR-6.11 |
| F-07 | Wearable details | Photo-dominant detail page with all item information | P0 | FR-7.1 – FR-7.5 |
| F-08 | Add / edit / delete | Full CRUD for outfits and wearables with explicit delete confirmation and cascade rules | P0 | FR-8.1 – FR-8.12 |
| F-09 | Favorites | Persistent heart flag on outfits and wearables, surfaced on Home | P0 | FR-9.1 – FR-9.6 |
| F-10 | iCloud sync | Bidirectional sync of database and images, Apple platforms only | P1 | FR-10.1 – FR-10.7 |
| F-11 | Local offline storage | Internal SQLite database and local image files; no server, no account | P0 | FR-11.1 – FR-11.4 |

## 5. Functional requirements

Requirement IDs are stable and referenced by other documents in this set and by tests. Wording uses "shall" for normative behavior; parenthetical `(Optional, P2)` marks stretch behavior that is not part of the v1 baseline. Assumptions made by this specification are collected in Section 5.12 and cited as A-1 … A-11.

### 5.1 Onboarding (F-01)

- **FR-1.1** On the first launch after a fresh installation, the app shall present the onboarding flow; on every subsequent launch it shall not.
- **FR-1.2** The onboarding flow shall consist of exactly three pages, in this order: (1) *Catalog your wardrobe* — add a photo and the details of every item you own; (2) *Compose outfits* — combine wearables into named, reusable looks; (3) *Stay in sync* — on iPhone, iPad, and Mac, the wardrobe and its images are kept in the user's iCloud and available on every device signed in to the same Apple account.
- **FR-1.3** Each onboarding page shall show a title, a short explanatory text, and a position indicator ("1 of 3", "2 of 3", "3 of 3").
- **FR-1.4** Pages 1 and 2 shall offer a **Next** action that advances to the following page and a **Skip** action that dismisses onboarding and opens the Home tab.
- **FR-1.5** Page 3 shall offer a **Get started** action and a **Skip** action; both dismiss onboarding and open the Home tab.
- **FR-1.6** Once the user has completed onboarding (via *Skip* or *Get started*), the app shall never present onboarding again on subsequent launches.
- **FR-1.7** The onboarding-completed flag shall persist across app restarts and device reboots.
- **FR-1.8** *(Optional, P2)* The app may offer a setting that re-presents the onboarding flow without altering any wardrobe data (see A-11).

### 5.2 Main navigation (F-02)

- **FR-2.1** The main screen shall present a tab bar containing exactly three tabs, in this order: **Home**, **Outfits**, **Wearables**.
- **FR-2.2** Selecting a tab shall display that section's screen and mark the tab as selected; the other tabs shall remain available at all times while a tabbed screen is showing.
- **FR-2.3** When the user switches away from a tab and later returns to it, the tab shall restore its previous state, including scroll position, active filters, and loaded content (implemented with per-branch state, see [Architecture](architecture.md)).
- **FR-2.4** Navigating from a tab to a detail page shall keep the active tab as the current one; when the user navigates back, the same tab shall be shown in the same state.
- **FR-2.5** The three sections, their order, and the state-preservation behavior of FR-2.3 shall be identical on every form factor; on wide windows (tablet, Mac) the navigation presentation may adapt (for example, a side rail instead of a bottom bar) without changing the functional behavior (see [Responsive design](responsive-design.md)).

### 5.3 Home (F-03)

- **FR-3.1** The Home page shall present exactly three sections, in this order: **Latest outfits**, **Favorite outfits**, **Favorite clothes**.
- **FR-3.2** The *Latest outfits* section shall show the 10 most recently created outfits (A-4) in a horizontally scrolling carousel; tapping an item shall open that outfit's detail page.
- **FR-3.3** The *Favorite outfits* section shall show all favorited outfits in a grid; tapping an item shall open that outfit's detail page.
- **FR-3.4** The *Favorite clothes* section shall show all favorited wearables in a grid; tapping an item shall open that wearable's detail page.
- **FR-3.5** When a section has no items, it shall remain visible with a short, section-specific empty message (for example, "No favorite outfits yet — tap the heart on any outfit"); the other sections shall not be affected.
- **FR-3.6** When the wardrobe contains no outfits and no wearables, Home shall show a welcoming empty state that explains what the app does and offers calls to action to add the first wearable and to compose the first outfit.
- **FR-3.7** The Home sections shall update immediately when the user creates, edits, deletes, or changes the favorite state of any item anywhere in the app.

### 5.4 Outfit list & filters (F-04)

- **FR-4.1** The Outfits page shall present a scrollable list of **all** outfits, newest first (A-3).
- **FR-4.2** Each list item shall show the outfit image, the outfit name, and a heart icon reflecting the current favorite state.
- **FR-4.3** The Outfits page shall provide a text search that matches outfit names case-insensitively by substring.
- **FR-4.4** The Outfits page shall provide a color filter; an outfit matches the filter when at least one wearable that composes it has the selected color (A-1).
- **FR-4.5** The Outfits page shall provide a tag filter with one or more selectable tags; an outfit matches when at least one wearable that composes it carries any of the selected tags (A-1, A-2).
- **FR-4.6** When more than one filter dimension is active (name, color, tag), an outfit shall match only if it satisfies **all** active dimensions; within the tag dimension, the selected tags shall combine with OR.
- **FR-4.7** The Outfits page shall provide a *Clear filters* action that resets all filters and restores the full list.
- **FR-4.8** Tapping the heart icon on a card shall toggle the outfit's favorite state immediately, with visible feedback (filled versus outlined heart), without navigating away from the list.
- **FR-4.9** Tapping any other part of a card shall open the outfit's detail page.
- **FR-4.10** When active filters exclude every outfit, the page shall show a *no results* state that names the active filters and offers *Clear filters*; this state shall be visually distinct from the empty-wardrobe state of FR-4.11.
- **FR-4.11** When the wardrobe contains no outfits at all, the page shall show an empty state with a call to action to create the first outfit.

### 5.5 Outfit details (F-05)

- **FR-5.1** The outfit detail page shall show the outfit image as the dominant visual element at the top of the page.
- **FR-5.2** The page shall show the outfit name.
- **FR-5.3** The page shall show the outfit's description, occasion, season, and notes (each optional; an optional field shall be displayed only when set) and shall always show the creation date and the last-updated date.
- **FR-5.4** Below the details, the page shall list **every** wearable that composes the outfit; each entry shall show a thumbnail, the wearable name, and the wearable type; a composing wearable without an image shall show a type-based placeholder instead of a thumbnail.
- **FR-5.5** Tapping a composing wearable shall open its detail page; navigating back shall return to the same outfit detail page in the same state.
- **FR-5.6** The page shall show the outfit's current favorite state and provide a heart toggle that is consistent with the one on the list card.
- **FR-5.7** The page shall provide **Edit** and **Delete** actions for the outfit (see FR-8.5 and FR-8.7).

### 5.6 Wearable list & filters (F-06)

- **FR-6.1** The Wearables page shall present a scrollable list (grid layout on wide windows) of **all** wearables added by the user, newest first (A-3).
- **FR-6.2** Each item shall show the wearable image (or a type-based placeholder when the wearable has no image, A-7), the name, and the type.
- **FR-6.3** The Wearables page shall provide a text search that matches wearable names case-insensitively by substring.
- **FR-6.4** The Wearables page shall provide a type filter whose option set is exactly: **Top, Bottom, Dress, Jacket, Shoes, Accessory** (A-5); a wearable matches when its type equals the selected type.
- **FR-6.5** The Wearables page shall provide a color filter; a wearable matches when its color equals the selected color (a wearable with no color set never matches, A-8).
- **FR-6.6** The Wearables page shall provide a tag filter; a wearable matches when it carries any of the selected tags.
- **FR-6.7** Active filter dimensions shall combine with AND; within the tag dimension, selected tags shall combine with OR; a *Clear filters* action shall be available.
- **FR-6.8** Tapping the heart icon on a card shall toggle the wearable's favorite state immediately, with visible feedback, without navigating away.
- **FR-6.9** Tapping any other part of a card shall open the wearable's detail page.
- **FR-6.10** When active filters exclude every wearable, the page shall show a *no results* state (visually distinct from the empty-wardrobe state) that offers *Clear filters*.
- **FR-6.11** When the wardrobe contains no wearables at all, the page shall show an empty state with a call to action to add the first wearable.

**Filter matrix** (per list page; control semantics per A-2):

| Filter dimension | Outfits page | Wearables page | Matching rule |
|---|---|---|---|
| Name (text) | Yes | Yes | Case-insensitive substring of the item name |
| Color | Yes (derived from composing wearables, A-1) | Yes (own color field) | Item has the selected color |
| Type | No | Yes | Wearable type equals the selected type |
| Tag | Yes (derived from composing wearables, A-1) | Yes | Item carries any selected tag (OR within dimension) |
| Combination | AND across dimensions | AND across dimensions | Active dimensions must all be satisfied |

### 5.7 Wearable details (F-07)

- **FR-7.1** The wearable detail page shall present the item's picture as the dominant visual element at the top of the page; when the wearable has no picture (allowed by A-7), the same position shall show a type-based placeholder.
- **FR-7.2** The page shall show the name, the type, the color (when set), size, brand, material, and notes (size, brand, material, and notes are optional and displayed only when set), plus the full list of tags.
- **FR-7.3** The page shall show the wearable's favorite state and provide a heart toggle consistent with the one on the list card.
- **FR-7.4** The page shall show the creation date and the last-updated date.
- **FR-7.5** The page shall provide **Edit** and **Delete** actions (see FR-8.5 and FR-8.7).

### 5.8 Add, edit, delete (CRUD) (F-08)

- **FR-8.1** The Outfits and Wearables pages shall each provide a primary *add* action (floating action button on compact screens; an equivalent toolbar action on wide windows, see [Responsive design](responsive-design.md)) that opens the respective creation form.
- **FR-8.2** The outfit creation form shall require: an image (A-7), a name, and the selection of at least one wearable from the wardrobe (A-6); description, occasion, season (one of Spring, Summer, Autumn, Winter, All seasons — A-9), and notes shall be optional.
- **FR-8.3** The wearable creation form shall require a name and a type from the set in FR-6.4; image (A-7), color (A-8), size, brand, material, notes, and tags shall be optional.
- **FR-8.4** The app shall not submit a form while a required field is missing and shall show an inline error naming the missing requirement.
- **FR-8.5** Editing an outfit or a wearable shall be available from its detail page; the edit form shall be pre-filled with the current values, and saving shall update the record and its last-updated date.
- **FR-8.6** When editing an outfit, the user may replace the image, but an outfit shall always retain an image (A-7); when editing a wearable, the user may remove the image, after which the placeholder of FR-7.1 applies.
- **FR-8.7** Deleting an item shall require an explicit confirmation dialog that names the item and, when the item is a wearable, states how many outfits it will be removed from (and, where applicable, that any outfit left with no wearables will be deleted — FR-8.9).
- **FR-8.8** Deleting a wearable shall remove it from every outfit that contains it; each affected outfit shall keep its remaining wearables.
- **FR-8.9** If deleting a wearable leaves an outfit with zero wearables, the app shall delete that now-empty outfit as part of the same operation (A-6).
- **FR-8.10** Deleting an outfit shall **not** delete any of its wearables.
- **FR-8.11** After any create, edit, or delete, every affected screen (both lists, the Home sections, and open or subsequently opened detail pages) shall reflect the change immediately.
- **FR-8.12** A newly created item shall appear first in the newest-first lists (FR-4.1, FR-6.1); a newly created outfit shall also appear in Home's *Latest outfits* section (FR-3.2).

### 5.9 Favorites (F-09)

- **FR-9.1** The favorite state shall be a boolean flag stored with each outfit and each wearable in the local database (see [Data model & local database](data-model-and-database.md)).
- **FR-9.2** The favorite toggle shall be available on the outfit list cards, the outfit detail page, the wearable list cards, and the wearable detail page.
- **FR-9.3** Toggling the favorite state shall apply immediately with visible feedback (filled versus outlined heart) and without navigation.
- **FR-9.4** The favorite state shall persist across app restarts and device reboots.
- **FR-9.5** Favorited outfits shall appear in Home's *Favorite outfits* section and favorited wearables in *Favorite clothes*; removing the favorite state shall remove the item from the respective section immediately.
- **FR-9.6** *(Optional, P2)* The Outfits and Wearables pages may provide a "favorites only" quick filter that shows only favorited items.

### 5.10 iCloud sync (F-10)

- **FR-10.1** On Apple platforms (iOS, iPadOS, macOS), the app shall synchronize the complete wardrobe — database records (outfits, wearables, outfit–wearable composition, favorite flags) and image files — to the user's iCloud, using the `icloud_storage_sync` package.
- **FR-10.2** Synchronization shall be bidirectional: local changes shall be uploaded, and changes made on other devices shall be merged into the local database and image store.
- **FR-10.3** A second device, signed in to the same Apple account and running iWardrobe, shall present the same outfits, wearables, favorite flags, and images (subject to the conflict policy in [iCloud sync](icloud-sync.md)).
- **FR-10.4** The app shall remain fully usable while offline; pending changes shall be synchronized automatically as soon as the network and iCloud are available again.
- **FR-10.5** On Apple platforms the app shall display the time of the last successful sync in a lightweight indicator; on Android no synchronization status or settings UI shall be shown.
- **FR-10.6** On Android, all features of Sections 5.1 – 5.9 and 5.11 shall work with local data only; no feature shall depend on synchronization.
- **FR-10.7** Conflicts for the same item edited on two devices shall be resolved with last-writer-wins by update timestamp (A-10; details in [iCloud sync](icloud-sync.md)).

### 5.11 Local data & offline operation (F-11)

- **FR-11.1** The app shall store all wardrobe data in an internal SQLite database (implemented with `drift`) and all images as files in the app's documents directory; it shall use no remote APIs and no server (see [Data model & local database](data-model-and-database.md)).
- **FR-11.2** Every core feature (onboarding, navigation, lists, detail pages, filters, CRUD, favorites) shall work with the device in airplane mode.
- **FR-11.3** The app shall not collect, transmit, or require any user account or personal data.
- **FR-11.4** On every launch, the app shall restore the wardrobe exactly in its last saved state.

### 5.12 Assumptions

The following decisions are made by this specification so that the requirements above are unambiguous. They are flagged for product-owner review.

| ID | Assumption |
|---|---|
| A-1 | Outfit color and tag filters are evaluated against the wearables that compose the outfit; the outfit entity itself has no color or tag fields. |
| A-2 | Name search is a case-insensitive substring match; color and type filters are single-select chips with an "All" default; the tag filter is multi-select, and selected tags combine with OR. |
| A-3 | All lists are ordered by creation date, descending (newest first). |
| A-4 | Home's *Latest outfits* section shows the 10 most recently created outfits. |
| A-5 | The wearable type set is exactly: Top, Bottom, Dress, Jacket, Shoes, Accessory. |
| A-6 | An outfit must contain at least one wearable; if its last remaining wearable is deleted, the now-empty outfit is deleted as well. |
| A-7 | An image is required for outfits (at creation and at all times) and optional for wearables (a type-based placeholder is shown when absent). |
| A-8 | The wearable color is optional; a wearable without a color never matches a color filter. |
| A-9 | The season field takes one of: Spring, Summer, Autumn, Winter, All seasons. |
| A-10 | Sync conflicts on the same item are resolved last-writer-wins by update timestamp. |
| A-11 | Re-showing onboarding (FR-1.8) is an optional stretch feature, not part of the v1 baseline. |

## 6. User stories

1. As a new user, I want a short onboarding on my first launch so that I understand what the app can do before I start adding clothes.
2. As a user, I want to add a clothing item with its photo and details so that my wardrobe is fully cataloged in one place.
3. As a user, I want to compose a named outfit from wearables I already cataloged so that I can save a complete look and reuse it later.
4. As a user, I want to filter outfits by color so that I can quickly find looks that match a specific shade.
5. As a user, I want to search wearables by name so that I can find a specific item even in a large wardrobe.
6. As a user, I want to filter wearables by type and tags so that I can narrow down, for example, to all my work jackets.
7. As a user, I want to mark outfits and clothes as favorites so that my preferred looks are always one tap away on Home.
8. As a user, I want a Home screen that summarizes my latest and favorite items so that I land on what I care about most.
9. As a user, I want to edit an item's details so that I can fix a typo or update information without recreating it.
10. As a user, I want a confirmation before a delete so that I never lose an item by accident and I always see what a delete affects.
11. As an iPhone user, I want my wardrobe and photos to sync to iCloud so that I find the same items on my iPad and my Mac.
12. As a user, I want the app to work fully offline so that I never need a network connection or an account to manage my wardrobe.

## 7. Key user flows

### 7.1 First launch and onboarding

1. The user installs iWardrobe and taps the app icon.
2. The app shows onboarding page 1 (*Catalog your wardrobe*) with the "1 of 3" indicator, plus **Next** and **Skip** (FR-1.3, FR-1.4).
3. The user taps **Next**; page 2 (*Compose outfits*) is shown.
4. The user taps **Next**; page 3 (*Stay in sync*) is shown with **Get started** (FR-1.5).
5. The user taps **Get started**; onboarding is dismissed and the Home tab opens (FR-1.5).
6. Because the wardrobe is empty, Home shows the welcoming empty state with calls to action to add the first wearable and compose the first outfit (FR-3.6).
7. On the next launch the app opens directly on Home; onboarding is not shown again (FR-1.6, FR-1.7).
8. *Variation:* the user may tap **Skip** on any page, which jumps to step 5.

### 7.2 Adding the first wearable

1. From the Home empty state (or the Wearables tab), the user taps **Add wearable** (FR-8.1, FR-6.11).
2. The wearable creation form opens (FR-8.3).
3. The user takes or selects a photo (optional, A-7), enters the name "Blue shirt", selects type **Top**, color **Blue**, size **M**, and optionally adds brand, material, and the tag "casual".
4. The user taps **Save**; validation passes (FR-8.4).
5. The new wearable appears first in the Wearables list (FR-6.1, FR-8.12).
6. The user navigates to another tab and back; the Wearables tab restores its previous state, and the new item is visible (FR-2.3).

### 7.3 Composing the first outfit

1. The user opens the Outfits tab, sees the empty state, and taps **Create your first outfit** (FR-4.11); the add action (FR-8.1) opens the outfit creation form.
2. The form asks for an outfit image (required, A-7), a name, and a selection of one or more wearables (required, A-6); the user selects the *Blue shirt*, a pair of jeans, and sneakers, then enters the name "Casual Friday", occasion "Work casual", season **All seasons** (A-9), and an optional note.
3. The user taps **Save**; the outfit appears first in the Outfits list (FR-4.1) and in Home's *Latest outfits* carousel (FR-3.2, FR-8.12).
4. The user taps the new card; the detail page shows the image, the name, the details and dates, and the three composing wearables with thumbnail, name, and type (FR-5.1 – FR-5.4).
5. Tapping the jeans entry opens the jeans' wearable detail page; navigating back returns to the same outfit detail (FR-5.5).

### 7.4 Finding an outfit by color

1. The user opens the Outfits tab, which lists all outfits newest first (FR-4.1).
2. The user opens the filter bar and selects the color **Navy** (single-select, A-2); the list immediately narrows to outfits that contain at least one navy wearable (FR-4.4).
3. The user adds the tag **work**; the list narrows further — the outfit must satisfy both the color and the tag dimension (FR-4.5, FR-4.6).
4. No outfit matches, so the page shows the *no results* state with the active filters named and a **Clear filters** action (FR-4.10).
5. The user taps **Clear filters**; the full list is restored (FR-4.7).
6. The user taps the desired outfit card (anywhere except the heart) and lands on its detail page (FR-4.9).

### 7.5 Favoriting an outfit from the list

1. On the Outfits list, the user taps the heart icon on the "Casual Friday" card.
2. The heart fills immediately without navigation, and the favorite flag is saved with the record (FR-4.8, FR-9.1, FR-9.3).
3. The user taps the Home tab; "Casual Friday" now appears in *Favorite outfits* (FR-9.5).
4. The user restarts the app; the favorite is still set (FR-9.4).

### 7.6 Seeing favorites on Home

1. The user opens the Home tab.
2. The three sections are shown in order: *Latest outfits* (horizontal carousel of the 10 most recent outfits, FR-3.2), *Favorite outfits* (grid of favorited outfits, FR-3.3), *Favorite clothes* (grid of favorited wearables, FR-3.4).
3. Sections without items show their short empty messages and stay in place (FR-3.5).
4. Tapping a favorite outfit opens its detail; tapping a favorite wearable opens the wearable detail (FR-3.3, FR-3.4).
5. The user unfavorites a wearable from its detail page; it disappears from *Favorite clothes* immediately (FR-9.3, FR-9.5, FR-3.7).

> **Cross-reference:** the end-to-end sync flow — for example, adding an outfit on an iPhone and finding it, with its images, on an iPad and a Mac under the same Apple account — is specified in [iCloud sync](icloud-sync.md), which is planned in this documentation set.

## 8. Non-functional requirements

| ID | Requirement |
|---|---|
| **NFR-1 — Offline-first** | The app is fully usable with no network connection (FR-11.2). No feature may require connectivity; synchronization on Apple platforms is an enhancement that happens in the background and degrades gracefully offline (FR-10.4). |
| **NFR-2 — Local privacy** | There are no accounts, no server, and no remote APIs (FR-11.3). Wardrobe data and images remain on the device and, on Apple platforms, only in the user's own iCloud (FR-10.1). No analytics or telemetry is collected or transmitted. |
| **NFR-3 — Performance** | List scrolling shall remain smooth at 60 fps on supported hardware. Lists and grids shall be rendered lazily, and images shall be loaded lazily with placeholders shown while loading. Filter application shall update the visible list without perceptible delay. |
| **NFR-4 — Accessibility** | Every interactive element shall have a touch target of at least 44 × 44 logical pixels. Text and icon colors shall meet readable contrast ratios. Every interactive element shall expose a screen-reader label, and the UI shall support the system's text-size settings. |
| **NFR-5 — Cozy visual language** | The interface shall feel warm, personal, and calm, aligned with a personal wardrobe rather than a generic productivity tool; colors, typography, components, and empty states are defined in [UI & design language](ui-design.md). |
| **NFR-6 — Responsiveness** | The app shall adapt to window width (not device type) across smartphone, tablet, and Mac, including resizable Mac windows and iPad multitasking, without layout breakage or locked orientations (see [Responsive design](responsive-design.md)). |

## 9. Out of scope for v1

The following are explicitly **not** part of the v1 release:

| Item | Reason |
|---|---|
| iCloud sync on Android | iCloud is an Apple service and unavailable on Android; Android builds are local-only by design (FR-10.6). |
| Sharing and social features | No sharing of outfits, no public profiles, no comments — v1 is a personal wardrobe. |
| Third-party logins | No Apple ID sign-in, Google, or any other login; the app is account-free (FR-11.3). |
| Analytics and telemetry | No usage tracking and no data transmission of any kind (NFR-2). |
| Multi-user / household sharing | One wardrobe per installation; no profiles, roles, or shared wardrobes. |
| Price and stock tracking | No purchase prices, no restock reminders, no inventory management. |

## 10. Acceptance criteria

A build of iWardrobe v1 is accepted when all of the following hold:

- [ ] Onboarding is shown on the first launch after install and is never shown again once completed via **Skip** or **Get started** (FR-1.1, FR-1.5, FR-1.6, FR-1.7).
- [ ] The main tab bar contains exactly three tabs — Home, Outfits, Wearables — in that order, and each tab restores its state (scroll position, active filters) when the user returns to it (FR-2.1, FR-2.3).
- [ ] Home shows the *Latest outfits*, *Favorite outfits*, and *Favorite clothes* sections in that order, with per-section empty messages and a welcoming empty state for a brand-new wardrobe (FR-3.1 – FR-3.6).
- [ ] The Outfits list shows all outfits and its filters work by name, color, and tag, with AND across dimensions, OR within tags, and a working *Clear filters* action (FR-4.3 – FR-4.7).
- [ ] The heart toggle on both list pages applies immediately with visible feedback and persists across an app restart (FR-4.8, FR-6.8, FR-9.3, FR-9.4).
- [ ] The Outfit details page shows the image, the name, the details and dates, and every composing wearable with thumbnail, name, and type, each tappable to its detail page (FR-5.1 – FR-5.5).
- [ ] The Wearables list shows all wearables and its filters work by type, color, name, and tag, with a *no results* state that is distinct from the empty-wardrobe state (FR-6.3 – FR-6.7, FR-6.10, FR-6.11).
- [ ] The Wearable details page shows the picture (or placeholder) as the dominant element plus name, type, color, size, brand, material, notes, and tags (FR-7.1 – FR-7.2).
- [ ] CRUD works for both entities: add from the list pages, edit from the detail pages, delete with explicit confirmation; deleting a wearable removes it from all containing outfits (deleting the last one deletes the now-empty outfit), and deleting an outfit keeps its wearables (FR-8.2 – FR-8.10).
- [ ] The app is fully usable offline — every feature works in airplane mode, and no data is transmitted anywhere (FR-11.2, FR-11.3, NFR-1, NFR-2).
- [ ] On Apple platforms, outfits, wearables, favorite flags, and images added on one device appear on a second device signed in to the same Apple account (see [iCloud sync](icloud-sync.md)).
