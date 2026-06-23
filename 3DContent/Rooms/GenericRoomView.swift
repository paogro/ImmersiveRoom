import SwiftUI
import RealityKit
import RealityKitContent
import ARKit

struct GenericRoomView: View {
    let skyboxTextureName: String
    var ambientSoundName: String? = nil   // optionaler Raum-Loop (Bundle-Resource ohne Endung), nil = stumm
    var skyboxDrehungGrad: Float = 0      // Y-Drehung der Skybox in Grad: legt fest, welcher Bildausschnitt beim Start vorne liegt

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
    @State var leseArtikel: NewsArtikel? = nil   // geladener News-Artikel zum aktuellen Lese-Thema
    @State var leseLaedt: Bool = false           // true während der Artikel aus der DB geladen wird

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

    @State var audioController: AudioPlaybackController? = nil   // laufender Raum-Loop, zum Stoppen beim Verlassen
    @State var audioEntity = Entity()                            // stabile Audio-Entity; Loop wird per starteRaumSound darauf gespielt
    @State var sfxEntity = Entity()                              // eigene Entity für kurze UI-Klicks (stört den Loop nicht)
    @State var clickKarten: AudioFileResource? = nil             // Karten-Navigation (rein/eintauchen) → RPG-Sound
    @State var clickBreadcrumb: AudioFileResource? = nil          // Breadcrumb & Home → Bleep-Bloop-Sound

    // Kopf-/Geräte-Tracking (ARKit) — liefert Kopfausrichtung und -position, um die UI
    // bei jedem Neu-Laden zur Blickrichtung auszurichten und ihr beim Gehen zu folgen.
    @State var arkitSession = ARKitSession()
    @State var worldTracking = WorldTrackingProvider()
    @State var skyboxEntity = ModelEntity()   // Skybox-Kugel; folgt der Position, damit man nie an den Rand kommt
    @State var sceneUpdateSub: EventSubscription? = nil   // Pro-Frame-Abo (Render-Loop) fürs Positions-Following

    let followDeadzone: Float = 0.4   // bis hierhin (m) bleibt die UI stehen, bevor sie nachzieht
    let followRate: Float = 6.0       // Glättungsrate des Nachziehens (höher = schneller), frame-zeit-basiert

    // Navigations-Verlauf: pro Ring (Schlüssel = parent-Topic-ID) die zuletzt vorne
    // stehende Karte. Wird bei Vor-/Zurück-/Sprung-Navigation und beim Blättern
    // gepflegt und beim Betreten eines Rings zum Zentrieren genutzt. Reiner
    // Session-State → bei Raum-/App-Neustart leer (ladeErsteEbene räumt auf).
    @State var besuchtePosition: [UUID: UUID] = [:]

    let themenService = ThemenService()
    let ringMaxStep: Float = 0.6                   // max. Winkelabstand pro Karte (rad ~34°). Wenige Karten → Frontal-Fächer statt Vollkreis.
    let ringDragSensitivity: Float = 2.5           // radians of ring rotation per metre of horizontal hand drag (scene space)
    let ringMomentumDamping: Float = 0.5           // velocity multiplier per ~16ms tick during glide
    let ringMomentumMinSpeed: Float = 2.5          // rad/s below which momentum gives up and snaps

    var isRootLevel: Bool {
        fokusThema == nil
    }

    // Parent-Topic des aktuell sichtbaren Rings: im Fokus-Modus das fokussierte
    // Thema, im Wurzel-Karussell die gewählte Hauptkategorie.
    var aktuellerRingParentId: UUID? {
        fokusThema?.id ?? appModel.ausgewaehltesThema?.id
    }

    var sichtbareThemen: [Thema] {
        if fokusThema != nil {
            return childrenThemen
        } else {
            return aktuelleThemen
        }
    }

    // Winkelabstand pro Karte: voller Kreis durch Anzahl, aber gedeckelt auf ringMaxStep.
    // Dadurch fächern wenige Karten frontal vor dem Nutzer auf, statt sich um ihn zu legen.
    // Alle Ring-Funktionen (Layout, Front-Index, Snap, Zentrieren) nutzen diesen Wert.
    var ringWinkelSchritt: Float {
        min(2 * .pi / Float(max(sichtbareThemen.count, 1)), ringMaxStep)
    }

    var body: some View {
        RealityView { content, attachments in
            // --- Skybox ---
            var skyboxMaterial = UnlitMaterial()
            if let texture = try? await TextureResource(named: skyboxTextureName) {
                skyboxMaterial.color = .init(texture: .init(texture))
            }
            // skyboxEntity ist eine @State-ModelEntity → stabile Referenz, damit der
            // Follow-Loop sie später auf die Nutzerposition ziehen kann.
            skyboxEntity.model = ModelComponent(mesh: .generateSphere(radius: 50), materials: [skyboxMaterial])
            skyboxEntity.scale = SIMD3<Float>(x: -1, y: 1, z: 1)
            // Skybox um Y drehen, damit beim Start ein bestimmter Bildausschnitt vorne liegt.
            skyboxEntity.orientation = simd_quatf(angle: skyboxDrehungGrad * .pi / 180, axis: [0, 1, 0])
            content.add(skyboxEntity)

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
                // Entity-Tap + weißer Gaze-Spotlight (wie die Karten, aber weiß).
                zurueck.components.set(InputTargetComponent(allowedInputTypes: .all))
                zurueck.components.set(CollisionComponent(shapes: [.generateBox(size: SIMD3<Float>(0.6, 0.34, 0.05))]))
                zurueck.components.set(HoverEffectComponent(.spotlight(.init(color: .systemBlue, strength: 20.0))))
                rootEntity.addChild(zurueck)
            }

            // --- Raum-Atmosphäre ---
            // Audio-Entity (stabile @State-Referenz) in die Szene hängen.
            // ChannelAudioComponent = NICHT spatialisiert → der Loop klingt überall
            // gleich, egal wohin man sich dreht (raumfüllende Atmo statt Punktquelle).
            // Start/Stop laufen über .task (starteRaumSound) und .onDisappear, damit
            // der Loop nach z. B. einem geöffneten Fenster automatisch wieder anläuft.
            audioEntity.components.set(ChannelAudioComponent())
            rootEntity.addChild(audioEntity)

            // Eigene Entity für kurze UI-Klicks (nicht-spatialisiert), getrennt vom Loop.
            sfxEntity.components.set(ChannelAudioComponent())
            rootEntity.addChild(sfxEntity)

            // Positions-Following im RENDER-LOOP (jeden Frame, synchron zur Bildrate) statt
            // über einen separaten Timer → glatt, kein Ruckeln. Liefert auch die echte
            // Frame-Zeit (deltaTime) für framerate-unabhängiges Glätten.
            sceneUpdateSub = content.subscribe(to: SceneEvents.Update.self) { event in
                folgeNutzerposition(deltaTime: event.deltaTime)
            }

        } update: { content, attachments in

            // === LESE-PANEL ===
            if leseModusAktiv, let lese = leseThema {
                if let lesePanel = attachments.entity(for: "lese_\(lese.id.uuidString)") {
                    lesePanel.position = SIMD3<Float>(0, 1.5, -1.8)
                    lesePanel.name = "lese_\(lese.id.uuidString)"
                    // Bewusst KEIN InputTargetComponent/CollisionComponent: sonst würde die
                    // szenenweite SpatialTapGesture (tapGesture) das ganze Panel abfangen und
                    // die SwiftUI-Buttons (Schließen, "Mehr Infos") bekämen ihren Tap nie.
                    // Schließen und Link laufen jetzt rein über SwiftUI im LesePanelView.
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
                let expandedSpacing: Float = 0.22   // enger gepackt (vorher 0.30)
                let expandedScale: Float = 1.2       // aufgeklappte Pillen etwas größer (vorher 1.0)
                let expandedCenterY: Float = 1.40
                let expandedZ: Float = -1.55
                let nExpandedTotal = breadcrumbPfad.count + 2 // + Basis-Raum + Home-Button am Boden
                let expandedTopY = expandedCenterY + Float(nExpandedTotal - 1) * expandedSpacing / 2.0

                for (idx, thema) in breadcrumbPfad.enumerated() {
                    let attachmentID = "crumb_\(thema.id.uuidString)"

                    if let panel = attachments.entity(for: attachmentID) {
                        panel.name = attachmentID

                        if panel.components[InputTargetComponent.self] == nil {
                            panel.components.set(InputTargetComponent(allowedInputTypes: .all))
                            panel.components.set(CollisionComponent(shapes: [.generateBox(size: SIMD3<Float>(1.1, 0.32, 0.05))]))
                            panel.components.set(HoverEffectComponent(.spotlight(.init(color: .systemBlue, strength: 20.0))))
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

                        // Eingeklappt: sauberer Größenverlauf nach Tiefe (vorne am größten,
                        // jede dahinter etwas kleiner) — unabhängig von der Kartenbreite.
                        let collapsedScale = max(0.78, 1.0 - Float(idx) * 0.08)
                        let crumbTransform = Transform(
                            scale: SIMD3<Float>(repeating: breadcrumbExpanded ? expandedScale : collapsedScale),
                            rotation: simd_quatf(angle: 0, axis: [0, 1, 0]),
                            translation: SIMD3<Float>(0, targetY, targetZ)
                        )
                        panel.move(to: crumbTransform, relativeTo: rootEntity, duration: 0.4, timingFunction: .easeInOut)
                    }
                }

                // === BASIS-RAUM-EINTRAG ===
                // Sitzt nur im aufgeklappten Zustand zwischen der ältesten Vorfahren-Karte
                // und dem Home-Button. Springt zurück ins Start-Karussell (fokusThema == nil).
                // Im eingeklappten Zustand off-screen geparkt (wie der Home-Button).
                if let basis = attachments.entity(for: "basis_crumb") {
                    basis.name = "basis_crumb"

                    if basis.components[InputTargetComponent.self] == nil {
                        basis.components.set(InputTargetComponent(allowedInputTypes: .all))
                        basis.components.set(CollisionComponent(shapes: [.generateBox(size: SIMD3<Float>(1.1, 0.32, 0.05))]))
                        basis.components.set(HoverEffectComponent(.spotlight(.init(color: .systemBlue, strength: 20.0))))
                    }

                    let basisY: Float = breadcrumbExpanded
                        ? expandedTopY - Float(breadcrumbPfad.count) * expandedSpacing
                        : -10
                    let basisZ: Float = breadcrumbExpanded ? expandedZ : -2

                    if basis.parent == nil {
                        basis.position = SIMD3<Float>(0, basisY, basisZ)
                        rootEntity.addChild(basis)
                    }

                    let basisTransform = Transform(
                        scale: SIMD3<Float>(repeating: breadcrumbExpanded ? expandedScale : 1.0),
                        rotation: simd_quatf(angle: 0, axis: [0, 1, 0]),
                        translation: SIMD3<Float>(0, basisY, basisZ)
                    )
                    basis.move(to: basisTransform, relativeTo: rootEntity, duration: 0.4, timingFunction: .easeInOut)
                }
            }

            // === POSITIONIERUNG DER THEMEN ===
            // Karten sitzen statisch auf einem Kreis im LOKALEN Raum von ringEntity.
            // Drehen wir ringEntity um Y, rotieren alle Karten als geschlossener Ring mit —
            // wie ein Zahnrad. Frontposition in der Welt ist die Karte, deren lokaler Winkel
            // gerade ringAngle entspricht; ihr Index wird in aktuellerIndex gehalten.
            let angleStepLayout: Float = ringWinkelSchritt
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
                        // Blauer Gaze-Spotlight für beide; bei den Children etwas dezenter
                        // (geringere strength) als bei den Wurzel-Karten.
                        let spotStrength: Float = fokusThema == nil ? 20.0 : 10.0
                        panel.components.set(HoverEffectComponent(.spotlight(.init(color: .systemBlue, strength: spotStrength))))
                    }

                    let theta = Float(index) * angleStepLayout
                    let zielPosition = SIMD3<Float>(radiusLayout * sin(theta), cardYLayout, -radiusLayout * cos(theta))
                    let zielRotation = simd_quatf(angle: -theta, axis: [0, 1, 0])
                    // Die Karte in der Frontmitte (aktuellerIndex) wird vergrößert und
                    // hervorgehoben, damit beim Drehen klar sichtbar ist, welches Thema
                    // gerade zentriert ist. Gaze-Hover bleibt zusätzlich aktiv.
                    let isFront = isRootLevel && (index == aktuellerIndex)
                    let zielScale: Float = isFront ? 1.18 : 1.0

                    let prevMarker = panel.components[RingPanelMarker.self]
                    let zielTransform = Transform(
                        scale: SIMD3<Float>(repeating: zielScale),
                        rotation: zielRotation,
                        translation: zielPosition
                    )

                    if panel.parent == nil {
                        // Fly-in: Fokus-Ebenen fliegen vertikal rein. Beim Zurück/Überspringen
                        // (navigiertTiefer == false) fliegen ALLE neuen Karten von unten rein —
                        // auch das Wurzel-Karussell, damit jeder Zurück-Schritt gleich aussieht.
                        // Nur beim Vorwärts-Eintritt ins Wurzel-Karussell "poppen" die Karten.
                        let kommtVonUnten = !navigiertTiefer
                        if !isRootLevel || kommtVonUnten {
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
                        // Vertikaler Einflug (Fokus oder Zurück) gemächlicher als das reine
                        // Root-"Poppen" beim Vorwärts-Eintritt.
                        let dur: Double = (!isRootLevel || kommtVonUnten) ? 0.7 : 0.5
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
                    let nExpandedTotal = pfad.count + 3 // breadcrumbs (fokus + ancestors) + Basis-Raum + home
                    let expandedSpacing: Float = 0.22
                    let expandedCenterY: Float = 1.40
                    let expandedZ: Float = -1.55
                    let bottomY = expandedCenterY - Float(nExpandedTotal - 1) * expandedSpacing / 2.0
                    btnTarget = SIMD3<Float>(0, bottomY, expandedZ)
                } else {
                    btnTarget = SIMD3<Float>(0, -10, -2)
                }
                zuBtn.move(to: Transform(translation: btnTarget), relativeTo: rootEntity, duration: 0.4, timingFunction: .easeInOut)
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
                            panelsEingeblendet: panelsEingeblendet,
                            frontName: fokus.name
                        )
                    }
                }
                Attachment(id: "basis_crumb") {
                    BasisRaumCrumbView(
                        breadcrumbExpanded: breadcrumbExpanded,
                        panelsEingeblendet: panelsEingeblendet
                    )
                }
            }

            if leseModusAktiv, let lese = leseThema {
                Attachment(id: "lese_\(lese.id.uuidString)") {
                    LesePanelView(thema: lese, artikel: leseArtikel, laedt: leseLaedt, leseModusAktiv: leseModusAktiv, onClose: { schliesseLesemodus() })
                }
            }

            if fokusThema == nil && !leseModusAktiv {
                ForEach(Array(aktuelleThemen.enumerated()), id: \.element.id) { index, thema in
                    Attachment(id: "thema_\(thema.id.uuidString)") {
                        // Frontkarte (zentriert beim Drehen) wird hervorgehoben; alle
                        // anderen Karten reagieren weiterhin auf den Gaze-Hover.
                        themaPanel(thema: thema, isFront: index == aktuellerIndex)
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
        .task {
            // Kopf-Tracking starten, damit richteAufKopfrichtungAus() die aktuelle
            // Blickrichtung abfragen kann.
            try? await arkitSession.run([worldTracking])
        }
        .task {
            // Raum-Sound starten. Läuft bei jedem (Wieder-)Erscheinen der View erneut,
            // damit der Loop nach einem geöffneten/geschlossenen Fenster automatisch
            // wieder anspringt (das make-Closure läuft dabei nicht erneut).
            await starteRaumSound()
        }
        .task {
            // Kurze UI-Klick-Sounds einmal aus dem App-Bundle vorladen (nicht loopen),
            // damit sie bei Taps sofort abgespielt werden können.
            if let u = Bundle.main.url(forResource: "click_rpg", withExtension: "m4a") {
                clickKarten = try? await AudioFileResource(contentsOf: u, configuration: .init(shouldLoop: false))
            }
            if let u = Bundle.main.url(forResource: "click_bleep", withExtension: "m4a") {
                clickBreadcrumb = try? await AudioFileResource(contentsOf: u, configuration: .init(shouldLoop: false))
            }
        }
        .onDisappear { audioController?.stop() }
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
