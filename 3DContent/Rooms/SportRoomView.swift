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
    
    // Animation
    @State private var panelsEingeblendet = false
    
    // Gesten-State
    @State private var baumOffset: SIMD3<Float> = .zero
    @State private var dragStartOffset: SIMD3<Float> = .zero
    @State private var baumScale: Float = 1.0
    @State private var scaleStart: Float = 1.0
    
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
            
            // Zurück
            if let zurueck = attachments.entity(for: "zurueck") {
                zurueck.position = SIMD3<Float>(0, 0.6, -2.3)
                content.add(zurueck)
            }
            
        } update: { content, attachments in
            // === FOKUS-THEMA (Titel oben) ===
            if let fokus = fokusThema {
                if let titelPanel = attachments.entity(for: "fokus_\(fokus.id.uuidString)") {
                    titelPanel.position = SIMD3<Float>(0, 1.9, -2.5)
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
            
            // === SICHTBARE PANELS ===
            let positionen = berechneHalbrundPositionen(
                anzahl: sichtbareThemen.count,
                radius: 2.8,
                y: fokusThema != nil ? 1.35 : 1.5,
                winkelBereich: 1.2
            )
            
            for (index, thema) in sichtbareThemen.enumerated() {
                let attachmentID = fokusThema != nil
                    ? "child_\(thema.id.uuidString)"
                    : "thema_\(thema.id.uuidString)"
                
                if let panel = attachments.entity(for: attachmentID) {
                    if index < positionen.count {
                        panel.position = positionen[index]
                        panel.name = attachmentID
                        
                        let winkel = berechneWinkel(
                            index: index,
                            anzahl: sichtbareThemen.count,
                            winkelBereich: 1.2
                        )
                        panel.transform.rotation = simd_quatf(
                            angle: winkel,
                            axis: SIMD3<Float>(0, 1, 0)
                        )
                        
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
            rootEntity.position = baumOffset
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
            
            // Auswahl-Panels
            if fokusThema == nil {
                ForEach(aktuelleThemen) { thema in
                    Attachment(id: "thema_\(thema.id.uuidString)") {
                        glasPanel(thema: thema, istChild: false)
                    }
                }
            }
            
            // Children-Panels
            if fokusThema != nil {
                ForEach(childrenThemen) { thema in
                    Attachment(id: "child_\(thema.id.uuidString)") {
                        glasPanel(thema: thema, istChild: true)
                    }
                }
            }
        }
        .gesture(tapGesture)
        .gesture(dragGesture)
        .gesture(zoomGesture)
        .task {
            await ladeErsteEbene()
        }
    }
    
    // MARK: - Gesten
    
    private var tapGesture: some Gesture {
        SpatialTapGesture()
            .targetedToAnyEntity()
            .onEnded { value in
                let name = value.entity.name
                
                if name.hasPrefix("fokus_") {
                    Task { await zurueckEineEbene() }
                    return
                }
                
                if name.hasPrefix("thema_") {
                    let uuidString = String(name.dropFirst("thema_".count))
                    if let thema = aktuelleThemen.first(where: { $0.id.uuidString == uuidString }) {
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
    
    private var dragGesture: some Gesture {
        DragGesture()
            .targetedToAnyEntity()
            .onChanged { value in
                let translation = value.convert(value.translation3D, from: .local, to: .scene)
                baumOffset = dragStartOffset + SIMD3<Float>(
                    Float(translation.x),
                    Float(translation.y),
                    Float(translation.z)
                )
            }
            .onEnded { _ in
                dragStartOffset = baumOffset
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
    
    // MARK: - Positionen
    
    private func berechneHalbrundPositionen(anzahl: Int, radius: Float, y: Float, winkelBereich: Float) -> [SIMD3<Float>] {
        guard anzahl > 0 else { return [] }
        var positionen: [SIMD3<Float>] = []
        let maxWinkel = min(Float(anzahl - 1) * 0.3, winkelBereich)
        let startWinkel = -maxWinkel / 2.0
        
        for i in 0..<anzahl {
            let fortschritt: Float = anzahl > 1
                ? Float(i) / Float(anzahl - 1)
                : 0.5
            let winkel = startWinkel + fortschritt * maxWinkel
            let x = sin(winkel) * radius
            let z = -cos(winkel) * radius
            positionen.append(SIMD3<Float>(x, y, z))
        }
        return positionen
    }
    
    private func berechneWinkel(index: Int, anzahl: Int, winkelBereich: Float) -> Float {
        let maxWinkel = min(Float(anzahl - 1) * 0.3, winkelBereich)
        let startWinkel = -maxWinkel / 2.0
        let fortschritt: Float = anzahl > 1
            ? Float(index) / Float(anzahl - 1)
            : 0.5
        return startWinkel + fortschritt * maxWinkel
    }
    
    // MARK: - Liquid Glass Panels
    
    @ViewBuilder
    private func glasPanel(thema: Thema, istChild: Bool) -> some View {
        Text(thema.name)
            .font(istChild ? .largeTitle : .extraLargeTitle)
            .fontWeight(.medium)
            .foregroundStyle(
                LinearGradient(
                    colors: [.white, .white.opacity(0.85)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .multilineTextAlignment(.center)
            .frame(minWidth: istChild ? 160 : 200)
            .padding(istChild ? 24 : 30)
            .background {
                ZStack {
                    // Basis-Glas
                    RoundedRectangle(cornerRadius: 24)
                        .fill(.ultraThinMaterial)
                    
                    // Irisierender Schimmer oben
                    RoundedRectangle(cornerRadius: 24)
                        .fill(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.2),
                                    .blue.opacity(0.08),
                                    .purple.opacity(0.05),
                                    .clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    // Innerer Lichtstreifen (Liquid-Effekt)
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.5),
                                    .white.opacity(0.1),
                                    .blue.opacity(0.15),
                                    .white.opacity(0.3)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                }
            }
            .shadow(color: .blue.opacity(0.15), radius: 20, y: 8)
            .shadow(color: .white.opacity(0.1), radius: 5, y: -2)
            .scaleEffect(panelsEingeblendet ? 1.0 : 0.7)
            .opacity(panelsEingeblendet ? 1.0 : 0.0)
            .animation(
                .spring(response: 0.5, dampingFraction: 0.7),
                value: panelsEingeblendet
            )
    }
    
    @ViewBuilder
    private func fokusPanel(thema: Thema) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "chevron.left")
                .font(.title2)
                .foregroundColor(.white.opacity(0.7))
            
            Text(thema.name)
                .font(.extraLargeTitle)
                .fontWeight(.semibold)
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, .white.opacity(0.9)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        }
        .padding(.horizontal, 34)
        .padding(.vertical, 22)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 28)
                    .fill(.ultraThinMaterial)
                
                // Stärkerer Glas-Effekt für Fokus
                RoundedRectangle(cornerRadius: 28)
                    .fill(
                        LinearGradient(
                            colors: [
                                .blue.opacity(0.2),
                                .purple.opacity(0.1),
                                .blue.opacity(0.05),
                                .clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                // Leuchtender Rand
                RoundedRectangle(cornerRadius: 28)
                    .stroke(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.6),
                                .blue.opacity(0.3),
                                .purple.opacity(0.2),
                                .white.opacity(0.4)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
            }
        }
        .shadow(color: .blue.opacity(0.25), radius: 25, y: 8)
        .shadow(color: .purple.opacity(0.1), radius: 15, y: -3)
    }
    
    @ViewBuilder
    private func zurueckButton() -> some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.left")
                .font(.body)
            Text("Übersicht")
                .font(.title3)
        }
        .foregroundColor(.white.opacity(0.8))
        .padding(.horizontal, 22)
        .padding(.vertical, 12)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                
                RoundedRectangle(cornerRadius: 16)
                    .fill(.white.opacity(0.05))
                
                RoundedRectangle(cornerRadius: 16)
                    .stroke(.white.opacity(0.15), lineWidth: 1)
            }
        }
        .shadow(color: .black.opacity(0.2), radius: 10, y: 4)
        .onTapGesture {
            appModel.ausgewaehltesThema = nil
            openWindow(id: "main")
        }
    }
    
    // MARK: - Animation
    
    private func animierePanels() {
        panelsEingeblendet = false
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.1)) {
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
                status = "\(thema.name) – keine Unterthemen"
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
                status = "\(thema.name) – keine weiteren Unterthemen"
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
