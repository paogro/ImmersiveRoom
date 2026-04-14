import SwiftUI
import RealityKit
import RealityKitContent

// Speichert den exakten Zustand für den Zurück-Button
struct NavigationState {
    let aktuelleThemen: [Thema]
    let fokusThema: Thema?
    let childrenThemen: [Thema]
    let aktuellerIndex: Int
}

struct SportRoomView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.openWindow) var openWindow

    // --- STATUS / GLIEDERUNG ---
    @State private var aktuelleThemen: [Thema] = []
    @State private var fokusThema: Thema? = nil
    @State private var childrenThemen: [Thema] = []

    @State private var aktuellerIndex: Int = 0
    @State private var pfad: [NavigationState] = []
    @State private var status = "Lade..."

    // Sichtbare Panels: Dynamisch zusammengebaut
    private var currentStack: [Thema] {
        guard let fokus = fokusThema else {
            return aktuelleThemen // Ebene 0: Galerie
        }
        return [fokus] + childrenThemen // Ebene 1+: Fokus vorne, Kinder dahinter
    }

    private var isRootLevel: Bool {
        fokusThema == nil
    }

    // Animation & UI
    @State private var panelsEingeblendet = false
    @State private var leseThema: Thema? = nil
    @State private var leseModusAktiv = false
    @State private var baumScale: Float = 1.0
    @State private var scaleStart: Float = 1.0

    @State private var rootEntity: Entity = Entity()
    private let themenService = ThemenService()

    var body: some View {
        RealityView { content, attachments in
            // --- Skybox ---
            let skybox = ModelEntity(
                mesh: .generateSphere(radius: 50),
                materials: [UnlitMaterial(color: UIColor(red: 0.05, green: 0.05, blue: 0.15, alpha: 1.0))]
            )
            skybox.scale = SIMD3<Float>(x: -1, y: 1, z: 1)
            let skyAnchor = AnchorEntity(.head)
            skyAnchor.anchoring.trackingMode = .continuous
            skyAnchor.addChild(skybox)
            content.add(skyAnchor)

            rootEntity.position = .zero
            content.add(rootEntity)

            if let debug = attachments.entity(for: "debug") {
                debug.position = SIMD3<Float>(0, 2.2, -2)
                content.add(debug)
            }
            if let zurueck = attachments.entity(for: "zurueck") {
                zurueck.position = SIMD3<Float>(0, 0.6, -1.8)
                content.add(zurueck)
            }

        } update: { content, attachments in

            // --- Alte Panels aufräumen, die nicht mehr im Stack sind ---
            let aktuelleIDs = Set(currentStack.map { "thema_\($0.id.uuidString)" })
            for child in rootEntity.children where child.name.hasPrefix("thema_") {
                if !aktuelleIDs.contains(child.name) {
                    child.removeFromParent()
                }
            }

            // === LESE-PANEL ===
            if leseModusAktiv, let lese = leseThema {
                if let lesePanel = attachments.entity(for: "lese_\(lese.id.uuidString)") {
                    lesePanel.position = SIMD3<Float>(0, 1.5, -1.2)
                    lesePanel.name = "lese_\(lese.id.uuidString)"

                    if lesePanel.components[InputTargetComponent.self] == nil {
                        lesePanel.components.set(InputTargetComponent(allowedInputTypes: .all))
                        lesePanel.components.set(CollisionComponent(shapes: [.generateBox(size: SIMD3<Float>(1.5, 1.0, 0.05))]))
                    }
                    if lesePanel.parent == nil {
                        rootEntity.addChild(lesePanel)
                    }
                }

                // Themen-Panels ausblenden während Lesemodus
                for thema in currentStack {
                    attachments.entity(for: "thema_\(thema.id.uuidString)")?.isEnabled = false
                }
                rootEntity.scale = SIMD3<Float>(repeating: baumScale)
                return
            }

            // Alle Themen-Panels wieder einblenden
            for thema in currentStack {
                attachments.entity(for: "thema_\(thema.id.uuidString)")?.isEnabled = true
            }

            // === POSITIONIERUNG DER THEMEN ===
            for (index, thema) in currentStack.enumerated() {
                guard let panel = attachments.entity(for: "thema_\(thema.id.uuidString)") else { continue }

                panel.name = "thema_\(thema.id.uuidString)"

                // Interaktion nur einmal einrichten
                if panel.components[InputTargetComponent.self] == nil {
                    panel.components.set(InputTargetComponent(allowedInputTypes: .all))
                    panel.components.set(CollisionComponent(shapes: [.generateBox(size: SIMD3<Float>(0.8, 0.3, 0.05))]))
                }
                if panel.parent == nil {
                    rootEntity.addChild(panel)
                }

                let distanz = index - aktuellerIndex
                var zielPosition: SIMD3<Float>
                var zielScale: Float

                if isRootLevel {
                    // --- EBENE 0: GERADE GALERIE ---
                    let xOffset = Float(distanz) * 1.1

                    if distanz == 0 {
                        zielPosition = SIMD3<Float>(0, 1.4, -1.2)
                        zielScale = 1.2
                    } else {
                        let zOffset = abs(Float(distanz)) * 0.2
                        zielPosition = SIMD3<Float>(xOffset, 1.4, -1.2 - zOffset)
                        zielScale = max(0.6, 1.2 - (abs(Float(distanz)) * 0.25))
                    }
                } else {
                    // --- EBENE 1+: FOKUS VORNE, KINDER DAHINTER ---
                    if distanz < 0 {
                        // Weggewischt → sauber nach unten verschwinden
                        zielPosition = SIMD3<Float>(Float(distanz) * 0.5, 0.5, -0.8)
                        zielScale = 0.001
                    } else if distanz == 0 {
                        // Vorderste Karte
                        zielPosition = SIMD3<Float>(0, 1.4, -0.8)
                        zielScale = 1.4
                    } else {
                        // Kinder dahinter gestapelt
                        let tiefe = Float(distanz) * 0.8
                        let hoehenVersatz = Float(distanz) * 0.15
                        zielPosition = SIMD3<Float>(0, 1.4 + hoehenVersatz, -0.8 - tiefe)
                        zielScale = max(0.4, 1.4 - (Float(distanz) * 0.35))
                    }
                }

                let zielRotation = simd_quatf(angle: 0, axis: [0, 1, 0])
                let transform = Transform(
                    scale: SIMD3<Float>(repeating: zielScale),
                    rotation: zielRotation,
                    translation: zielPosition
                )
                panel.move(to: transform, relativeTo: nil, duration: 0.5, timingFunction: .easeInOut)
            }

            rootEntity.scale = SIMD3<Float>(repeating: baumScale)

        } attachments: {
            Attachment(id: "debug") {
                Text(status)
                    .font(.caption)
                    .foregroundColor(.yellow)
                    .padding(8)
                    .background(.black.opacity(0.5))
                    .cornerRadius(8)
            }

            Attachment(id: "zurueck") {
                zurueckButton()
            }

            if leseModusAktiv, let lese = leseThema {
                Attachment(id: "lese_\(lese.id.uuidString)") {
                    lesePanel(thema: lese)
                }
            }

            ForEach(currentStack) { thema in
                let isFront = currentStack.firstIndex(where: { $0.id == thema.id }) == aktuellerIndex
                Attachment(id: "thema_\(thema.id.uuidString)") {
                    themaPanel(thema: thema, isFront: isFront)
                }
            }
        }
        .gesture(tapGesture)
        .gesture(swipeGesture)
        .gesture(zoomGesture)
        .task { await ladeErsteEbene() }
    }

    // MARK: - Navigation

    private func ladeErsteEbene() async {
        guard let sportThema = appModel.ausgewaehltesThema else { return }
        pfad = []
        leseModusAktiv = false
        leseThema = nil
        fokusThema = nil
        childrenThemen = []

        do {
            let children = try await themenService.getUnterthemen(vonThemaId: sportThema.id)
            aktuelleThemen = children
            aktuellerIndex = 0
            status = "Galerie: \(children.count) Themen"
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                panelsEingeblendet = true
            }
        } catch {
            status = "Fehler: \(error.localizedDescription)"
        }
    }

    private func drillDown(into thema: Thema) async {
        status = "Lade \(thema.name)..."

        do {
            let children = try await themenService.getUnterthemen(vonThemaId: thema.id)

            if children.isEmpty {
                // Blatt-Thema → Lesemodus
                leseThema = thema
                leseModusAktiv = true
                status = "\(thema.name) – Lesemodus"
            } else {
                // Hat Kinder → eine Ebene tiefer
                let snapshot = NavigationState(
                    aktuelleThemen: aktuelleThemen,
                    fokusThema: fokusThema,
                    childrenThemen: childrenThemen,
                    aktuellerIndex: aktuellerIndex
                )
                pfad.append(snapshot)

                panelsEingeblendet = false

                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(150))
                    fokusThema = thema
                    childrenThemen = children
                    aktuellerIndex = 0
                    status = "\(thema.name) + \(children.count) Unterthemen"

                    try? await Task.sleep(for: .milliseconds(100))
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                        panelsEingeblendet = true
                    }
                }
            }
        } catch {
            status = "Fehler: \(error.localizedDescription)"
        }
    }

    private func navigiereZurueck() {
        if leseModusAktiv {
            // Zuerst Lesemodus schließen
            leseModusAktiv = false
            leseThema = nil
            return
        }

        if let lastState = pfad.popLast() {
            panelsEingeblendet = false

            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(150))
                aktuelleThemen = lastState.aktuelleThemen
                fokusThema = lastState.fokusThema
                childrenThemen = lastState.childrenThemen
                aktuellerIndex = lastState.aktuellerIndex

                try? await Task.sleep(for: .milliseconds(100))
                withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                    panelsEingeblendet = true
                }
            }
        } else {
            // Ganz raus → zurück zum Hauptmenü
            appModel.ausgewaehltesThema = nil
            openWindow(id: "main")
        }
    }

    // MARK: - Gesten

    private var tapGesture: some Gesture {
        SpatialTapGesture()
            .targetedToAnyEntity()
            .onEnded { value in
                let name = value.entity.name

                // Lese-Panel schließen bei Tap
                if name.hasPrefix("lese_") {
                    leseModusAktiv = false
                    leseThema = nil
                    return
                }

                guard name.hasPrefix("thema_") else { return }
                let uuidString = String(name.dropFirst("thema_".count))

                guard let tappedIndex = currentStack.firstIndex(where: {
                    $0.id.uuidString == uuidString
                }) else { return }

                if tappedIndex == aktuellerIndex {
                    // Vorderste Karte angetippt → drillDown (prüft intern ob Blatt)
                    let thema = currentStack[tappedIndex]
                    Task { await drillDown(into: thema) }
                } else {
                    // Hintere/seitliche Karte → nach vorne holen
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        aktuellerIndex = tappedIndex
                    }
                }
            }
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .targetedToAnyEntity()
            .onEnded { value in
                let translationX = value.translation3D.x
                guard abs(translationX) > 0.02 else { return }

                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    if translationX < 0 {
                        aktuellerIndex = min(currentStack.count - 1, aktuellerIndex + 1)
                    } else {
                        aktuellerIndex = max(0, aktuellerIndex - 1)
                    }
                }
            }
    }

    private var zoomGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                baumScale = max(0.4, min(2.5, scaleStart * Float(value.magnification)))
            }
            .onEnded { _ in
                scaleStart = baumScale
            }
    }

    // MARK: - Panel Views

    @ViewBuilder
    private func themaPanel(thema: Thema, isFront: Bool) -> some View {
        Text(thema.name)
            .font(.extraLargeTitle)
            .fontWeight(isFront ? .bold : .semibold)
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .frame(minWidth: 260)
            .padding(.horizontal, 40)
            .padding(.vertical, 32)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: 28)
                        .fill(.ultraThinMaterial)

                    if isFront {
                        RoundedRectangle(cornerRadius: 28)
                            .fill(LinearGradient(
                                colors: [.white.opacity(0.15), .clear],
                                startPoint: .top, endPoint: .bottom
                            ))
                        RoundedRectangle(cornerRadius: 28)
                            .stroke(LinearGradient(
                                colors: [.white.opacity(0.6), .white.opacity(0.2)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ), lineWidth: 2.0)
                    } else {
                        RoundedRectangle(cornerRadius: 28)
                            .stroke(.white.opacity(0.2), lineWidth: 1.0)
                    }
                }
            }
            .shadow(
                color: isFront ? .blue.opacity(0.3) : .black.opacity(0.2),
                radius: isFront ? 25 : 10,
                y: isFront ? 15 : 5
            )
            .hoverEffect(.highlight)
            .scaleEffect(panelsEingeblendet ? 1.0 : 0.7)
            .opacity(panelsEingeblendet ? 1.0 : 0.0)
    }

    @ViewBuilder
    private func zurueckButton() -> some View {
        let istLesemodus = leseModusAktiv
        let istRoot = pfad.isEmpty && !istLesemodus

        HStack(spacing: 10) {
            Image(systemName: istRoot ? "xmark.circle" : "arrow.up.left")
            Text(istRoot ? "Schließen" : (istLesemodus ? "Zurück" : "Ebene hoch"))
        }
        .font(.title3.weight(.medium))
        .foregroundColor(.white)
        .padding(.horizontal, 26)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(.white.opacity(0.3), lineWidth: 1)
        )
        .hoverEffect(.highlight)
        .onTapGesture {
            navigiereZurueck()
        }
    }

    @ViewBuilder
    private func lesePanel(thema: Thema) -> some View {
        VStack(spacing: 20) {
            HStack {
                Text(thema.name)
                    .font(.extraLargeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Spacer()
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundColor(.secondary)
            }

            Divider().overlay(.white.opacity(0.2))

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Thema: \(thema.name)")
                        .font(.title)
                        .foregroundColor(.white)
                    Text("Ebene: \(thema.level)")
                        .font(.title2)
                        .foregroundColor(.secondary)

                    if let parentId = thema.parentId {
                        Text("Parent: \(parentId.uuidString.prefix(8))...")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }

                    Divider().overlay(.white.opacity(0.1))

                    Text("Hier können später Lerninhalte angezeigt werden.")
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.8))
                        .lineSpacing(6)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(width: 700, height: 500)
        .padding(40)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 32)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 32)
                    .fill(LinearGradient(
                        stops: [
                            .init(color: .white.opacity(0.1), location: 0),
                            .init(color: .clear, location: 0.3)
                        ],
                        startPoint: .top, endPoint: .bottom
                    ))
                RoundedRectangle(cornerRadius: 32)
                    .stroke(LinearGradient(
                        colors: [.white.opacity(0.4), .white.opacity(0.1), .white.opacity(0.2)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ), lineWidth: 1.5)
            }
        }
        .shadow(color: .blue.opacity(0.15), radius: 30, y: 12)
        .scaleEffect(leseModusAktiv ? 1.0 : 0.5)
        .opacity(leseModusAktiv ? 1.0 : 0.0)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: leseModusAktiv)
    }
}
