import SwiftUI
import RealityKit
import RealityKitContent

struct SportRoomView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.openWindow) var openWindow
    
    @State private var aktuelleThemen: [Thema] = []
    @State private var fokusThema: Thema? = nil
    @State private var childrenThemen: [Thema] = []
    @State private var pfad: [Thema] = []
    @State private var status = "Lade..."
    
    // Lesemodus
    @State private var leseThema: Thema? = nil
    @State private var leseModusAktiv = false
    
    // Animation
    @State private var panelsEingeblendet = false
    
    // Gesten-State
    @State private var baumScale: Float = 1.0
    @State private var scaleStart: Float = 1.0
    
    // Hold-Geste (Long Press über DragGesture)
    @State private var dragStartZeit: Date = .distantPast
    @State private var dragGestartetAufName: String = ""
    @State private var hatSichBewegt = false
    
    // RealityKit
    @State private var rootEntity: Entity = Entity()
    
    private let themenService = ThemenService()
    
    private var sichtbareThemen: [Thema] {
        if fokusThema != nil {
            return childrenThemen
        } else {
            return aktuelleThemen
        }
    }
    
    var body: some View {
        RealityView { content, attachments in
            // Skybox
            let skybox = ModelEntity(
                mesh: .generateSphere(radius: 50),
                materials: [UnlitMaterial(color: UIColor(red: 0.05, green: 0.05, blue: 0.15, alpha: 1.0))]
            )
            skybox.scale = SIMD3<Float>(x: -1, y: 1, z: 1)
            let skyAnchor = AnchorEntity(.head)
            skyAnchor.anchoring.trackingMode = .continuous
            skyAnchor.addChild(skybox)
            content.add(skyAnchor)
            
            // Root Entity
            rootEntity.position = .zero
            content.add(rootEntity)
            
            // Debug
            if let debug = attachments.entity(for: "debug") {
                debug.position = SIMD3<Float>(0, 2.2, -2)
                content.add(debug)
            }
            
            // Zurück-Button
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
                        lesePanel.components.set(CollisionComponent(
                            shapes: [.generateBox(size: SIMD3<Float>(1.5, 1.0, 0.05))]
                        ))
                    }
                    
                    rootEntity.addChild(lesePanel)
                }
                
                rootEntity.scale = SIMD3<Float>(repeating: baumScale)
                return
            }
            
            // === FOKUS-THEMA (Titel oben) ===
            if let fokus = fokusThema {
                if let titelPanel = attachments.entity(for: "fokus_\(fokus.id.uuidString)") {
                    titelPanel.position = SIMD3<Float>(0, 1.95, -2.5)
                    titelPanel.name = "fokus_\(fokus.id.uuidString)"
                    
                    if titelPanel.components[InputTargetComponent.self] == nil {
                        titelPanel.components.set(InputTargetComponent(allowedInputTypes: .all))
                        titelPanel.components.set(CollisionComponent(
                            shapes: [.generateBox(size: SIMD3<Float>(1.2, 0.35, 0.05))]
                        ))
                    }
                    
                    rootEntity.addChild(titelPanel)
                }
            }
            
            // === SICHTBARE PANELS – UM DEN USER HERUM ===
            let positionen = berechneUmgebungsPositionen(
                anzahl: sichtbareThemen.count,
                radius: 3.0,
                y: fokusThema != nil ? 1.35 : 1.5,
                bogenGrad: 120.0
            )
            
            for (index, thema) in sichtbareThemen.enumerated() {
                let attachmentID = fokusThema != nil
                    ? "child_\(thema.id.uuidString)"
                    : "thema_\(thema.id.uuidString)"
                
                if let panel = attachments.entity(for: attachmentID) {
                    if index < positionen.count {
                        panel.position = positionen[index]
                        panel.name = attachmentID
                        
                        if panel.components[InputTargetComponent.self] == nil {
                            panel.components.set(InputTargetComponent(allowedInputTypes: .all))
                            panel.components.set(CollisionComponent(
                                shapes: [.generateBox(size: SIMD3<Float>(0.8, 0.3, 0.05))]
                            ))
                        }
                        
                        rootEntity.addChild(panel)
                    }
                }
            }
            
            // Baum-Transform
            rootEntity.scale = SIMD3<Float>(repeating: baumScale)
        } attachments: {
            // Debug
            Attachment(id: "debug") {
                Text(status)
                    .font(.caption)
                    .foregroundColor(.yellow)
                    .padding(8)
                    .background(.black.opacity(0.5))
                    .cornerRadius(8)
            }
            
            // Zurück
            Attachment(id: "zurueck") {
                zurueckButton()
            }
            
            // Fokus-Thema
            if let fokus = fokusThema {
                Attachment(id: "fokus_\(fokus.id.uuidString)") {
                    fokusPanel(thema: fokus)
                }
            }
            
            // Lese-Panel
            if leseModusAktiv, let lese = leseThema {
                Attachment(id: "lese_\(lese.id.uuidString)") {
                    lesePanel(thema: lese)
                }
            }
            
            // Auswahl-Panels
            if fokusThema == nil && !leseModusAktiv {
                ForEach(aktuelleThemen) { thema in
                    Attachment(id: "thema_\(thema.id.uuidString)") {
                        themaPanel(thema: thema)
                    }
                }
            }
            
            // Children-Panels
            if fokusThema != nil && !leseModusAktiv {
                ForEach(childrenThemen) { thema in
                    Attachment(id: "child_\(thema.id.uuidString)") {
                        themaPanel(thema: thema)
                    }
                }
            }
        }
        .gesture(tapGesture)
        .gesture(holdGesture)
        .gesture(zoomGesture)
        .task {
            await ladeErsteEbene()
        }
    }
    
    // MARK: - Positionen um den User herum
    
    private func berechneUmgebungsPositionen(
        anzahl: Int,
        radius: Float,
        y: Float,
        bogenGrad: Float
    ) -> [SIMD3<Float>] {
        guard anzahl > 0 else { return [] }
        var positionen: [SIMD3<Float>] = []
        
        let bogenRad = bogenGrad * .pi / 180.0
        let startWinkel = -bogenRad / 2.0
        
        for i in 0..<anzahl {
            let fortschritt: Float = anzahl > 1
                ? Float(i) / Float(anzahl - 1)
                : 0.5
            let winkel = startWinkel + fortschritt * bogenRad
            
            let x = sin(winkel) * radius
            let z = -cos(winkel) * radius
            
            positionen.append(SIMD3<Float>(x, y, z))
        }
        
        return positionen
    }
    
    // MARK: - Gesten
    
    private var tapGesture: some Gesture {
        SpatialTapGesture()
            .targetedToAnyEntity()
            .onEnded { value in
                let name = value.entity.name
                
                // Lese-Panel schließen
                if name.hasPrefix("lese_") {
                    leseModusAktiv = false
                    leseThema = nil
                    animierePanels()
                    return
                }
                
                // Fokus-Titel: zurück
                if name.hasPrefix("fokus_") {
                    Task { await zurueckEineEbene() }
                    return
                }
                
                // Thema-Panel: navigieren
                if name.hasPrefix("thema_") {
                    let uuidString = String(name.dropFirst("thema_".count))
                    if let thema = aktuelleThemen.first(where: { $0.id.uuidString == uuidString }) {
                        Task { await themaAusgewaehlt(thema: thema) }
                    }
                    return
                }
                
                // Child-Panel: navigieren
                if name.hasPrefix("child_") {
                    let uuidString = String(name.dropFirst("child_".count))
                    if let thema = childrenThemen.first(where: { $0.id.uuidString == uuidString }) {
                        Task { await childAusgewaehlt(thema: thema) }
                    }
                    return
                }
            }
    }
    
    private var holdGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .targetedToAnyEntity()
            .onChanged { value in
                let name = value.entity.name
                
                // Neuer Drag gestartet
                if dragGestartetAufName != name {
                    dragGestartetAufName = name
                    dragStartZeit = Date()
                    hatSichBewegt = false
                }
                
                // Prüfen ob sich der Finger bewegt hat
                let translation = value.translation3D
                let bewegung = sqrt(
                    Float(translation.x * translation.x) +
                    Float(translation.y * translation.y) +
                    Float(translation.z * translation.z)
                )
                if bewegung > 0.01 {
                    hatSichBewegt = true
                }
            }
            .onEnded { value in
                let name = value.entity.name
                let halteDauer = Date().timeIntervalSince(dragStartZeit)
                
                // Nur als Long Press werten wenn:
                // - Mindestens 0.5 Sekunden gehalten
                // - Finger hat sich nicht bewegt
                guard halteDauer >= 0.5 && !hatSichBewegt else {
                    dragGestartetAufName = ""
                    return
                }
                
                // Thema-Panel: Lesemodus
                if name.hasPrefix("thema_") {
                    let uuidString = String(name.dropFirst("thema_".count))
                    if let thema = aktuelleThemen.first(where: { $0.id.uuidString == uuidString }) {
                        leseThema = thema
                        leseModusAktiv = true
                    }
                }
                
                // Child-Panel: Lesemodus
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
            .onEnded { _ in
                scaleStart = baumScale
            }
    }
    
    // MARK: - Panel Views
    
    @ViewBuilder
    private func themaPanel(thema: Thema) -> some View {
        Text(thema.name)
            .font(.extraLargeTitle)
            .fontWeight(.semibold)
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .frame(minWidth: 220)
            .padding(.horizontal, 40)
            .padding(.vertical, 28)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: 28)
                        .fill(.ultraThinMaterial)
                    
                    RoundedRectangle(cornerRadius: 28)
                        .fill(
                            LinearGradient(
                                stops: [
                                    .init(color: .white.opacity(0.15), location: 0),
                                    .init(color: .clear, location: 0.4)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.4),
                                    .white.opacity(0.1),
                                    .white.opacity(0.2)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                }
            }
            .shadow(color: .blue.opacity(0.15), radius: 20, y: 10)
            .hoverEffect(.highlight)
            .scaleEffect(panelsEingeblendet ? 1.0 : 0.7)
            .opacity(panelsEingeblendet ? 1.0 : 0.0)
            .animation(
                .spring(response: 0.5, dampingFraction: 0.75),
                value: panelsEingeblendet
            )
    }
    
    @ViewBuilder
    private func fokusPanel(thema: Thema) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "chevron.left")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(.white.opacity(0.6))
            
            Text(thema.name)
                .font(.extraLargeTitle)
                .fontWeight(.bold)
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 24)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 32)
                    .fill(.ultraThinMaterial)
                
                RoundedRectangle(cornerRadius: 32)
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: .blue.opacity(0.15), location: 0),
                                .init(color: .purple.opacity(0.05), location: 0.5),
                                .init(color: .clear, location: 1.0)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                RoundedRectangle(cornerRadius: 32)
                    .stroke(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.5),
                                .blue.opacity(0.2),
                                .white.opacity(0.3)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            }
        }
        .shadow(color: .blue.opacity(0.2), radius: 25, y: 10)
        .hoverEffect(.highlight)
    }
    
    @ViewBuilder
    private func lesePanel(thema: Thema) -> some View {
        VStack(spacing: 20) {
            // Header
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
            
            Divider()
                .overlay(.white.opacity(0.2))
            
            // Inhalt
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
                    
                    Divider()
                        .overlay(.white.opacity(0.1))
                    
                    Text("Hier können später Lerninhalte, Texte, Bilder oder interaktive Elemente für \"\(thema.name)\" angezeigt werden.")
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.8))
                        .lineSpacing(6)
                    
                    Text("Halte ein Thema gedrückt um den Lesemodus zu öffnen. Tippe auf X um zu schließen.")
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .padding(.top, 10)
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
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: .white.opacity(0.1), location: 0),
                                .init(color: .clear, location: 0.3)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                
                RoundedRectangle(cornerRadius: 32)
                    .stroke(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.4),
                                .white.opacity(0.1),
                                .white.opacity(0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            }
        }
        .shadow(color: .blue.opacity(0.15), radius: 30, y: 12)
        .scaleEffect(leseModusAktiv ? 1.0 : 0.5)
        .opacity(leseModusAktiv ? 1.0 : 0.0)
        .animation(
            .spring(response: 0.4, dampingFraction: 0.8),
            value: leseModusAktiv
        )
    }
    
    @ViewBuilder
    private func zurueckButton() -> some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.left")
                .font(.title3)
                .fontWeight(.medium)
            Text("Übersicht")
                .font(.title3)
                .fontWeight(.medium)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 26)
        .padding(.vertical, 14)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: .white.opacity(0.1), location: 0),
                                .init(color: .clear, location: 0.5)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                
                RoundedRectangle(cornerRadius: 20)
                    .stroke(.white.opacity(0.2), lineWidth: 1)
            }
        }
        .shadow(color: .blue.opacity(0.1), radius: 15, y: 5)
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
        guard let sportThema = appModel.ausgewaehltesThema else {
            status = "Kein Thema ausgewählt"
            return
        }
        pfad = []
        fokusThema = nil
        childrenThemen = []
        leseModusAktiv = false
        leseThema = nil
        await ladeChildren(vonThemaId: sportThema.id)
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
            if let fokus = fokusThema {
                pfad.append(fokus)
            }
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
            status = "\(aktuelleThemen.count) Themen"
        }
        animierePanels()
    }
}
