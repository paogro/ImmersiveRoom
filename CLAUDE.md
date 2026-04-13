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
- `ImmersiveRoom/AppModel.swift` — Central `@Observable` state class. Owns `immersiveSpaceState` (closed/inTransition/open) and `ausgewaehltesThema` (currently selected category). Injected via `.environment` throughout the app.

### UI Layer (`Views/`)

- `ContentView.swift` — Main window. Shows "Start Experience" button, lists loaded categories, and "Experience beenden" button. Fetches top-level categories via `ThemenService` when the immersive space opens.

### 3D Immersive Layer (`3DContent/`)

- `ImmersiveView.swift` — Router: switches between themed `RealityView`-based room implementations based on `AppModel.ausgewaehltesThema`.
- `3DContent/Rooms/SportRoomView.swift` — Reference implementation. Creates a dark skybox sphere, loads subcategories (`Unterthemen`) from Supabase, and positions them as floating `ViewAttachment` panels in 3D space around the user. The other three rooms (Natur, Technik, Politik) are not yet implemented.

### Data Layer

- `Models/Thema.swift` — Core model. Fields: `id` (UUID), `name`, `parentId` (nullable, for hierarchy), `level` (depth), `createdAt`. Maps Supabase snake_case field names via `CodingKeys`.
- `Services/ThemenService.swift` — Queries the `topics` table:
  - `getHauptkategorien()` — level 1 categories
  - `getUnterthemen(fuer:)` — subcategories by parent ID
  - `getThema(id:)` — single topic lookup
  - `getPfad(fuer:)` — full ancestor path (leaf → root)
- `Services/SupabaseClient.swift` — Singleton `SupabaseManager` providing a shared `SupabaseClient`.
- `App/AppConfig.swift` — Supabase URL and anon API key constants.

### RealityKit Content Package (`Packages/RealityKitContent/`)

Local Swift package that bundles RealityKit assets (Reality Composer Pro project). Linked as a framework target.

## Key Patterns

- **State propagation:** `AppModel` is passed as an environment object; room views read `appModel.ausgewaehltesThema` to decide what to load.
- **3D UI:** Subcategories are rendered as SwiftUI views anchored in `RealityView` using `.attachment(id:)` and positioned with `BillboardComponent` or explicit transforms.
- **Async data loading:** All Supabase calls use `async/await` inside `.task {}` modifiers.
- **Adding a new room:** Implement a view analogous to `SportRoomView`, then add a `case` to the switch in `ImmersiveView.swift`.
