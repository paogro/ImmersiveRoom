import SwiftUI
import RealityKit
import RealityKitContent

struct GenericRoomView: View {
    let skyboxTextureName: String

    @Environment(AppModel.self) var appModel
    @Environment(\.openWindow) var openWindow 

    // @State properties must live in the struct declaration — Swift extensions
    // in other files cannot access `private` stored properties, so all @State
    // is declared internal (no modifier) here so RoomGestures.swift and
    // RoomViewModel.swift extensions can read and mutate them.
    @State var aktuelleThemen: [Thema] = []
    @State var fokusThema: Thema? = nil
    @State var childrenThemen: [Thema] = []
    @State var pfad: [Thema] = []
    @State var status = "Lade..."

    @State var leseThema: Thema? = nil
    @State var leseModusAktiv = false

    @State var panelsEingeblendet = false
    @State var aktuellerIndex: Int = 0

    @State var baumScale: Float = 1.0
    @State var scaleStart: Float = 1.0

    @State var aktivGehaltenesPanel: String? = nil
    @State var holdTask: Task<Void, Never>? = nil
    @State var holdTriggered = false
    @State var breadcrumbExpanded: Bool = false
    @State var navigiertTiefer: Bool = true

    @State var rootEntity: Entity = Entity()
    @State var ringEntity: Entity = Entity()        // holds the topic-card ring; rotating it spins the whole ring

    @State var ringAngle: Float = 0                 // current rotation of the ring (radians)
    @State var ringDragActive: Bool = false
    @State var ringDragStartAngle: Float = 0
    @State var ringDragLastX: Float = 0             // last sampled horizontal drag offset (m), for velocity
    @State var ringDragLastTime: Date = Date()
    @State var ringVelocity: Float = 0             // smoothed angular velocity at release (rad/s)
    @State var ringInteracting: Bool = false        // suppresses update-closure rotation while drag/momentum drives ringEntity directly
    @State var momentumTask: Task<Void, Never>? = nil

    let themenService = ThemenService()
    let ringDragSensitivity: Float = 0.25          // radians of ring rotation per metre of horizontal drag (tunable)
    let ringMomentumDamping: Float = 0.5           // velocity multiplier per ~16ms tick during glide
    let ringMomentumMinSpeed: Float = 3.5          // rad/s below which momentum gives up and snaps

    var isRootLevel: Bool {
        fokusThema == nil
    }

    var sichtbareThemen: [Thema] {
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

            ringEntity.name = "ring"
            ringEntity.transform.rotation = simd_quatf(angle: ringAngle, axis: [0, 1, 0])
            rootEntity.addChild(ringEntity)

            RingPanelMarker.registerComponent()

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
            // Karten sitzen statisch auf einem Kreis im LOKALEN Raum von ringEntity.
            // Drehen wir ringEntity um Y, rotieren alle Karten als geschlossener Ring mit —
            // wie ein Zahnrad. Frontposition in der Welt ist die Karte, deren lokaler Winkel
            // gerade ringAngle entspricht; ihr Index wird in aktuellerIndex gehalten.
            let nCardsLayout = max(sichtbareThemen.count, 1)
            let angleStepLayout: Float = 2 * Float.pi / Float(nCardsLayout)
            let radiusLayout: Float = 2.5
            let cardYLayout: Float = 1.5

            for (index, thema) in sichtbareThemen.enumerated() {
                let attachmentID = fokusThema != nil
                    ? "child_\(thema.id.uuidString)"
                    : "thema_\(thema.id.uuidString)"

                if let panel = attachments.entity(for: attachmentID) {
                    panel.name = attachmentID

                    if panel.components[InputTargetComponent.self] == nil {
                        panel.components.set(InputTargetComponent(allowedInputTypes: .all))
                        panel.components.set(CollisionComponent(shapes: [.generateBox(size: SIMD3<Float>(0.95, 0.35, 0.05))]))
                        // Required for the SwiftUI .hoverEffect inside the attachment to receive
                        // gaze state — without it, topic cards in the room get no hover feedback.
                        panel.components.set(HoverEffectComponent())
                    }

                    let theta = Float(index) * angleStepLayout
                    let zielPosition = SIMD3<Float>(radiusLayout * sin(theta), cardYLayout, -radiusLayout * cos(theta))
                    let zielRotation = simd_quatf(angle: -theta, axis: [0, 1, 0])
                    // Im Root-Carousel bekommt KEINE Karte mehr eine positionsabhängige
                    // Hervorhebung — der Blick (Gaze-Hover) bestimmt allein, welche Karte
                    // aufleuchtet. Children behalten ihr eigenes Styling.
                    let isFront = false
                    let zielScale: Float = 1.0

                    let prevMarker = panel.components[RingPanelMarker.self]
                    let zielTransform = Transform(
                        scale: SIMD3<Float>(repeating: zielScale),
                        rotation: zielRotation,
                        translation: zielPosition
                    )

                    if panel.parent == nil {
                        // Fly-in: focus levels drop in vertically; root cards just pop via the
                        // SwiftUI panelsEingeblendet scale spring.
                        if !isRootLevel {
                            let yOffset: Float = navigiertTiefer ? 1.5 : -1.5
                            panel.transform = Transform(
                                scale: SIMD3<Float>(repeating: zielScale),
                                rotation: zielRotation,
                                translation: SIMD3<Float>(zielPosition.x, zielPosition.y + yOffset, zielPosition.z)
                            )
                        } else {
                            panel.transform = zielTransform
                        }
                        ringEntity.addChild(panel)
                        let dur: Double = isRootLevel ? 0.5 : 0.55
                        panel.move(to: zielTransform, relativeTo: ringEntity, duration: dur, timingFunction: .easeOut)
                        panel.components.set(RingPanelMarker(isFront: isFront))
                    } else if prevMarker?.isFront != isFront {
                        // Only the front-highlight scale changed — animate just that.
                        panel.move(to: zielTransform, relativeTo: ringEntity, duration: 0.25, timingFunction: .easeOut)
                        panel.components.set(RingPanelMarker(isFront: isFront))
                    }
                }
            }

            // Ring rotation is driven imperatively during drag/momentum (see swipeGesture /
            // momentum task); the update closure only mirrors the settled ringAngle when no
            // interaction is in flight so unrelated state changes don't snap the ring back.
            if !ringInteracting {
                ringEntity.transform.rotation = simd_quatf(angle: ringAngle, axis: [0, 1, 0])
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

            Attachment(id: "zurueck") {
                ZurueckButtonView(panelsEingeblendet: panelsEingeblendet)
            }

            if let fokus = fokusThema {
                let breadcrumbPfad: [Thema] = (pfad + [fokus]).reversed()
                ForEach(breadcrumbPfad) { thema in
                    Attachment(id: "crumb_\(thema.id.uuidString)") {
                        CrumbPanelView(
                            thema: thema,
                            isFront: thema.id == fokus.id,
                            breadcrumbExpanded: breadcrumbExpanded,
                            panelsEingeblendet: panelsEingeblendet
                        )
                    }
                }
            }

            if leseModusAktiv, let lese = leseThema {
                Attachment(id: "lese_\(lese.id.uuidString)") {
                    LesePanelView(thema: lese, leseModusAktiv: leseModusAktiv)
                }
            }

            if fokusThema == nil && !leseModusAktiv {
                ForEach(aktuelleThemen) { thema in
                    Attachment(id: "thema_\(thema.id.uuidString)") {
                        // Root-Karten haben keine positionsabhängige Hervorhebung mehr —
                        // der Gaze-Hover (.roundedGazeHover unten) übernimmt das Highlight.
                        themaPanel(thema: thema, isFront: false)
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

    // MARK: - Panel View Factory

    @ViewBuilder
    private func themaPanel(thema: Thema, isFront: Bool, isActiveChild: Bool = false, animationDelay: Double = 0, hideWhenExpanded: Bool = false) -> some View {
        let isGehalten = aktivGehaltenesPanel == "thema_\(thema.id.uuidString)"
                      || aktivGehaltenesPanel == "child_\(thema.id.uuidString)"
        let childHidden = hideWhenExpanded && breadcrumbExpanded

        ThemaPanelView(
            thema: thema,
            isFront: isFront,
            isActiveChild: isActiveChild,
            isGehalten: isGehalten,
            childHidden: childHidden,
            panelsEingeblendet: panelsEingeblendet,
            animationDelay: animationDelay
        )
    }
}
