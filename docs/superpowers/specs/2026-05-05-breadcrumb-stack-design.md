# Breadcrumb Stack & Entry Animation — Design Spec

**Date:** 2026-05-05  
**File:** `3DContent/Rooms/GenericRoomView.swift`  
**Status:** Approved

---

## Overview

Two usability improvements to `GenericRoomView`:

1. New child panels animate in from above when entering or deepening focus mode.
2. The single breadcrumb panel is replaced by a 3D stack showing all ancestors, which expands downward on tap to allow direct back-navigation to any level.

---

## Feature 1: Entry Animation from Above

**Trigger:** Any time focus mode is entered or deepened (`themaAusgewaehlt`, `childAusgewaehlt`).

**Behavior:**  
In the `update` closure, when a child panel entity is first added to the scene (`panel.parent == nil`), its initial position is set to `(targetX, targetY + 1.5, targetZ)` before `rootEntity.addChild(panel)` is called. The existing `panel.move(to:duration:timingFunction:)` call then animates it to the target — giving a "falling in from above" effect.

**Scope:**  
- Applies to `child_` attachment panels only (fokus mode).  
- Root gallery panels (`thema_`) keep their existing scale-in animation (0.7 → 1.0).  
- The fokus breadcrumb panel already slides down from its starting position — no change needed there.

---

## Feature 2: 3D Breadcrumb Stack

### 2a. State

```swift
@State private var breadcrumbExpanded: Bool = false
```

Added to `GenericRoomView`. Reset to `false` whenever `fokusThema` changes.

### 2b. Attachment IDs

All breadcrumb panels (current parent + all ancestors) use a unified `crumb_` prefix:

- `fokusThema` → `"crumb_\(fokusThema.id.uuidString)"`
- `pfad[i]` → `"crumb_\(pfad[i].id.uuidString)"`

The existing `fokus_` attachment and its tap handler are replaced entirely by the new `crumb_` system.

### 2c. Collapsed Stack Positions

Panels are rendered as a stack; older ancestors sit slightly lower and further away, peeking out below the front card. No opacity change — all cards fully opaque.

| Depth offset (from front) | Y          | Z       | Scale |
|--------------------------|------------|---------|-------|
| 0 — fokusThema (front)   | 0.80       | −2.00   | 1.00  |
| 1 — pfad.last            | 0.74       | −2.02   | 0.96  |
| 2 — pfad[−2]             | 0.68       | −2.04   | 0.92  |
| n                        | 0.80−n×0.06 | −2.00−n×0.02 | 1.00−n×0.04 |

All panels have `InputTargetComponent` + `CollisionComponent`.

Front card label: `‹ Name` (existing chevron style, no additional icons).  
Ancestor cards: same panel style but visually receding due to position/scale, not transparency.

### 2d. Expanded Stack Positions

When `breadcrumbExpanded == true`, cards animate to a vertical column at uniform Z:

| Depth offset | Y                  | Z     |
|--------------|--------------------|-------|
| 0 — front    | 0.80               | −2.00 |
| 1            | 0.28               | −2.00 |
| 2            | −0.24              | −2.00 |
| n            | 0.80 − n × 0.52    | −2.00 |

Animation: `entity.move(to:relativeTo:nil, duration: 0.4, timingFunction: .easeInOut)`

### 2e. Tap Logic

| Situation | Action |
|-----------|--------|
| Tap front card, `breadcrumbExpanded == false`, `pfad` not empty | Expand stack (`breadcrumbExpanded = true`) |
| Tap front card, `breadcrumbExpanded == true` | Collapse stack (`breadcrumbExpanded = false`) |
| Tap ancestor card (any `crumb_` that is not fokusThema) | `zurueckZuAncestor(thema:)` + collapse |
| Tap front card, `pfad.isEmpty` | `zurueckEineEbene()` — existing back behavior |

### 2f. `zurueckZuAncestor(thema:)` Navigation

```swift
private func zurueckZuAncestor(thema: Thema) async {
    let vollPfad = pfad + [fokusThema!]
    guard let idx = vollPfad.firstIndex(where: { $0.id == thema.id }) else { return }

    pfad = Array(vollPfad[0..<idx])
    fokusThema = thema
    breadcrumbExpanded = false

    // Reload children of the target
    childrenThemen = (try? await themenService.getUnterthemen(vonThemaId: thema.id)) ?? []

    // Reload siblings (children of target's parent)
    let parentId = pfad.last?.id ?? appModel.ausgewaehltesThema?.id
    if let pid = parentId {
        aktuelleThemen = (try? await themenService.getUnterthemen(vonThemaId: pid)) ?? []
    }

    animierePanels()
}
```

---

## Update Closure Changes

The existing `// === FOKUS-THEMA (Breadcrumb UNTEN) ===` block in the `update` closure is removed entirely. It is replaced by a new loop over the full `breadcrumbPfad` array (all `crumb_` entities), which positions each panel according to the collapsed or expanded positions in sections 2c/2d above.

The new loop runs after the child panels loop and before the `rootEntity.scale` line.

---

## Tap Gesture Changes

The existing `if name.hasPrefix("fokus_")` branch in `tapGesture` is replaced by:

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

---

## Attachment Declaration Changes

In the `attachments` block:

- Remove the existing `if let fokus = fokusThema { Attachment(id: "fokus_...") }` block.
- Add a `ForEach` over the full breadcrumb path:

```swift
let breadcrumbPfad: [Thema] = (fokusThema != nil)
    ? pfad + [fokusThema!]
    : []

ForEach(breadcrumbPfad) { thema in
    Attachment(id: "crumb_\(thema.id.uuidString)") {
        crumbPanel(thema: thema, isFront: thema.id == fokusThema?.id)
    }
}
```

---

## `crumbPanel` View

A new `@ViewBuilder` function replacing `fokusPanel`. The front card (`isFront == true`) gets the existing glassmorphism gradient + blue border. Ancestor cards get the same border/background but are not visually differentiated beyond position/scale (no transparency). Label: `‹ Name` on front card; plain `Name` on ancestor cards.

---

## Out of Scope

- No changes to root gallery mode (swipe, scale-in animation).
- No changes to `lesePanel` or `leseModusAktiv`.
- No changes to `zurueckButton` (Übersicht / home).
- No changes to hold gesture or zoom gesture.
