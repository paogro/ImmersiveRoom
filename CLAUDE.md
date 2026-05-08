# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Wissensraum** is a visionOS immersive spatial computing app that presents educational content in 3D themed rooms. Users open an ImmersiveSpace, select a main category (Sport, Natur, Technik, Politik), and explore subcategories displayed as floating panels in 3D space. The backend is a Supabase PostgreSQL database with a hierarchical topic structure.

## Build & Run

- Open `ImmersiveRoom.xcodeproj` in Xcode
- Target: visionOS 26+ (requires Apple Vision Pro or visionOS Simulator)
- Build with Cmd+B, run with Cmd+R
- No build scripts or CLI tooling — standard Xcode + Swift Package Manager

## Architecture

### App Lifecycle & State

- `App/ImmersiveRoomApp.swift` — App entry point. Declares two scenes: a `WindowGroup` (main UI) and an `ImmersiveSpace` (the 3D environment).
- `ImmersiveRoom/AppModel.swift` — Central `@Observable` state class. Owns:
  - `immersiveSpaceState` (closed/inTransition/open)
  - `isImmersiveOpen: Bool`
  - `ausgewaehltesThema: Thema?` (currently selected top-level category)
  - `ausgewaehlteThemenProEbene: [UUID]` (selection history per hierarchy level)
  - Injected via `.environment` throughout the app.

### UI Layer (`Views/`)

- `ContentView.swift` — Main window. Shows "Start Experience" button, lists loaded categories as tappable buttons, and "Experience beenden" button. Fetches top-level categories via `ThemenService` on appear. Tapping a category sets `appModel.ausgewaehltesThema` and dismisses the window.

### 3D Immersive Layer (`3DContent/`)

- `ImmersiveView.swift` — Router: switches on `appModel.ausgewaehltesThema.name` and passes the matching skybox texture name to `GenericRoomView`:
  - `"Sport"` → `GenericRoomView(skyboxTextureName: "sport_equirectangular")`
  - `"Natur"` → `GenericRoomView(skyboxTextureName: "natur_equirectangular")`
  - `"Technik"` → `GenericRoomView(skyboxTextureName: "technik_equirectangular")`
  - `"Politik"` → `GenericRoomView(skyboxTextureName: "politik_equirectangular")`
  - Fallback: empty `FallbackRoomView`
- `3DContent/Rooms/GenericRoomView.swift` — The single shared room implementation used by all 4 categories. Accepts a `skyboxTextureName: String` parameter. Creates a skybox sphere (radius 50, X-flipped), loads subcategories from Supabase, and handles the full navigation/interaction loop inside a `RealityView`.

### Data Layer

- `Models/Thema.swift` — Core model. Fields: `id` (UUID), `name`, `parentId` (UUID?, for hierarchy), `level` (Int, depth), `createdAt` (String), `description` (String?, optional long-form text). Maps Supabase snake_case column names via `CodingKeys`.
- `Services/ThemenService.swift` — Queries the `topics` table:
  - `getHauptkategorien()` — level-1 categories
  - `getUnterthemen(vonThemaId:)` — subcategories by parent UUID
  - `getThema(id:)` — single topic lookup
  - `getPfad(fuerThemaId:)` — full ancestor path (leaf → root)
- `Services/SupabaseClient.swift` — Singleton `SupabaseManager` providing a shared `SupabaseClient`.
- `App/AppConfig.swift` — Supabase URL and anon API key constants.

### RealityKit Content Package (`Packages/RealityKitContent/`)

Local Swift package that bundles RealityKit assets (Reality Composer Pro project). Linked as a framework target.

---

## GenericRoomView — Interaction Model

`GenericRoomView` implements the complete 3D UI. There are two display modes:

**Gallery mode** (root level, `fokusThema == nil`):
- Themes arranged in a flat row; the current one (`aktuellerIndex`) is centered and scaled up (1.2×).
- Swipe left/right to cycle through themes.
- Tap a side panel to bring it to front; tap the front panel to enter **Fokus mode**.

**Fokus mode** (`fokusThema != nil`):
- Children of the selected theme are shown in a flat horizontal row at equal scale.
- A breadcrumb panel (`fokusPanel`) appears below with the current theme name and a back chevron — tap it to go up one level.
- Tap a child panel to drill deeper (or open **Lesemodus** if it has no children).

**Lesemodus** (detail view):
- Activated by holding a panel for 450ms OR tapping a leaf node (no children).
- Shows a 700×500 info panel with the theme name and `thema.description` from the DB.
- If no description is set in the DB, a placeholder empty-state is shown.
- Tap anywhere on the panel to close it.

**Gestures:**

| Gesture | Trigger | Action |
|---|---|---|
| `SpatialTapGesture` | Quick tap on entity | Navigate / select / close |
| `DragGesture(minimumDistance: 10)` | Horizontal drag in gallery | Swipe to previous/next theme |
| `DragGesture(minimumDistance: 0)` + 450ms `Task.sleep` | Hold without movement (≤4cm tolerance) | Open Lesemodus; sets `holdTriggered` to suppress subsequent tap |
| `MagnifyGesture` | Pinch | Scale entire scene (0.4–2.5×) |

Hold feedback: the held panel scales to 1.06× and gains a cyan glow ring while the timer runs.

---

## GenericRoomView — 3D Positions

All positions are in world space (`relativeTo: nil`). User stands at origin.

| Element | Position |
|---|---|
| Debug status label | `(0, 2.2, -2.0)` |
| Übersicht-Button | `(0, 1.1, -1.7)` |
| Lesepanel (info) | `(0, 1.5, -1.8)` |
| Fokus-Breadcrumb | animiert `(0, 1.4, -2.0)` → `(0, 0.8, -2.0)` |
| Front theme panel (root) | `(0, 1.4, -2.0)`, scale 1.2 |
| Side panels (root) | `(±1.1×n, 1.4, -2.0 - 0.2×n)`, scale max(0.6, 1.2 - 0.25×n) |
| Children panels (fokus) | `(evenly spaced, 1.5, -2.5)`, scale 1.0 |

---

## Key Patterns

- **State propagation:** `AppModel` is passed as an environment object; `GenericRoomView` reads `appModel.ausgewaehltesThema` to determine which data to load.
- **3D UI:** Subcategories are rendered as SwiftUI views anchored in `RealityView` using `.attachment(id:)`. Interaction requires `InputTargetComponent` + `CollisionComponent` on the attachment entity (set in the `update` closure when `panel.parent == nil`).
- **Async data loading:** All Supabase calls use `async/await` inside `.task {}` modifiers or `Task { }` blocks.
- **Hold-gesture pattern:** `DragGesture(minimumDistance: 0)` starts a `Task { @MainActor in try? await Task.sleep(for: .milliseconds(450)) }`. Movement > 4cm cancels the task. On activation, `holdTriggered = true` is set so the co-firing `SpatialTapGesture` is suppressed.
- **Adding a new room:** Add a `case "NewCategory": GenericRoomView(skyboxTextureName: "newcategory_equirectangular")` to the switch in `ImmersiveView.swift` and provide the matching equirectangular texture asset.
- **Description data:** `thema.description` is optional — always guard/trim before display. `ThemenService.select()` fetches all columns automatically, so no query changes are needed when new columns are added to the `topics` table.
