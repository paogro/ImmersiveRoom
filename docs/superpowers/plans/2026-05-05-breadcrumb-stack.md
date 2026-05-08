# Breadcrumb Stack & Entry Animation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the single fokus breadcrumb panel with a 3D stacked breadcrumb trail that expands downward on tap, and animate new child panels entering from above.

**Architecture:** All changes are confined to `3DContent/Rooms/GenericRoomView.swift`. A new `@State var breadcrumbExpanded` controls the stack open/closed state. All ancestor panels use the `crumb_` attachment prefix, replacing the old `fokus_` system. A new `zurueckZuAncestor(thema:)` function handles direct back-navigation to any level. `animierePanels()` is extended to remove stale entities so re-entry animations always fire.

**Tech Stack:** SwiftUI, RealityKit, visionOS 26+

---

### Task 1: Add `breadcrumbExpanded` state and reset on navigation

**Files:**
- Modify: `3DContent/Rooms/GenericRoomView.swift`

- [ ] **Step 1: Add state property**

In the `@State` block (after `@State private var holdTriggered = false`, around line 28), add:

```swift
@State private var breadcrumbExpanded: Bool = false
```

- [ ] **Step 2: Reset in `themaAusgewaehlt`**

In `themaAusgewaehlt(thema:)`, add before `animierePanels()`:

```swift
breadcrumbExpanded = false
```

- [ ] **Step 3: Reset in `childAusgewaehlt`**

In `childAusgewaehlt(thema:)`, add before `animierePanels()`:

```swift
breadcrumbExpanded = false
```

- [ ] **Step 4: Reset in `zurueckEineEbene`**

In `zurueckEineEbene()`, add before `animierePanels()`:

```swift
breadcrumbExpanded = false
```

- [ ] **Step 5: Build (Cmd+B)**

Expected: compiles without errors.

- [ ] **Step 6: Commit**

```bash
git add 3DContent/Rooms/GenericRoomView.swift
git commit -m "feat: add breadcrumbExpanded state with reset on all navigation paths"
```

---

### Task 2: Add `crumbPanel` view, remove `fokusPanel`

**Files:**
- Modify: `3DContent/Rooms/GenericRoomView.swift`

- [ ] **Step 1: Add `crumbPanel` function**

Insert this new `@ViewBuilder` function directly after the closing `}` of `fokusPanel` (around line 465):

```swift
@ViewBuilder
private func crumbPanel(thema: Thema, isFront: Bool) -> some View {
    HStack(spacing: 14) {
        if isFront {
            Image(systemName: "chevron.left")
                .font(.title2).fontWeight(.medium).foregroundColor(.white.opacity(0.7))
        }
        Text(thema.name)
            .font(.extraLargeTitle).fontWeight(.bold).foregroundStyle(.white)
    }
    .padding(.horizontal, 48)
    .padding(.vertical, 28)
    .background {
        ZStack {
            RoundedRectangle(cornerRadius: 32).fill(.black.opacity(0.3))
            RoundedRectangle(cornerRadius: 32).fill(.ultraThinMaterial)
            RoundedRectangle(cornerRadius: 32).fill(LinearGradient(
                stops: [
                    .init(color: isFront ? .blue.opacity(0.2) : .white.opacity(0.08), location: 0),
                    .init(color: isFront ? .purple.opacity(0.08) : .clear, location: 0.5),
                    .init(color: .clear, location: 1.0)
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ))
            RoundedRectangle(cornerRadius: 32).stroke(
                LinearGradient(
                    colors: isFront
                        ? [.white.opacity(0.6), .blue.opacity(0.3), .white.opacity(0.4)]
                        : [.white.opacity(0.3), .white.opacity(0.1), .white.opacity(0.2)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ),
                lineWidth: isFront ? 1.5 : 1.0
            )
        }
    }
    .shadow(color: isFront ? .blue.opacity(0.3) : .black.opacity(0.2),
            radius: isFront ? 25 : 10, y: 10)
    .hoverEffect(.highlight)
    .scaleEffect(panelsEingeblendet ? 1.0 : 0.85)
    .opacity(panelsEingeblendet ? 1.0 : 0.0)
    .animation(.spring(response: 0.45, dampingFraction: 0.8), value: panelsEingeblendet)
}
```

- [ ] **Step 2: Delete `fokusPanel`**

Remove the entire `@ViewBuilder private func fokusPanel(thema: Thema) -> some View { ... }` function (lines 427–465).

- [ ] **Step 3: Build (Cmd+B)**

Expected: errors referencing `fokusPanel` — will be fixed in Task 3.

---

### Task 3: Update `attachments` block

**Files:**
- Modify: `3DContent/Rooms/GenericRoomView.swift`

- [ ] **Step 1: Replace `fokus_` Attachment with `crumb_` ForEach**

In the `attachments:` block, find:

```swift
if let fokus = fokusThema {
    Attachment(id: "fokus_\(fokus.id.uuidString)") {
        fokusPanel(thema: fokus)
    }
}
```

Replace with:

```swift
if let fokus = fokusThema {
    let breadcrumbPfad: [Thema] = pfad + [fokus]
    ForEach(breadcrumbPfad) { thema in
        Attachment(id: "crumb_\(thema.id.uuidString)") {
            crumbPanel(thema: thema, isFront: thema.id == fokus.id)
        }
    }
}
```

- [ ] **Step 2: Build (Cmd+B)**

Expected: compiles without errors — `fokusPanel` reference is gone.

- [ ] **Step 3: Commit**

```bash
git add 3DContent/Rooms/GenericRoomView.swift
git commit -m "feat: replace fokus_ attachment with crumb_ breadcrumb stack"
```

---

### Task 4: Update `update` closure — breadcrumb stack positioning

**Files:**
- Modify: `3DContent/Rooms/GenericRoomView.swift`

- [ ] **Step 1: Replace the old fokus block with the new crumb stack loop**

In the `update` closure, find and remove the entire `// === FOKUS-THEMA (Breadcrumb UNTEN) ===` block:

```swift
// === FOKUS-THEMA (Breadcrumb UNTEN) ===
if let fokus = fokusThema {
    if let titelPanel = attachments.entity(for: "fokus_\(fokus.id.uuidString)") {
        titelPanel.name = "fokus_\(fokus.id.uuidString)"

        if titelPanel.components[InputTargetComponent.self] == nil {
            titelPanel.components.set(InputTargetComponent(allowedInputTypes: .all))
            titelPanel.components.set(CollisionComponent(shapes: [.generateBox(size: SIMD3<Float>(1.35, 0.4, 0.05))]))
        }

        if titelPanel.parent == nil {
            titelPanel.position = SIMD3<Float>(0, 1.4, -2.0)
            rootEntity.addChild(titelPanel)

            let zielTransform = Transform(
                scale: SIMD3<Float>(repeating: 1.0),
                rotation: simd_quatf(angle: 0, axis: [0, 1, 0]),
                translation: SIMD3<Float>(0, 0.8, -2.0)
            )
            titelPanel.move(to: zielTransform, relativeTo: nil, duration: 0.55, timingFunction: .easeInOut)
        }
    }
}
```

Replace with:

```swift
// === BREADCRUMB STACK ===
if let fokus = fokusThema {
    let breadcrumbPfad: [Thema] = pfad + [fokus]

    for (revIdx, thema) in breadcrumbPfad.reversed().enumerated() {
        // revIdx 0 = fokusThema (front/top of stack), revIdx 1 = pfad.last, etc.
        let attachmentID = "crumb_\(thema.id.uuidString)"

        if let panel = attachments.entity(for: attachmentID) {
            panel.name = attachmentID

            if panel.components[InputTargetComponent.self] == nil {
                panel.components.set(InputTargetComponent(allowedInputTypes: .all))
                panel.components.set(CollisionComponent(shapes: [.generateBox(size: SIMD3<Float>(1.35, 0.4, 0.05))]))
            }

            if panel.parent == nil {
                panel.position = SIMD3<Float>(0, 0.8, -2.0)
                rootEntity.addChild(panel)
            }

            let targetY: Float
            let targetZ: Float
            let targetScale: Float

            if breadcrumbExpanded {
                targetY     = 0.80 - Float(revIdx) * 0.52
                targetZ     = -2.00
                targetScale = 1.00 - Float(revIdx) * 0.04
            } else {
                targetY     = 0.80 - Float(revIdx) * 0.06
                targetZ     = -2.00 - Float(revIdx) * 0.02
                targetScale = 1.00 - Float(revIdx) * 0.04
            }

            let crumbTransform = Transform(
                scale: SIMD3<Float>(repeating: targetScale),
                rotation: simd_quatf(angle: 0, axis: [0, 1, 0]),
                translation: SIMD3<Float>(0, targetY, targetZ)
            )
            panel.move(to: crumbTransform, relativeTo: nil, duration: 0.4, timingFunction: .easeInOut)
        }
    }
}
```

- [ ] **Step 2: Build (Cmd+B)**

Expected: compiles without errors.

- [ ] **Step 3: Commit**

```bash
git add 3DContent/Rooms/GenericRoomView.swift
git commit -m "feat: implement 3D breadcrumb stack with collapse/expand positioning"
```

---

### Task 5: Entry animation from above for child panels

**Files:**
- Modify: `3DContent/Rooms/GenericRoomView.swift`

- [ ] **Step 1: Restructure the `// === POSITIONIERUNG DER THEMEN ===` loop**

The goal: compute `zielPosition` first, then use it for the from-top entry offset when `panel.parent == nil`. Find the existing loop body:

```swift
if panel.parent == nil { rootEntity.addChild(panel) }

var zielPosition: SIMD3<Float>
var zielScale: Float

if isRootLevel {
    // ...gallery calc...
} else {
    // ...fokus calc...
}

let transform = Transform(
    scale: SIMD3<Float>(repeating: zielScale),
    rotation: simd_quatf(angle: 0, axis: [0, 1, 0]),
    translation: zielPosition
)
panel.move(to: transform, relativeTo: nil, duration: 0.5, timingFunction: .easeInOut)
```

Replace with:

```swift
var zielPosition: SIMD3<Float>
var zielScale: Float

if isRootLevel {
    let distanz = index - aktuellerIndex
    let xOffset = Float(distanz) * 1.1

    if distanz == 0 {
        zielPosition = SIMD3<Float>(0, 1.4, -2.0)
        zielScale = 1.2
    } else {
        let zOffset = abs(Float(distanz)) * 0.2
        zielPosition = SIMD3<Float>(xOffset, 1.4, -2.0 - zOffset)
        zielScale = max(0.6, 1.2 - (abs(Float(distanz)) * 0.25))
    }
} else {
    let gesamtBreite = Float(sichtbareThemen.count - 1) * 1.1
    let startX = -gesamtBreite / 2.0
    let xPos = startX + Float(index) * 1.1

    zielPosition = SIMD3<Float>(xPos, 1.5, -2.5)
    zielScale = 1.0
}

if panel.parent == nil {
    if !isRootLevel {
        // Child panels fly in from 1.5m above their target
        panel.position = SIMD3<Float>(zielPosition.x, zielPosition.y + 1.5, zielPosition.z)
    }
    rootEntity.addChild(panel)
}

let transform = Transform(
    scale: SIMD3<Float>(repeating: zielScale),
    rotation: simd_quatf(angle: 0, axis: [0, 1, 0]),
    translation: zielPosition
)
panel.move(to: transform, relativeTo: nil, duration: 0.5, timingFunction: .easeInOut)
```

- [ ] **Step 2: Build (Cmd+B)**

Expected: compiles without errors.

- [ ] **Step 3: Commit**

```bash
git add 3DContent/Rooms/GenericRoomView.swift
git commit -m "feat: animate child panels in from above when entering focus mode"
```

---

### Task 6: Update tap gesture for `crumb_` entities

**Files:**
- Modify: `3DContent/Rooms/GenericRoomView.swift`

- [ ] **Step 1: Replace `fokus_` handler**

In `tapGesture`, find:

```swift
if name.hasPrefix("fokus_") {
    Task { await zurueckEineEbene() }
    return
}
```

Replace with:

```swift
if name.hasPrefix("crumb_") {
    let uuidString = String(name.dropFirst("crumb_".count))
    let isFront = fokusThema?.id.uuidString == uuidString
    if isFront {
        if pfad.isEmpty {
            Task { await zurueckEineEbene() }
        } else {
            breadcrumbExpanded.toggle()
        }
    } else {
        if let ancestor = pfad.first(where: { $0.id.uuidString == uuidString }) {
            Task { await zurueckZuAncestor(thema: ancestor) }
        }
    }
    return
}
```

- [ ] **Step 2: Build (Cmd+B)**

Expected: error on `zurueckZuAncestor` — implement in Task 7.

---

### Task 7: Add `zurueckZuAncestor` function

**Files:**
- Modify: `3DContent/Rooms/GenericRoomView.swift`

- [ ] **Step 1: Add function after `zurueckEineEbene`**

After the closing `}` of `zurueckEineEbene()` (end of the Navigation section), add:

```swift
private func zurueckZuAncestor(thema: Thema) async {
    guard let fokus = fokusThema else { return }
    let vollPfad = pfad + [fokus]
    guard let idx = vollPfad.firstIndex(where: { $0.id == thema.id }) else { return }

    pfad = Array(vollPfad[0..<idx])
    fokusThema = thema
    breadcrumbExpanded = false

    do {
        childrenThemen = try await themenService.getUnterthemen(vonThemaId: thema.id)
        let parentId = pfad.last?.id ?? appModel.ausgewaehltesThema?.id
        if let pid = parentId {
            aktuelleThemen = try await themenService.getUnterthemen(vonThemaId: pid)
        }
        status = "\(childrenThemen.count) Unterthemen"
    } catch {
        status = "Fehler: \(error.localizedDescription)"
    }

    animierePanels()
}
```

- [ ] **Step 2: Build (Cmd+B)**

Expected: compiles without errors.

- [ ] **Step 3: Commit**

```bash
git add 3DContent/Rooms/GenericRoomView.swift
git commit -m "feat: add zurueckZuAncestor for direct breadcrumb back-navigation"
```

---

### Task 8: Remove stale entities on navigation

**Files:**
- Modify: `3DContent/Rooms/GenericRoomView.swift`

When navigating, old `crumb_`, `child_`, and `thema_` entities remain parented to `rootEntity` after `animierePanels()` — they just stop receiving `move()` calls and linger in space. Removing them ensures re-entry animations always fire cleanly.

- [ ] **Step 1: Extend `animierePanels()` to purge stale entities**

Find:

```swift
private func animierePanels() {
    panelsEingeblendet = false
    withAnimation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.1)) {
        panelsEingeblendet = true
    }
}
```

Replace with:

```swift
private func animierePanels() {
    // Collect first to avoid mutating the collection during iteration
    let stale = rootEntity.children.filter {
        $0.name.hasPrefix("crumb_") || $0.name.hasPrefix("child_") || $0.name.hasPrefix("thema_")
    }
    stale.forEach { $0.removeFromParent() }
    panelsEingeblendet = false
    withAnimation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.1)) {
        panelsEingeblendet = true
    }
}
```

- [ ] **Step 2: Build (Cmd+B)**

Expected: compiles without errors.

- [ ] **Step 3: Commit**

```bash
git add 3DContent/Rooms/GenericRoomView.swift
git commit -m "feat: purge stale panel entities on navigation for clean re-entry animations"
```

---

### Task 9: Smoke test on visionOS Simulator

- [ ] **Run on Simulator (Cmd+R) and verify:**

1. Root gallery loads — panels scale in as before, swipe left/right works.
2. Tap front gallery panel → child panels fall in from above (1.5m drop). Breadcrumb (front `crumb_` card) slides down to y=0.80.
3. With one level of fokus (`pfad.isEmpty`): tap `crumb_` card → goes back to root.
4. Navigate two levels deep → `crumb_` stack shows 2 cards; the older one peeks ~0.06m below the front card.
5. Tap front `crumb_` card → stack expands downward (older card drops to y=0.28).
6. Tap the older card in expanded state → navigates back to that level; child panels fly in from above; crumb collapses to single card.
7. Tap front `crumb_` card when expanded but no ancestor tapped → stack collapses.
8. Hold gesture on child panel → Lesemodus still works.
9. Pinch zoom → still works.
