import SwiftUI
import RealityKit
import RealityKitContent

struct GenericRoomView: View {
    let skyboxTextureName: String

    @Environment(AppModel.self) private var appModel
    @Environment(\.openWindow) var openWindow

    @State private var aktuelleThemen: [Thema] = []
    @State private var fokusThema: Thema? = nil
    @State private var childrenThemen: [Thema] = []
    @State private var pfad: [Thema] = []
    @State private var status = "Lade..."

    @State private var leseThema: Thema? = nil
    @State private var leseModusAktiv = false

    @State private var panelsEingeblendet = false
    @State private var aktuellerIndex: Int = 0

    @State private var baumScale: Float = 1.0
    @State private var scaleStart: Float = 1.0

    @State private var aktivGehaltenesPanel: String? = nil
    @State private var holdTask: Task<Void, Never>? = nil
    @State private var holdTriggered = false
    @State private var breadcrumbExpanded: Bool = false
    @State private var navigiertTiefer: Bool = true

    @State private var rootEntity: Entity = Entity()

    private let themenService = ThemenService()

    private var isRootLevel: Bool {
        fokusThema == nil
    }

    private var sichtbareThemen: [Thema] {
        if fokusThema != nil {
            return childrenThemen
        } else {
            return aktuelleThemen
        }
    }

    var body: some View {
        RealityView { content, attachments in
            // --- Skybox ---
            var skyboxMaterial = UnlitMaterial()
            if let texture = try? await TextureResource(named: skyboxTextureName) {
                skyboxMaterial.color = .init(texture: .init(texture))
            }
            let skybox = ModelEntity(
                mesh: .generateSphere(radius: 50),
                materials: [skyboxMaterial]
            )
            skybox.scale = SIMD3<Float>(x: -1, y: 1, z: 1)
            content.add(skybox)

            rootEntity.position = .zero
            content.add(rootEntity)

            if let debug = attachments.entity(for: "debug") {
                debug.position = SIMD3<Float>(0, 2.2, -2)
                content.add(debug)
            }
            if let zurueck = attachments.entity(for: "zurueck") {
                zurueck.name = "zurueck_btn"
                zurueck.position = SIMD3<Float>(0, -10, -2)
                rootEntity.addChild(zurueck)
            }

        } update: { content, attachments in

            // === LESE-PANEL ===
            if leseModusAktiv, let lese = leseThema {
                if let lesePanel = attachments.entity(for: "lese_\(lese.id.uuidString)") {
                    lesePanel.position = SIMD3<Float>(0, 1.5, -1.8)
                    lesePanel.name = "lese_\(lese.id.uuidString)"

                    if lesePanel.components[InputTargetComponent.self] == nil {
                        lesePanel.components.set(InputTargetComponent(allowedInputTypes: .all))
                        lesePanel.components.set(CollisionComponent(shapes: [.generateBox(size: SIMD3<Float>(1.5, 1.0, 0.05))]))
                    }
                    rootEntity.addChild(lesePanel)
                }
                rootEntity.scale = SIMD3<Float>(repeating: baumScale)
                return
            }

            // === BREADCRUMB STACK ===
            // Collapsed: front card (current) at bottom of scene, ancestors peek behind in 3D depth.
            // Expanded: vertical list — most recent at top, older ancestors below, home at bottom.
            // idx 0 = fokusThema (most recent), idx n-1 = oldest ancestor.
            if let fokus = fokusThema {
                let breadcrumbPfad: [Thema] = (pfad + [fokus]).reversed()

                // Collapsed: tight card-deck stack at mid-height. Front card fully readable;
                // ancestors peek out by a few cm from the bottom edge (lower Y, slightly back in Z).
                let collapsedFrontY: Float = 1.05
                let collapsedFrontZ: Float = -1.70
                let collapsedStepY: Float = -0.030
                let collapsedStepZ: Float = 0.012

                // Expanded: vertical list pulled into the user's direct forward view, vertically
                // centered around eye level so the whole stack sits "in your face".
                let expandedSpacing: Float = 0.30
                let expandedCenterY: Float = 1.40
                let expandedZ: Float = -1.55
                let nExpandedTotal = breadcrumbPfad.count + 1 // +1 for home button at bottom
                let expandedTopY = expandedCenterY + Float(nExpandedTotal - 1) * expandedSpacing / 2.0

                for (idx, thema) in breadcrumbPfad.enumerated() {
                    let attachmentID = "crumb_\(thema.id.uuidString)"

                    if let panel = attachments.entity(for: attachmentID) {
                        panel.name = attachmentID

                        if panel.components[InputTargetComponent.self] == nil {
                            panel.components.set(InputTargetComponent(allowedInputTypes: .all))
                            panel.components.set(CollisionComponent(shapes: [.generateBox(size: SIMD3<Float>(1.1, 0.32, 0.05))]))
                        }

                        let targetY: Float
                        let targetZ: Float

                        if breadcrumbExpanded {
                            targetY = expandedTopY - Float(idx) * expandedSpacing
                            targetZ = expandedZ
                        } else {
                            targetY = collapsedFrontY + Float(idx) * collapsedStepY
                            targetZ = collapsedFrontZ - Float(idx) * collapsedStepZ
                        }

                        if panel.parent == nil {
                            panel.position = SIMD3<Float>(0, targetY + 0.4, targetZ)
                            rootEntity.addChild(panel)
                        }

                        let crumbTransform = Transform(
                            scale: SIMD3<Float>(repeating: 1.0),
                            rotation: simd_quatf(angle: 0, axis: [0, 1, 0]),
                            translation: SIMD3<Float>(0, targetY, targetZ)
                        )
                        panel.move(to: crumbTransform, relativeTo: nil, duration: 0.4, timingFunction: .easeInOut)
                    }
                }
            }

            // === POSITIONIERUNG DER THEMEN ===
            for (index, thema) in sichtbareThemen.enumerated() {
                let attachmentID = fokusThema != nil
                    ? "child_\(thema.id.uuidString)"
                    : "thema_\(thema.id.uuidString)"

                if let panel = attachments.entity(for: attachmentID) {
                    panel.name = attachmentID

                    if panel.components[InputTargetComponent.self] == nil {
                        panel.components.set(InputTargetComponent(allowedInputTypes: .all))
                        panel.components.set(CollisionComponent(shapes: [.generateBox(size: SIMD3<Float>(0.95, 0.35, 0.05))]))
                    }

                    let gesamtBreite = Float(sichtbareThemen.count - 1) * 1.1
                    let startX = -gesamtBreite / 2.0
                    let xPos = startX + Float(index) * 1.1

                    var zielPosition: SIMD3<Float>
                    var zielScale: Float
                    var zielRotation: simd_quatf
                    var animDuration: Double

                    if isRootLevel {
                        // --- KREIS: Karten ringförmig um den Nutzer auf Augenhöhe ---
                        // 360° gleichmäßig auf alle Themen verteilt; aktuellerIndex sitzt
                        // an der Frontposition (theta = 0). Swipe rotiert den Ring.
                        // Karten stehen im Weltraum — Kopfbewegung bleibt vollständig frei.
                        let nCards = max(sichtbareThemen.count, 1)
                        let angleStep = 2 * Float.pi / Float(nCards)
                        let radius: Float = 2.5
                        let cardY: Float = 1.5

                        let theta = (Float(index) - Float(aktuellerIndex)) * angleStep
                        zielPosition = SIMD3<Float>(radius * sin(theta), cardY, -radius * cos(theta))
                        zielScale = (index == aktuellerIndex) ? 1.2 : 1.0
                        // Karte zur Mitte (Nutzer) drehen
                        zielRotation = simd_quatf(angle: -theta, axis: [0, 1, 0])
                        animDuration = 0.5

                    } else {
                        // --- FOKUS: Children flach aufgereiht (immer sichtbar) ---
                        zielPosition = SIMD3<Float>(xPos, 1.55, -2.5)
                        zielScale = 1.0
                        zielRotation = simd_quatf(angle: 0, axis: [0, 1, 0])
                        animDuration = 0.175
                    }

                    if panel.parent == nil {
                        if !isRootLevel {
                            // Fly in from above when going deeper, from below when going back up
                            let yOffset: Float = navigiertTiefer ? 1.5 : -1.5
                            panel.position = SIMD3<Float>(zielPosition.x, zielPosition.y + yOffset, zielPosition.z)
                        }
                        rootEntity.addChild(panel)
                    }

                    let transform = Transform(
                        scale: SIMD3<Float>(repeating: zielScale),
                        rotation: zielRotation,
                        translation: zielPosition
                    )
                    panel.move(to: transform, relativeTo: nil, duration: animDuration, timingFunction: .easeOut)
                }
            }

            // === HOME BUTTON ===
            // Root view: floats below the gallery.
            // Focus view + expanded breadcrumb: sits at the very bottom of the vertical list.
            // Focus view + collapsed: hidden off-screen.
            if let zuBtn = rootEntity.findEntity(named: "zurueck_btn") {
                let btnTarget: SIMD3<Float>
                if fokusThema == nil {
                    btnTarget = SIMD3<Float>(0, 1.1, -1.7)
                } else if breadcrumbExpanded {
                    let nExpandedTotal = pfad.count + 2 // breadcrumbs (fokus + ancestors) + home
                    let expandedSpacing: Float = 0.30
                    let expandedCenterY: Float = 1.40
                    let expandedZ: Float = -1.55
                    let bottomY = expandedCenterY - Float(nExpandedTotal - 1) * expandedSpacing / 2.0
                    btnTarget = SIMD3<Float>(0, bottomY, expandedZ)
                } else {
                    btnTarget = SIMD3<Float>(0, -10, -2)
                }
                zuBtn.move(to: Transform(translation: btnTarget), relativeTo: nil, duration: 0.4, timingFunction: .easeInOut)
            }

            rootEntity.scale = SIMD3<Float>(repeating: baumScale)

        } attachments: {
            Attachment(id: "debug") {
                Text(status).font(.caption).foregroundColor(.yellow).padding(8).background(.black.opacity(0.5)).cornerRadius(8)
            }

            Attachment(id: "zurueck") { zurueckButton() }

            if let fokus = fokusThema {
                let breadcrumbPfad: [Thema] = (pfad + [fokus]).reversed()
                ForEach(breadcrumbPfad) { thema in
                    Attachment(id: "crumb_\(thema.id.uuidString)") {
                        crumbPanel(thema: thema, isFront: thema.id == fokus.id)
                    }
                }
            }

            if leseModusAktiv, let lese = leseThema {
                Attachment(id: "lese_\(lese.id.uuidString)") {
                    lesePanel(thema: lese)
                }
            }

            if fokusThema == nil && !leseModusAktiv {
                ForEach(aktuelleThemen) { thema in
                    Attachment(id: "thema_\(thema.id.uuidString)") {
                        let isFront = aktuelleThemen.firstIndex(where: { $0.id == thema.id }) == aktuellerIndex
                        themaPanel(thema: thema, isFront: isFront)
                    }
                }
            }

            if fokusThema != nil && !leseModusAktiv {
                ForEach(Array(childrenThemen.enumerated()), id: \.element.id) { index, thema in
                    Attachment(id: "child_\(thema.id.uuidString)") {
                        themaPanel(thema: thema, isFront: false, isActiveChild: true, animationDelay: 0.3 + Double(index) * 0.07, hideWhenExpanded: true)
                    }
                }
            }
        }
        .gesture(tapGesture)
        .gesture(swipeGesture)
        .gesture(holdGesture)
        .gesture(zoomGesture)
        .task { await ladeErsteEbene() }
    }

    // MARK: - Gesten

    private var tapGesture: some Gesture {
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
                    let uuidString = String(name.dropFirst("thema_".count))
                    if let tappedIndex = aktuelleThemen.firstIndex(where: { $0.id.uuidString == uuidString }) {
                        if tappedIndex == aktuellerIndex {
                            // Vorderstes Thema → Fokus-Modus
                            let thema = aktuelleThemen[tappedIndex]
                            Task { await themaAusgewaehlt(thema: thema) }
                        } else {
                            // Seitliches Thema → nach vorne holen
                            withAnimation { aktuellerIndex = tappedIndex }
                        }
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

    // Swipe nur in der Galerie (Root) — rotiert den Ring zyklisch
    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .targetedToAnyEntity()
            .onEnded { value in
                guard isRootLevel else { return }
                let count = aktuelleThemen.count
                guard count > 0 else { return }
                let translation = value.translation3D
                if abs(translation.x) > 0.02 {
                    if translation.x < 0 {
                        withAnimation { aktuellerIndex = (aktuellerIndex + 1) % count }
                    } else {
                        withAnimation { aktuellerIndex = (aktuellerIndex - 1 + count) % count }
                    }
                }
            }
    }

    private var holdGesture: some Gesture {
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

    private func loeseLeseModusAus(panelName: String) {
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

    private var zoomGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                baumScale = max(0.4, min(2.5, scaleStart * Float(value.magnification)))
            }
            .onEnded { _ in scaleStart = baumScale }
    }

    // MARK: - Panel Views

    @ViewBuilder
    private func themaPanel(thema: Thema, isFront: Bool, isActiveChild: Bool = false, animationDelay: Double = 0, hideWhenExpanded: Bool = false) -> some View {
        let isGehalten = aktivGehaltenesPanel == "thema_\(thema.id.uuidString)"
                      || aktivGehaltenesPanel == "child_\(thema.id.uuidString)"
        let childHidden = hideWhenExpanded && breadcrumbExpanded

        Text(thema.name)
            .font(isActiveChild ? .system(size: 54, weight: .bold) : .extraLargeTitle)
            .fontWeight(isActiveChild ? .bold : (isFront ? .bold : .semibold))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.9), radius: 4, x: 0, y: 1)
            .multilineTextAlignment(.center)
            .frame(minWidth: isActiveChild ? 300 : 260)
            .padding(.horizontal, isActiveChild ? 56 : 48)
            .padding(.vertical, isActiveChild ? 40 : 32)
            .background {
                ZStack {
                    // Solid dark base guarantees readability on any 3D background
                    RoundedRectangle(cornerRadius: 28)
                        .fill(.black.opacity(isActiveChild ? 0.78 : 0.68))

                    RoundedRectangle(cornerRadius: 28)
                        .fill(.ultraThinMaterial.opacity(0.5))

                    if isActiveChild {
                        RoundedRectangle(cornerRadius: 28)
                            .fill(LinearGradient(
                                colors: [.white.opacity(0.18), .cyan.opacity(0.10), .clear],
                                startPoint: .top, endPoint: .bottom
                            ))
                        RoundedRectangle(cornerRadius: 28)
                            .stroke(LinearGradient(
                                colors: [.white.opacity(0.95), .cyan.opacity(0.65), .white.opacity(0.55)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ), lineWidth: 2.5)
                    } else if isFront {
                        RoundedRectangle(cornerRadius: 28)
                            .fill(LinearGradient(
                                colors: [.white.opacity(0.15), .blue.opacity(0.05), .clear],
                                startPoint: .top, endPoint: .bottom
                            ))
                        RoundedRectangle(cornerRadius: 28)
                            .stroke(LinearGradient(
                                colors: [.white.opacity(0.7), .blue.opacity(0.3), .white.opacity(0.3)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ), lineWidth: 2.0)
                    } else {
                        RoundedRectangle(cornerRadius: 28)
                            .fill(LinearGradient(
                                stops: [.init(color: .white.opacity(0.08), location: 0), .init(color: .clear, location: 0.4)],
                                startPoint: .top, endPoint: .bottom
                            ))
                        RoundedRectangle(cornerRadius: 28)
                            .stroke(.white.opacity(0.35), lineWidth: 1.5)
                    }

                    // Hold-Feedback: pulsierender blauer Glow-Ring
                    if isGehalten {
                        RoundedRectangle(cornerRadius: 28)
                            .stroke(
                                LinearGradient(
                                    colors: [.blue, .cyan, .blue],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                ),
                                lineWidth: 3.0
                            )
                            .blur(radius: 1.5)
                    }
                }
            }
            .shadow(
                color: isGehalten ? .cyan.opacity(0.7) : (isActiveChild ? .cyan.opacity(0.55) : (isFront ? .blue.opacity(0.4) : .black.opacity(0.4))),
                radius: isGehalten ? 40 : (isActiveChild ? 38 : (isFront ? 30 : 15)),
                y: isActiveChild || isFront ? 12 : 6
            )
            .hoverEffect(.highlight)
            .scaleEffect((panelsEingeblendet ? 1.0 : 0.7) * (isGehalten ? 1.06 : 1.0))
            .opacity(panelsEingeblendet && !childHidden ? 1.0 : 0.0)
            .animation(.spring(response: 0.5, dampingFraction: 0.75).delay(animationDelay), value: panelsEingeblendet)
            .animation(.easeOut(duration: 0.175), value: childHidden)
            .animation(.easeOut(duration: 0.25), value: isGehalten)
    }

    @ViewBuilder
    private func crumbPanel(thema: Thema, isFront: Bool) -> some View {
        let textVisible = isFront || breadcrumbExpanded
        HStack(spacing: 14) {
            Image(systemName: "chevron.left")
                .font(.title2).fontWeight(.medium)
                .foregroundColor(.white.opacity(0.75))
                .shadow(color: .black.opacity(0.9), radius: 3, x: 0, y: 1)
                .opacity(textVisible ? 1 : 0)
            Text(thema.name)
                .font(.title).fontWeight(.semibold)
                .foregroundStyle(.white.opacity(0.85))
                .shadow(color: .black.opacity(0.9), radius: 3, x: 0, y: 1)
                .opacity(textVisible ? 1 : 0)
        }
        .animation(.easeInOut(duration: 0.3), value: textVisible)
        .padding(.horizontal, 40)
        .padding(.vertical, 22)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 28).fill(.black.opacity(0.72))
                RoundedRectangle(cornerRadius: 28).fill(.ultraThinMaterial.opacity(0.4))
                RoundedRectangle(cornerRadius: 28).fill(LinearGradient(
                    stops: [
                        .init(color: .white.opacity(0.08), location: 0),
                        .init(color: .clear, location: 0.6)
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
                RoundedRectangle(cornerRadius: 28).stroke(
                    .white.opacity(0.35),
                    lineWidth: 1.2
                )
            }
        }
        .shadow(color: .black.opacity(0.35), radius: 14, y: 6)
        .hoverEffect(.highlight)
        .scaleEffect(panelsEingeblendet ? 1.0 : 0.85)
        .opacity(panelsEingeblendet ? 1.0 : 0.0)
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: panelsEingeblendet)
    }

    @ViewBuilder
    private func lesePanel(thema: Thema) -> some View {
        let beschreibung = thema.description?.trimmingCharacters(in: .whitespacesAndNewlines)
        let hatBeschreibung = !(beschreibung?.isEmpty ?? true)

        VStack(spacing: 20) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Info")
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundColor(.blue.opacity(0.85))
                        .textCase(.uppercase)
                        .tracking(1.5)
                    Text(thema.name)
                        .font(.extraLargeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundColor(.white.opacity(0.5))
            }
            Divider().overlay(.white.opacity(0.3))
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if hatBeschreibung, let text = beschreibung {
                        Text(text)
                            .font(.title2)
                            .foregroundColor(.white.opacity(0.92))
                            .lineSpacing(8)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            Image(systemName: "text.alignleft")
                                .font(.system(size: 42))
                                .foregroundColor(.white.opacity(0.3))
                            Text("Für \"\(thema.name)\" ist noch keine Beschreibung hinterlegt.")
                                .font(.title2)
                                .foregroundColor(.white.opacity(0.6))
                                .lineSpacing(6)
                        }
                        .padding(.vertical, 20)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(width: 700, height: 500)
        .padding(40)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 32)
                    .fill(.black.opacity(0.4))

                RoundedRectangle(cornerRadius: 32)
                    .fill(.ultraThinMaterial)

                RoundedRectangle(cornerRadius: 32)
                    .fill(LinearGradient(
                        stops: [.init(color: .white.opacity(0.12), location: 0), .init(color: .clear, location: 0.3)],
                        startPoint: .top, endPoint: .bottom
                    ))

                RoundedRectangle(cornerRadius: 32)
                    .stroke(LinearGradient(
                        colors: [.white.opacity(0.5), .white.opacity(0.15), .white.opacity(0.3)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ), lineWidth: 1.5)
            }
        }
        .shadow(color: .black.opacity(0.3), radius: 30, y: 12)
        .scaleEffect(leseModusAktiv ? 1.0 : 0.5)
        .opacity(leseModusAktiv ? 1.0 : 0.0)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: leseModusAktiv)
    }

    @ViewBuilder
    private func zurueckButton() -> some View {
        Button {
            appModel.ausgewaehltesThema = nil
            openWindow(id: "main")
        } label: {
            Image("Artboard 5@300x")
                .resizable()
                .scaledToFit()
                .frame(height: 78)
                .opacity(0.82)
                .padding(.horizontal, 44)
                .padding(.vertical, 10)
                .background {
                    ZStack {
                        RoundedRectangle(cornerRadius: 28).fill(.black.opacity(0.72))
                        RoundedRectangle(cornerRadius: 28).fill(.ultraThinMaterial.opacity(0.4))
                        RoundedRectangle(cornerRadius: 28).fill(LinearGradient(
                            stops: [
                                .init(color: .white.opacity(0.08), location: 0),
                                .init(color: .clear, location: 0.6)
                            ],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                        RoundedRectangle(cornerRadius: 28).stroke(
                            .white.opacity(0.35),
                            lineWidth: 1.2
                        )
                    }
                }
                .shadow(color: .black.opacity(0.35), radius: 14, y: 6)
        }
        .buttonStyle(.plain)
        .hoverEffect(.highlight)
        .scaleEffect(panelsEingeblendet ? 1.0 : 0.85)
        .opacity(panelsEingeblendet ? 1.0 : 0.0)
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: panelsEingeblendet)
    }

    // MARK: - Animation

    private func animierePanels(skipBounce: Bool = false) {
        // Only remove entities that no longer belong in the new state. Persisting entities
        // stay parented so they don't re-mount and re-trigger their initial-offset move(to:),
        // which would double up on the move triggered by the state change itself.
        let validCrumb: Set<String>
        let validChild: Set<String>
        let validThema: Set<String>
        if let fokus = fokusThema {
            validCrumb = Set((pfad + [fokus]).map { "crumb_\($0.id.uuidString)" })
            validChild = Set(childrenThemen.map { "child_\($0.id.uuidString)" })
            validThema = []
        } else {
            validCrumb = []
            validChild = []
            validThema = Set(aktuelleThemen.map { "thema_\($0.id.uuidString)" })
        }

        let stale = rootEntity.children.filter { entity in
            if entity.name.hasPrefix("crumb_") { return !validCrumb.contains(entity.name) }
            if entity.name.hasPrefix("child_") { return !validChild.contains(entity.name) }
            if entity.name.hasPrefix("thema_") { return !validThema.contains(entity.name) }
            return false
        }
        stale.forEach { $0.removeFromParent() }

        if skipBounce {
            // Back-navigation: only the RealityView move(to:) translation should animate
            // (fokus drops into stack, children slide in from below). Skip the
            // panelsEingeblendet opacity+scale spring so it doesn't double up.
            panelsEingeblendet = true
        } else {
            panelsEingeblendet = false
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.1)) {
                panelsEingeblendet = true
            }
        }
    }

    // MARK: - Navigation

    private func ladeErsteEbene() async {
        guard let thema = appModel.ausgewaehltesThema else {
            status = "Kein Thema ausgewählt"
            return
        }
        pfad = []
        fokusThema = nil
        childrenThemen = []
        leseModusAktiv = false
        leseThema = nil
        aktuellerIndex = 0
        await ladeChildren(vonThemaId: thema.id)
        animierePanels()
    }

    private func ladeChildren(vonThemaId id: UUID) async {
        status = "Lade..."
        do {
            let children = try await themenService.getUnterthemen(vonThemaId: id)
            aktuelleThemen = children
            status = "\(children.count) Themen"
        } catch {
            status = "Fehler: \(error.localizedDescription)"
        }
    }

    private func themaAusgewaehlt(thema: Thema) async {
        status = "Lade \(thema.name)..."
        do {
            let children = try await themenService.getUnterthemen(vonThemaId: thema.id)
            if children.isEmpty {
                leseThema = thema
                leseModusAktiv = true
                status = "\(thema.name) – Lesemodus"
                return
            }
            navigiertTiefer = true
            fokusThema = thema
            childrenThemen = children
            breadcrumbExpanded = false
            status = "\(children.count) Unterthemen"
            animierePanels()
        } catch {
            status = "Fehler: \(error.localizedDescription)"
        }
    }

    private func childAusgewaehlt(thema: Thema) async {
        status = "Lade \(thema.name)..."
        do {
            let children = try await themenService.getUnterthemen(vonThemaId: thema.id)
            if children.isEmpty {
                leseThema = thema
                leseModusAktiv = true
                status = "\(thema.name) – Lesemodus"
                return
            }
            if let fokus = fokusThema { pfad.append(fokus) }
            aktuelleThemen = childrenThemen
            navigiertTiefer = true
            fokusThema = thema
            childrenThemen = children
            breadcrumbExpanded = false
            status = "\(children.count) Unterthemen"
            animierePanels()
        } catch {
            status = "Fehler: \(error.localizedDescription)"
        }
    }

    private func zurueckEineEbene() async {
        navigiertTiefer = false
        breadcrumbExpanded = false
        if let letztesImPfad = pfad.last {
            pfad.removeLast()
            fokusThema = letztesImPfad
            childrenThemen = aktuelleThemen
            let parentId = letztesImPfad.parentId ?? appModel.ausgewaehltesThema?.id
            if let pid = parentId {
                do {
                    aktuelleThemen = try await themenService.getUnterthemen(vonThemaId: pid)
                } catch {
                    status = "Fehler: \(error.localizedDescription)"
                }
            }
        } else {
            fokusThema = nil
            childrenThemen = []
            aktuellerIndex = 0
            status = "\(aktuelleThemen.count) Themen"
        }
        animierePanels(skipBounce: true)
    }

    private func zurueckZuAncestor(thema: Thema) async {
        guard let fokus = fokusThema else { return }
        let vollPfad = pfad + [fokus]
        guard let idx = vollPfad.firstIndex(where: { $0.id == thema.id }) else { return }

        pfad = Array(vollPfad[0..<idx])
        fokusThema = thema
        navigiertTiefer = false
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

        animierePanels(skipBounce: true)
    }
}
