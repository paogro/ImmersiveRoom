# 3DContent/Rooms — Structure & Developer Reference

This folder contains everything that makes up the immersive 3D room experience. The original monolithic `GenericRoomView.swift` (~1 200 lines) was split into focused files. All files are extensions or types within the same Xcode target — no new modules were introduced.

---

## File Tree

```
3DContent/Rooms/
├── GenericRoomView.swift       ← struct declaration, all @State, body, RealityView
├── RoomViewModel.swift         ← navigation functions (extension on GenericRoomView)
├── RoomGestures.swift          ← gesture handlers + ring/momentum helpers (extension)
├── Views/
│   ├── ThemaPanelView.swift    ← individual topic card (root carousel + child cards)
│   ├── CrumbPanelView.swift    ← breadcrumb navigation pill
│   ├── LesePanelView.swift     ← detail/reading overlay panel
│   └── ZurueckButtonView.swift ← home/back button (logo image)
└── Extensions/
    └── ViewExtensions.swift    ← shared View modifiers + RingPanelMarker component
```

---

## GenericRoomView.swift

**What lives here:** The `GenericRoomView` struct declaration — the entry point for the entire room. This file owns everything that Swift requires to be in the struct itself.

### Properties

| Property | Type | Purpose |
|---|---|---|
| `skyboxTextureName` | `String` | Equirectangular texture loaded at startup (e.g. `"sport_equirectangular"`) |
| `appModel` | `AppModel` | Environment object — provides `ausgewaehltesThema` (the selected top-level category) |
| `openWindow` | `OpenWindowAction` | Environment action — used by `ZurueckButtonView` to reopen the main window |
| `aktuelleThemen` | `[Thema]` | The topic cards currently shown in the ring (root level or sibling level during back-nav) |
| `fokusThema` | `Thema?` | The currently focused/drilled-into topic; `nil` means root carousel mode |
| `childrenThemen` | `[Thema]` | Children of `fokusThema`, shown when in focus mode |
| `pfad` | `[Thema]` | Ancestor stack — grows on forward nav, shrinks on back nav |
| `status` | `String` | Debug label text shown at top of scene |
| `leseThema` / `leseModusAktiv` | `Thema?` / `Bool` | The topic whose detail overlay is open |
| `panelsEingeblendet` | `Bool` | Drives the opacity+scale spring animation when cards mount |
| `aktuellerIndex` | `Int` | Index of the card currently at the front of the ring |
| `baumScale` / `scaleStart` | `Float` | Pinch-to-zoom scale of the whole scene |
| `aktivGehaltenesPanel` | `String?` | Name of the panel currently being held (for hold-to-read feedback) |
| `holdTask` / `holdTriggered` | `Task` / `Bool` | Hold-gesture timer and its fire flag |
| `breadcrumbExpanded` | `Bool` | Whether the breadcrumb stack is expanded into a vertical list |
| `navigiertTiefer` | `Bool` | Direction flag: `true` = forward, `false` = back — controls fly-in Y offset direction |
| `rootEntity` | `Entity` | Parent RealityKit entity for breadcrumbs, lese-panel, home button |
| `ringEntity` | `Entity` | Child of `rootEntity`; rotating this spins all topic cards together |
| `ringAngle` | `Float` | Current settled rotation of the ring (radians around Y axis) |
| `ringDragActive/StartAngle/LastX/LastTime` | various | Drag tracking state for the swipe gesture |
| `ringVelocity` | `Float` | Smoothed angular velocity at drag release, used for momentum glide |
| `ringInteracting` | `Bool` | When `true`, the `update` closure skips writing `ringAngle` to avoid fighting the gesture |
| `momentumTask` | `Task?` | Currently running glide+snap momentum task |
| `ringDragSensitivity` | `Float = 2.5` | Radians of ring rotation per metre of horizontal drag |
| `ringMomentumDamping` | `Float = 0.5` | Velocity multiplier per ~16ms tick during glide |
| `ringMomentumMinSpeed` | `Float = 2.5` | rad/s below which momentum stops and snap begins |

### Computed Properties

| Property | Returns | Purpose |
|---|---|---|
| `isRootLevel` | `Bool` | `true` when `fokusThema == nil` (gallery mode) |
| `sichtbareThemen` | `[Thema]` | Returns `childrenThemen` in focus mode, else `aktuelleThemen` |

### body / RealityView

The `body` contains a single `RealityView` with three closures:

**`make` closure** — runs once at startup:
- Loads the equirectangular skybox sphere (radius 50, X-flipped for inside view)
- Adds `rootEntity` and `ringEntity` to the scene
- Registers `RingPanelMarker` as a RealityKit component
- Positions the debug label and home button attachment

**`update` closure** — re-runs on every `@State` change:
- If `leseModusAktiv`: positions and mounts the lese-panel, returns early (hides everything else)
- Breadcrumb stack: positions each `crumb_` attachment in either collapsed stack or expanded vertical list mode
- Ring positioning: places each topic card at its ring angle, sets initial Y-offset fly-in position for new panels, calls `move(to:)` to animate into place
- Home button: moves `zurueck_btn` to the right world position depending on focus/expanded state

**`attachments` block** — declares which SwiftUI views are anchored in 3D:
- `"debug"` → status text label
- `"zurueck"` → `ZurueckButtonView`
- `"crumb_<uuid>"` → `CrumbPanelView` (one per breadcrumb ancestor)
- `"lese_<uuid>"` → `LesePanelView`
- `"thema_<uuid>"` → `themaPanel(...)` → `ThemaPanelView` (root carousel cards)
- `"child_<uuid>"` → `themaPanel(...)` → `ThemaPanelView` (focus-level child cards)

**`themaPanel()` helper** — private factory that computes `isGehalten` and `childHidden` from view state and forwards them into `ThemaPanelView`. Stays here because it reads `@State` directly.

### Key Animation Values (in the update closure)

| Value | Location | Meaning |
|---|---|---|
| `dur = isRootLevel ? 0.5 : 0.7` | update closure, new-panel branch | Fly-in slide duration; 0.7 s for focus-level cards, 0.5 s for root cards |
| `yOffset = navigiertTiefer ? 1.5 : -1.5` | update closure | Starting Y offset for fly-in: drops from above on forward nav, rises from below on back |
| `0.25` | existing-panel branch | Duration when only the `isFront` scale state changes |

---

## RoomViewModel.swift

**What lives here:** `extension GenericRoomView` with all data-loading and navigation logic. No UI, no gestures.

### Functions

| Function | Async | Purpose |
|---|---|---|
| `animierePanels(skipBounce:)` | no | Removes stale RealityKit entities that no longer belong in the current nav state, then triggers the `panelsEingeblendet` opacity+scale spring. Pass `skipBounce: true` on back-navigation so the spring doesn't double-animate with the RealityKit slide. |
| `ladeErsteEbene()` | yes | Called once on `.task {}` at startup. Resets all state to root, loads first-level children of `appModel.ausgewaehltesThema` via `ThemenService`. |
| `ladeChildren(vonThemaId:)` | yes | Low-level fetch: calls `ThemenService.getUnterthemen()`, writes result into `aktuelleThemen`. |
| `themaAusgewaehlt(thema:)` | yes | Handles tap on a root carousel card. If the topic has children → drill into focus mode. If leaf → open Lesemodus directly. |
| `childAusgewaehlt(thema:)` | yes | Handles tap on a focus-level child card. Pushes `fokusThema` onto `pfad`, replaces the ring with the new children. If leaf → Lesemodus. |
| `zurueckEineEbene()` | yes | Back one level. Pops `pfad`, restores the previous ring. If `pfad` is already empty, returns to root carousel. |
| `zurueckZuAncestor(thema:)` | yes | Jump directly to any ancestor in the breadcrumb stack (tapped from the expanded breadcrumb list). Reloads both the ancestor's children and its parent's sibling ring. |

### Navigation State Machine

```
Root carousel (fokusThema == nil)
  │  tap thema_  →  themaAusgewaehlt()
  ▼
Focus mode (fokusThema != nil, pfad grows)
  │  tap child_  →  childAusgewaehlt()
  ▼
Deeper focus / Lesemodus (leaf node)
  │  tap crumb_  →  zurueckEineEbene() or zurueckZuAncestor()
  ▼
Back to previous level or root
```

---

## RoomGestures.swift

**What lives here:** `extension GenericRoomView` with all four gesture computed properties and all ring/momentum helper functions.

### Gesture Properties

| Property | Gesture type | Trigger | Action |
|---|---|---|---|
| `tapGesture` | `SpatialTapGesture` | Quick tap on any entity | Routes by entity name prefix (`crumb_`, `thema_`, `child_`) to the right navigation call. Note: the lese panel is **not** handled here — it has no input target; closing is done in SwiftUI via `onClose`. |
| `swipeGesture` | `DragGesture(minimumDistance: 10)` | Horizontal drag anywhere in scene | Rotates `ringEntity` around Y axis in real time; on release, calls `starteMomentum()` |
| `holdGesture` | `DragGesture(minimumDistance: 0)` | Touch + hold for 450 ms without moving >4 cm | Fires `loeseLeseModusAus()` to open Lesemodus; sets `holdTriggered` to suppress the co-firing tap |
| `zoomGesture` | `MagnifyGesture` | Pinch | Scales the entire scene via `baumScale` (clamped 0.4–2.5×) |

### Ring & Momentum Helpers

| Function | Purpose |
|---|---|
| `aktualisiereFrontIndex()` | Derives which card index is currently at front (world angle 0) from `ringAngle`. Called every frame during drag and momentum. |
| `stopMomentum()` | Cancels any running `momentumTask`, clears `ringInteracting`. |
| `starteMomentum()` | Launches the glide+snap task. Phase 1: exponential velocity decay (`ringMomentumDamping`) until speed drops below `ringMomentumMinSpeed`. Phase 2: cubic-ease snap to the card that was at front at the moment of release (locked in at release time to prevent off-by-one). |
| `rotiereZuIndex(_:)` | Programmatic smooth rotation to a specific card index; takes the shortest arc direction. Used when navigating to a known index. |
| `loeseLeseModusAus(panelName:)` | Identifies which `Thema` is behind a `thema_` or `child_` panel name and opens Lesemodus for it. |

### Hold Gesture Detail

The hold gesture uses `DragGesture(minimumDistance: 0)` (not a long-press recognizer) so it can co-exist with the spatial tap. A 450 ms `Task.sleep` acts as the timer. If the finger moves more than 4 cm during the wait, the task is cancelled. On fire, `holdTriggered = true` tells `tapGesture.onEnded` to ignore the simultaneous tap event.

---

## Views/ThemaPanelView.swift

**What lives here:** `struct ThemaPanelView: View` — the reusable card rendered for every topic in both the root carousel and focus-level child ring.

The struct is purely declarative — no `@State`. visionOS does not expose gaze position to apps; the blue gaze highlight on root cards is rendered by the system compositor via `HoverEffectComponent(.spotlight(...))` on the RealityKit entity (configured in `GenericRoomView.swift`), not by SwiftUI state.

### Parameters

| Parameter | Type | Purpose |
|---|---|---|
| `thema` | `Thema` | The topic data to display |
| `isFront` | `Bool` | `true` for the card currently at carousel center (`index == aktuellerIndex`) — drives bold text weight and full-opacity foreground; passed `false` for all child cards |
| `isActiveChild` | `Bool` | `true` for focus-level child cards — activates larger font and cyan border styling |
| `isGehalten` | `Bool` | `true` while the user holds the card — applies scale feedback and cyan glow ring |
| `childHidden` | `Bool` | `true` when breadcrumb is expanded — hides child cards so the breadcrumb list is readable |
| `panelsEingeblendet` | `Bool` | Drives the entrance opacity+scale spring |
| `animationDelay` | `Double` | Staggered delay for child cards so they cascade in one by one |

### Gaze Highlight (root cards only)

Root cards get their blue gaze feedback from the **system compositor**, not from SwiftUI state. visionOS does not expose gaze position to apps for privacy reasons, so `.onHover` / `.onContinuousHover` / custom `.hoverEffect`-closures inside RealityView attachments do not reliably render through. Instead, the entity carries an entity-level effect:

```swift
// GenericRoomView.swift — inside the update closure, set once per panel
panel.components.set(HoverEffectComponent(.spotlight(.init(color: .systemBlue, strength: 20.0))))
```

The system renders a focused blue spotlight that follows the user's gaze across the card surface. Children cards in focus mode keep the default `HoverEffectComponent()` (subtle uniform brighten).

`ThemaPanelView` itself only renders the **idle** look:
- `.ultraThinMaterial` blur + `.black.opacity(0.55)` overlay for readability against any skybox
- Subtle white gradient top-stop + thin white border (`white.opacity(0.5)`, 1.5 pt)
- Front card (`isFront == true`): bold text, full opacity white — plus the 1.18× scale applied by `GenericRoomView`'s ring layout (carousel-center cue)
- Held card (`isGehalten == true`): scale bump to 1.06× plus a cyan/blue gradient border ring

To tune the gaze effect, change the `strength:` value (currently `20.0`; visionOS clamps internally) or swap `.spotlight` for `.highlight` (uniform tint, more subtle).

---

## Views/CrumbPanelView.swift

**What lives here:** `struct CrumbPanelView: View` — the breadcrumb navigation pill shown in focus mode.

### Parameters

| Parameter | Type | Purpose |
|---|---|---|
| `thema` | `Thema` | The ancestor topic this crumb represents |
| `isFront` | `Bool` | `true` for the current (innermost) level — shows text fully visible |
| `breadcrumbExpanded` | `Bool` | When expanded, all ancestors show text; when collapsed, only the front card shows text |
| `panelsEingeblendet` | `Bool` | Drives the entrance opacity+scale spring |

**Interaction:** Tapping the front crumb collapses/expands the stack, or navigates up if no ancestors exist. Tapping an ancestor crumb (only readable when expanded) jumps directly to that level via `zurueckZuAncestor()`. The tap is handled in `tapGesture` in `RoomGestures.swift` — `CrumbPanelView` itself is purely visual.

---

## Views/LesePanelView.swift

**What lives here:** `struct LesePanelView: View` — the 700×500 pt detail overlay that appears when a leaf topic is opened.

### Parameters

| Parameter | Type | Purpose |
|---|---|---|
| `thema` | `Thema` | Leaf topic — its `name` is shown as the overline label |
| `artikel` | `NewsArtikel?` | The loaded news article; `nil` while loading or if none exists |
| `laedt` | `Bool` | `true` while the article is being fetched — shows a loading indicator |
| `leseModusAktiv` | `Bool` | Drives the scale+opacity entrance spring (0.5→1.0 scale, 0→1 opacity) |

Shows the article's `headline` as title and `zusammenfassung` (cleaned summary) as body, plus a "Mehr Infos – Quelle öffnen" button (`artikel.quelleURL` → `openWindow(id: "quelle", value:)`). While `laedt` is true, a loading indicator is shown; if no article exists, an empty-state illustration. The article is loaded by `oeffneLesemodus(fuer:)` in `RoomViewModel.swift` from `published_news_view` — no longer from `thema.description`.

**Closing & input:** The lese panel entity intentionally has **no** `InputTargetComponent`/`CollisionComponent`, so the scene-level `tapGesture` does not target it — otherwise it would swallow taps meant for the SwiftUI buttons inside the attachment (close ✕ and "Mehr Infos"). Closing is therefore handled in SwiftUI: a ✕ `Button` and a full-panel background `.onTapGesture` both call the `onClose` closure → `schliesseLesemodus()` in `RoomViewModel.swift` (clears state + removes the orphaned `lese_` entity). The panel is mounted by `rootEntity`, not `ringEntity`, so it stays in world space regardless of ring rotation.

---

## Views/ZurueckButtonView.swift

**What lives here:** `struct ZurueckButtonView: View` — the home/back button that closes the immersive space and reopens the main window.

Reads `AppModel` and `openWindow` from `@Environment` directly so it doesn't need them passed as parameters. Sets `appModel.ausgewaehltesThema = nil` and calls `openWindow(id: "main")` on tap. Uses `.roundedGazeHover()` from `ViewExtensions.swift`.

---

## Extensions/ViewExtensions.swift

**What lives here:** Shared utilities used across multiple view files.

### RingPanelMarker

```swift
struct RingPanelMarker: Component { var isFront: Bool }
```

A RealityKit `Component` attached to every topic card entity. The `update` closure reads the previous marker to detect when `isFront` changed — only then does it schedule a new `move(to:)` animation, preventing every unrelated `@State` change from restarting the scale animation and causing flicker.

### `roundedGazeHover(cornerRadius:)`

Applies the native visionOS `.hoverEffect(.highlight)` plus a 1.05× scale `hoverEffect` shaped to the card's corner radius. Used on breadcrumb pills and the home button (not on root carousel cards — see ThemaPanelView for why).

### `systemHoverIfActiveChild(_:)`

Applies `roundedGazeHover`-equivalent system effects (highlight + 1.05× scale) only when `isActiveChild == true`. Root carousel cards skip this because their gaze feedback is rendered at the entity level by `HoverEffectComponent(.spotlight(...))` — stacking a SwiftUI hover effect on top would just compete with the system spotlight without adding anything visible.

---

## Access Control Note

All members in the extension files (`RoomViewModel.swift`, `RoomGestures.swift`) and the view structs are `internal` (no modifier). This is required because Swift `private` scopes to the enclosing declaration *and extensions in the same file only* — extensions in separate files cannot access `private` stored properties of the original type. The `@State` properties therefore have no access modifier on `GenericRoomView`, making them module-internal. Since this is an app target (not a library), nothing leaks publicly.

---

## Where to Find What — Quick Reference

| I want to change… | Go to… |
|---|---|
| Skybox loading, entity setup, 3D positions | `GenericRoomView.swift` — `make` / `update` closures |
| Which SwiftUI views are mounted in 3D | `GenericRoomView.swift` — `attachments` block |
| Card fly-in animation speed | `GenericRoomView.swift` — `let dur = isRootLevel ? 0.5 : 0.55` |
| How navigating forward/back works | `RoomViewModel.swift` — `themaAusgewaehlt`, `childAusgewaehlt`, `zurueckEineEbene` |
| Panel cleanup after navigation | `RoomViewModel.swift` — `animierePanels()` |
| Swipe / drag ring rotation | `RoomGestures.swift` — `swipeGesture` |
| Momentum glide + snap behaviour | `RoomGestures.swift` — `starteMomentum()` |
| Hold-to-read gesture timing | `RoomGestures.swift` — `holdGesture` (450 ms sleep) |
| Pinch zoom | `RoomGestures.swift` — `zoomGesture` |
| Gaze highlight on root cards | `GenericRoomView.swift` — `HoverEffectComponent(.spotlight(...))` setup inside the `update` closure (~line 201) |
| Card appearance (colors, scale, font) | `Views/ThemaPanelView.swift` |
| Breadcrumb pill appearance | `Views/CrumbPanelView.swift` |
| Detail/reading overlay | `Views/LesePanelView.swift` |
| Home button | `Views/ZurueckButtonView.swift` |
| Shared hover modifiers | `Extensions/ViewExtensions.swift` |
| RingPanelMarker (flicker prevention) | `Extensions/ViewExtensions.swift` |
