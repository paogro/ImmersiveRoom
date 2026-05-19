import SwiftUI
import RealityKit

extension GenericRoomView {

    // MARK: - Gestures

    var tapGesture: some Gesture {
        SpatialTapGesture()
            .targetedToAnyEntity()
            .onEnded { value in
                let name = value.entity.name

                // Hold hat den Lesemodus ausgelöst → diesen Tap ignorieren
                if holdTriggered {
                    holdTriggered = false
                    return
                }

                if name.hasPrefix("lese_") {
                    leseModusAktiv = false
                    leseThema = nil
                    // Closing the detail overlay is NOT a navigation event — the underlying
                    // panels never went anywhere, they were just hidden behind the overlay.
                    // Don't call animierePanels(); that would tear down and remount every
                    // panel, re-triggering their initial-offset slide-in. Instead, just
                    // remove the orphaned lese entity so it leaves the scene cleanly.
                    let staleLese = rootEntity.children.filter { $0.name.hasPrefix("lese_") }
                    staleLese.forEach { $0.removeFromParent() }
                    return
                }

                if name.hasPrefix("crumb_") {
                    let uuidString = String(name.dropFirst("crumb_".count))
                    let isFront = fokusThema?.id.uuidString == uuidString
                    if isFront {
                        // Tap front card = toggle expand/collapse.
                        // No ancestors? Then collapse means "go up one level" (root).
                        if pfad.isEmpty && !breadcrumbExpanded {
                            Task { await zurueckEineEbene() }
                        } else {
                            withAnimation(.easeInOut(duration: 0.4)) {
                                breadcrumbExpanded.toggle()
                            }
                        }
                    } else {
                        // Tap an ancestor (only readable when expanded) = navigate to that level.
                        if let ancestor = pfad.first(where: { $0.id.uuidString == uuidString }) {
                            Task { await zurueckZuAncestor(thema: ancestor) }
                        }
                    }
                    return
                }

                if name.hasPrefix("thema_") {
                    // Tap = direkte Auswahl. Egal wo die Karte gerade im Kreis steht,
                    // der Tap betrifft genau die Karte, die der Nutzer angeschaut hat.
                    // Kein Re-Center, kein Snap-to-front — sonst stimmt die Auswahl
                    // nicht mit dem überein, was der Nutzer angetippt hat.
                    let uuidString = String(name.dropFirst("thema_".count))
                    if let thema = aktuelleThemen.first(where: { $0.id.uuidString == uuidString }) {
                        stopMomentum()
                        Task { await themaAusgewaehlt(thema: thema) }
                    }
                    return
                }

                if name.hasPrefix("child_") {
                    let uuidString = String(name.dropFirst("child_".count))
                    if let thema = childrenThemen.first(where: { $0.id.uuidString == uuidString }) {
                        Task { await childAusgewaehlt(thema: thema) }
                    }
                    return
                }
            }
    }

    // Swipe rotiert den ganzen Ring wie ein Zahnrad — funktioniert sowohl im
    // Root- als auch im Fokus-Level, weil beide jetzt dieselbe Kreis-Anordnung
    // benutzen. Während der Geste wird ringEntity.transform.rotation direkt
    // gesetzt; @State (ringAngle) wird erst nach dem Snap committed.
    var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .targetedToAnyEntity()
            .onChanged { value in
                let count = sichtbareThemen.count
                guard count > 0 else { return }
                let tx = Float(value.translation3D.x)
                let now = Date()

                if !ringDragActive {
                    stopMomentum()
                    ringDragActive = true
                    ringInteracting = true
                    ringDragStartAngle = ringAngle
                    ringDragLastX = tx
                    ringDragLastTime = now
                    ringVelocity = 0
                }

                // Drag-Konvention: nach rechts ziehen (positive x) holt die
                // vorherige Karte nach vorn — die Karten folgen also der Hand.
                // Ringrotation um +Y verschiebt Karten zur -X-Seite, deshalb
                // negieren wir tx.
                let newAngle = ringDragStartAngle - tx * ringDragSensitivity
                ringEntity.transform.rotation = simd_quatf(angle: newAngle, axis: [0, 1, 0])
                ringAngle = newAngle

                let dt = max(Float(now.timeIntervalSince(ringDragLastTime)), 0.001)
                let dx = tx - ringDragLastX
                let omega = -dx * ringDragSensitivity / dt
                // Geglättete Winkelgeschwindigkeit für den Impulsschwung
                ringVelocity = ringVelocity * 0.55 + omega * 0.45
                ringDragLastX = tx
                ringDragLastTime = now

                aktualisiereFrontIndex()
            }
            .onEnded { _ in
                guard ringDragActive else { return }
                ringDragActive = false
                let count = sichtbareThemen.count
                guard count > 0 else {
                    ringInteracting = false
                    return
                }
                // Geschwindigkeit clampen, sonst kann ein Ruckler den Ring
                // unkontrolliert schleudern.
                let maxSpeed: Float = 14.0
                ringVelocity = max(-maxSpeed, min(maxSpeed, ringVelocity))
                starteMomentum()
            }
    }

    var holdGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .targetedToAnyEntity()
            .onChanged { value in
                let name = value.entity.name
                guard name.hasPrefix("thema_") || name.hasPrefix("child_") else { return }

                // Erste Berührung an dieser Entity → Hold starten
                if aktivGehaltenesPanel != name {
                    holdTask?.cancel()
                    holdTriggered = false

                    withAnimation(.easeOut(duration: 0.15)) {
                        aktivGehaltenesPanel = name
                    }

                    holdTask = Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(450))
                        guard !Task.isCancelled else { return }
                        loeseLeseModusAus(panelName: name)
                        holdTriggered = true
                        withAnimation(.easeOut(duration: 0.2)) {
                            aktivGehaltenesPanel = nil
                        }
                    }
                }

                // Bewegungstoleranz: ~4cm — verzeiht Eye-Tracking-Wackler
                let translation = value.translation3D
                let bewegung = sqrt(
                    Float(translation.x * translation.x) +
                    Float(translation.y * translation.y) +
                    Float(translation.z * translation.z)
                )
                if bewegung > 0.04 {
                    holdTask?.cancel()
                    if aktivGehaltenesPanel != nil {
                        withAnimation(.easeOut(duration: 0.2)) {
                            aktivGehaltenesPanel = nil
                        }
                    }
                }
            }
            .onEnded { _ in
                holdTask?.cancel()
                if aktivGehaltenesPanel != nil {
                    withAnimation(.easeOut(duration: 0.2)) {
                        aktivGehaltenesPanel = nil
                    }
                }
            }
    }

    var zoomGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                baumScale = max(0.4, min(2.5, scaleStart * Float(value.magnification)))
            }
            .onEnded { _ in scaleStart = baumScale }
    }

    // MARK: - Ring / Momentum Helpers

    // Aktualisiert aktuellerIndex auf die Karte, die der Frontposition (Weltwinkel 0)
    // gerade am nächsten ist. Karte i sitzt im Ringraum bei θ_i = i*step; nach Rotation
    // um α ist ihr Weltwinkel θ_i - α, also frontIdx ≈ round(α / step) mod n.
    func aktualisiereFrontIndex() {
        let count = sichtbareThemen.count
        guard count > 0 else { return }
        let step: Float = 2 * Float.pi / Float(count)
        var idx = Int((ringAngle / step).rounded())
        idx = ((idx % count) + count) % count
        if idx != aktuellerIndex {
            aktuellerIndex = idx
        }
    }

    func stopMomentum() {
        momentumTask?.cancel()
        momentumTask = nil
        ringInteracting = false
    }

    func starteMomentum() {
        let count = sichtbareThemen.count
        guard count > 0 else {
            ringInteracting = false
            return
        }
        momentumTask?.cancel()
        ringInteracting = true

        momentumTask = Task { @MainActor in
            let step: Float = 2 * Float.pi / Float(count)
            let frameSec: Float = 1.0 / 60.0
            let frameNs: UInt64 = 16_000_000

            // Snap-Ziel wird im Moment des Loslassens festgenagelt: diejenige Karte,
            // die genau jetzt der Frontmitte am nächsten ist. Damit landet der Ring
            // garantiert auf der Karte, die der Nutzer beim Release sieht — selbst
            // wenn der kurze Nachlauf (Glide) sonst auf eine andere Karte rutschen
            // würde. Off-by-one durch späte Neuberechnung ist damit ausgeschlossen.
            let releaseAngle = ringAngle
            let releaseTargetIdx = Int((releaseAngle / step).rounded())
            let snapTarget = Float(releaseTargetIdx) * step

            // Glide-Phase: Geschwindigkeit klingt exponentiell ab.
            while !Task.isCancelled && abs(ringVelocity) > ringMomentumMinSpeed {
                let newAngle = ringAngle + ringVelocity * frameSec
                ringAngle = newAngle
                ringEntity.transform.rotation = simd_quatf(angle: newAngle, axis: [0, 1, 0])
                ringVelocity *= ringMomentumDamping
                aktualisiereFrontIndex()
                try? await Task.sleep(nanoseconds: frameNs)
            }
            if Task.isCancelled { return }

            // Snap-Phase: weich auf die beim Loslassen gemerkte Karte einrasten.
            let startAngle = ringAngle
            let diff = snapTarget - startAngle
            let snapDuration: Float = 0.35
            let steps = max(1, Int(snapDuration / frameSec))
            for i in 1...steps {
                if Task.isCancelled { return }
                let t = Float(i) / Float(steps)
                let eased = 1 - pow(1 - t, 3)
                let a = startAngle + diff * eased
                ringAngle = a
                ringEntity.transform.rotation = simd_quatf(angle: a, axis: [0, 1, 0])
                try? await Task.sleep(nanoseconds: frameNs)
            }
            if Task.isCancelled { return }

            ringAngle = snapTarget
            ringEntity.transform.rotation = simd_quatf(angle: snapTarget, axis: [0, 1, 0])
            ringVelocity = 0
            aktualisiereFrontIndex()
            ringInteracting = false
            momentumTask = nil
        }
    }

    // Tap auf eine seitliche Karte (Root) — Ring weich auf diesen Index drehen,
    // statt direkt aktuellerIndex zu setzen. Wählt die kürzeste Bogenrichtung.
    func rotiereZuIndex(_ index: Int) {
        let count = sichtbareThemen.count
        guard count > 0 else { return }
        momentumTask?.cancel()
        ringInteracting = true

        let step: Float = 2 * Float.pi / Float(count)
        var target = Float(index) * step
        var diff = target - ringAngle
        let twoPi: Float = 2 * Float.pi
        while diff > Float.pi { target -= twoPi; diff = target - ringAngle }
        while diff < -Float.pi { target += twoPi; diff = target - ringAngle }
        let startAngle = ringAngle

        momentumTask = Task { @MainActor in
            let frameSec: Float = 1.0 / 60.0
            let frameNs: UInt64 = 16_000_000
            let dur: Float = 0.45
            let steps = max(1, Int(dur / frameSec))
            for i in 1...steps {
                if Task.isCancelled { return }
                let t = Float(i) / Float(steps)
                let eased = 1 - pow(1 - t, 3)
                let a = startAngle + diff * eased
                ringAngle = a
                ringEntity.transform.rotation = simd_quatf(angle: a, axis: [0, 1, 0])
                aktualisiereFrontIndex()
                try? await Task.sleep(nanoseconds: frameNs)
            }
            if Task.isCancelled { return }
            ringAngle = target
            ringEntity.transform.rotation = simd_quatf(angle: target, axis: [0, 1, 0])
            aktuellerIndex = ((index % count) + count) % count
            ringInteracting = false
            momentumTask = nil
        }
    }

    func loeseLeseModusAus(panelName: String) {
        if panelName.hasPrefix("thema_") {
            let uuidString = String(panelName.dropFirst("thema_".count))
            if let thema = aktuelleThemen.first(where: { $0.id.uuidString == uuidString }) {
                leseThema = thema
                leseModusAktiv = true
            }
        } else if panelName.hasPrefix("child_") {
            let uuidString = String(panelName.dropFirst("child_".count))
            if let thema = childrenThemen.first(where: { $0.id.uuidString == uuidString }) {
                leseThema = thema
                leseModusAktiv = true
            }
        }
    }
}
