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
    
    @State private var dragStartZeit: Date = .distantPast
    @State private var dragGestartetAufName: String = ""
    @State private var hatSichBewegt = false
    
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
                zurueck.position = SIMD3<Float>(0, 0.6, -2.3)
                content.add(zurueck)
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
            
            // === FOKUS-THEMA (Breadcrumb UNTEN) ===
            if let fokus = fokusThema {
                if let titelPanel = attachments.entity(for: "fokus_\(fokus.id.uuidString)") {
                    titelPanel.position = SIMD3<Float>(0, 0.8, -2.0)  // Unten
                    titelPanel.name = "fokus_\(fokus.id.uuidString)"
                    
                    if titelPanel.components[InputTargetComponent.self] == nil {
                        titelPanel.components.set(InputTargetComponent(allowedInputTypes: .all))
                        titelPanel.components.set(CollisionComponent(shapes: [.generateBox(size: SIMD3<Float>(1.2, 0.35, 0.05))]))
                    }
                    rootEntity.addChild(titelPanel)
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
                        panel.components.set(CollisionComponent(shapes: [.generateBox(size: SIMD3<Float>(0.8, 0.3, 0.05))]))
                    }
                    if panel.parent == nil { rootEntity.addChild(panel) }
                    
                    var zielPosition: SIMD3<Float>
                    var zielScale: Float
                    
                    if isRootLevel {
                        // --- GALERIE: Flache Reihe mit Swipe ---
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
                        // --- FOKUS: Children flach aufgereiht ---
                        let gesamtBreite = Float(sichtbareThemen.count - 1) * 1.1
                        let startX = -gesamtBreite / 2.0
                        let xPos = startX + Float(index) * 1.1
                        
                        zielPosition = SIMD3<Float>(xPos, 1.5, -2.5)
                        zielScale = 1.0
                    }
                    
                    let transform = Transform(
                        scale: SIMD3<Float>(repeating: zielScale),
                        rotation: simd_quatf(angle: 0, axis: [0, 1, 0]),
                        translation: zielPosition
                    )
                    panel.move(to: transform, relativeTo: nil, duration: 0.5, timingFunction: .easeInOut)
                }
            }
            
            rootEntity.scale = SIMD3<Float>(repeating: baumScale)
            
        } attachments: {
            Attachment(id: "debug") {
                Text(status).font(.caption).foregroundColor(.yellow).padding(8).background(.black.opacity(0.5)).cornerRadius(8)
            }
            
            Attachment(id: "zurueck") { zurueckButton() }
            
            if let fokus = fokusThema {
                Attachment(id: "fokus_\(fokus.id.uuidString)") {
                    fokusPanel(thema: fokus)
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
                ForEach(childrenThemen) { thema in
                    Attachment(id: "child_\(thema.id.uuidString)") {
                        themaPanel(thema: thema, isFront: false)
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
                
                if name.hasPrefix("lese_") {
                    leseModusAktiv = false
                    leseThema = nil
                    animierePanels()
                    return
                }
                
                if name.hasPrefix("fokus_") {
                    Task { await zurueckEineEbene() }
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
    
    // Swipe nur in der Galerie (Root)
    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .targetedToAnyEntity()
            .onEnded { value in
                guard isRootLevel else { return }
                let translation = value.translation3D
                if abs(translation.x) > 0.02 {
                    if translation.x < 0 {
                        withAnimation { aktuellerIndex = min(aktuelleThemen.count - 1, aktuellerIndex + 1) }
                    } else {
                        withAnimation { aktuellerIndex = max(0, aktuellerIndex - 1) }
                    }
                }
            }
    }
    
    private var holdGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .targetedToAnyEntity()
            .onChanged { value in
                let name = value.entity.name
                
                if dragGestartetAufName != name {
                    dragGestartetAufName = name
                    dragStartZeit = Date()
                    hatSichBewegt = false
                }
                
                let translation = value.translation3D
                let bewegung = sqrt(
                    Float(translation.x * translation.x) +
                    Float(translation.y * translation.y) +
                    Float(translation.z * translation.z)
                )
                if bewegung > 0.01 { hatSichBewegt = true }
            }
            .onEnded { value in
                let name = value.entity.name
                let halteDauer = Date().timeIntervalSince(dragStartZeit)
                
                guard halteDauer >= 0.5 && !hatSichBewegt else {
                    dragGestartetAufName = ""
                    return
                }
                
                if name.hasPrefix("thema_") {
                    let uuidString = String(name.dropFirst("thema_".count))
                    if let thema = aktuelleThemen.first(where: { $0.id.uuidString == uuidString }) {
                        leseThema = thema
                        leseModusAktiv = true
                    }
                }
                
                if name.hasPrefix("child_") {
                    let uuidString = String(name.dropFirst("child_".count))
                    if let thema = childrenThemen.first(where: { $0.id.uuidString == uuidString }) {
                        leseThema = thema
                        leseModusAktiv = true
                    }
                }
                
                dragGestartetAufName = ""
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
    private func themaPanel(thema: Thema, isFront: Bool) -> some View {
        Text(thema.name)
            .font(.extraLargeTitle)
            .fontWeight(isFront ? .bold : .semibold)
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .frame(minWidth: 220)
            .padding(.horizontal, 40)
            .padding(.vertical, 28)
            .background {
                ZStack {
                    // Dunklere Basis für Kontrast auf hellem Hintergrund
                    RoundedRectangle(cornerRadius: 28)
                        .fill(.black.opacity(0.35))
                    
                    RoundedRectangle(cornerRadius: 28)
                        .fill(.ultraThinMaterial)
                    
                    if isFront {
                        RoundedRectangle(cornerRadius: 28)
                            .fill(LinearGradient(
                                colors: [.white.opacity(0.2), .blue.opacity(0.05), .clear],
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
                                stops: [.init(color: .white.opacity(0.1), location: 0), .init(color: .clear, location: 0.4)],
                                startPoint: .top, endPoint: .bottom
                            ))
                        RoundedRectangle(cornerRadius: 28)
                            .stroke(.white.opacity(0.35), lineWidth: 1.5)
                    }
                }
            }
            .shadow(color: isFront ? .blue.opacity(0.4) : .black.opacity(0.4), radius: isFront ? 30 : 15, y: isFront ? 12 : 6)
            .hoverEffect(.highlight)
            .scaleEffect(panelsEingeblendet ? 1.0 : 0.7)
            .opacity(panelsEingeblendet ? 1.0 : 0.0)
            .animation(.spring(response: 0.5, dampingFraction: 0.75), value: panelsEingeblendet)
    }

    @ViewBuilder
    private func fokusPanel(thema: Thema) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "chevron.left").font(.title2).fontWeight(.medium).foregroundColor(.white.opacity(0.7))
            Text(thema.name).font(.extraLargeTitle).fontWeight(.bold).foregroundStyle(.white)
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 24)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 32)
                    .fill(.black.opacity(0.3))
                
                RoundedRectangle(cornerRadius: 32)
                    .fill(.ultraThinMaterial)
                
                RoundedRectangle(cornerRadius: 32)
                    .fill(LinearGradient(
                        stops: [
                            .init(color: .blue.opacity(0.2), location: 0),
                            .init(color: .purple.opacity(0.08), location: 0.5),
                            .init(color: .clear, location: 1.0)
                        ],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                
                RoundedRectangle(cornerRadius: 32)
                    .stroke(LinearGradient(
                        colors: [.white.opacity(0.6), .blue.opacity(0.3), .white.opacity(0.4)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ), lineWidth: 1.5)
            }
        }
        .shadow(color: .blue.opacity(0.3), radius: 25, y: 10)
        .hoverEffect(.highlight)
    }

    @ViewBuilder
    private func lesePanel(thema: Thema) -> some View {
        VStack(spacing: 20) {
            HStack {
                Text(thema.name).font(.extraLargeTitle).fontWeight(.bold).foregroundColor(.white)
                Spacer()
                Image(systemName: "xmark.circle.fill").font(.title).foregroundColor(.white.opacity(0.5))
            }
            Divider().overlay(.white.opacity(0.3))
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Thema: \(thema.name)").font(.title).foregroundColor(.white)
                    Text("Ebene: \(thema.level)").font(.title2).foregroundColor(.white.opacity(0.6))
                    if let parentId = thema.parentId {
                        Text("Parent: \(parentId.uuidString.prefix(8))...").font(.title3).foregroundColor(.white.opacity(0.6))
                    }
                    Divider().overlay(.white.opacity(0.15))
                    Text("Hier können später Lerninhalte angezeigt werden.").font(.title2).foregroundColor(.white.opacity(0.85)).lineSpacing(6)
                    Text("Halte ein Thema gedrückt um den Lesemodus zu öffnen.").font(.title3).foregroundColor(.white.opacity(0.5)).padding(.top, 10)
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
        HStack(spacing: 10) {
            Image(systemName: "arrow.left").font(.title3).fontWeight(.medium)
            Text("Übersicht").font(.title3).fontWeight(.medium)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 26)
        .padding(.vertical, 14)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(.black.opacity(0.3))
                
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                
                RoundedRectangle(cornerRadius: 20)
                    .fill(LinearGradient(
                        stops: [.init(color: .white.opacity(0.12), location: 0), .init(color: .clear, location: 0.5)],
                        startPoint: .top, endPoint: .bottom
                    ))
                
                RoundedRectangle(cornerRadius: 20)
                    .stroke(.white.opacity(0.35), lineWidth: 1)
            }
        }
        .shadow(color: .black.opacity(0.3), radius: 15, y: 5)
        .hoverEffect(.highlight)
        .onTapGesture {
            appModel.ausgewaehltesThema = nil
            openWindow(id: "main")
        }
    }
    
    // MARK: - Animation
    
    private func animierePanels() {
        panelsEingeblendet = false
        withAnimation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.1)) {
            panelsEingeblendet = true
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
            fokusThema = thema
            childrenThemen = children
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
            fokusThema = thema
            childrenThemen = children
            status = "\(children.count) Unterthemen"
            animierePanels()
        } catch {
            status = "Fehler: \(error.localizedDescription)"
        }
    }
    
    private func zurueckEineEbene() async {
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
        animierePanels()
    }
}
