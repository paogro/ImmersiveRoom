import SwiftUI
import ARKit
import QuartzCore
import RealityKit
import RealityKitContent
import simd

enum PortalBoxConfiguration {
    static let immersiveSpaceID = "PortalBoxSpace"
}

private struct PortalThemeMapping: Identifiable {
    let portalNumber: Int
    let themeName: String
    let skyboxTextureName: String
    let fallbackSkyboxTextureName: String
    let anchorName: String

    var id: Int { portalNumber }
    var labelAttachmentID: String { "portal-preview-label-\(portalNumber)" }
}

@MainActor
struct PortalBoxImmersiveView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.openWindow) private var openWindow

    @State private var box = Entity()

    @State private var world1 = Entity()
    @State private var world2 = Entity()
    @State private var world3 = Entity()
    @State private var world4 = Entity()
    @State private var portalEntities: [Int: Entity] = [:]
    @State private var previousDevicePosition: SIMD3<Float>?
    @State private var isTransitioning = false

    private let arKitSession = ARKitSession()
    private let worldTracking = WorldTrackingProvider()
    private let themenService = ThemenService()

    private let portalThemeMappings = [
        PortalThemeMapping(
            portalNumber: 1,
            themeName: "Sport",
            skyboxTextureName: "sport_equirectangular",
            fallbackSkyboxTextureName: "skybox1",
            anchorName: "AnchorPortal1"
        ),
        PortalThemeMapping(
            portalNumber: 2,
            themeName: "Natur",
            skyboxTextureName: "nature_equirectangular",
            fallbackSkyboxTextureName: "skybox2",
            anchorName: "AnchorPortal2"
        ),
        PortalThemeMapping(
            portalNumber: 3,
            themeName: "Technik",
            skyboxTextureName: "technik_equirectangular",
            fallbackSkyboxTextureName: "skybox3",
            anchorName: "AnchorPortal3"
        ),
        PortalThemeMapping(
            portalNumber: 4,
            themeName: "Politik",
            skyboxTextureName: "politik_equirectangular",
            fallbackSkyboxTextureName: "skybox4",
            anchorName: "AnchorPortal4"
        )
    ]

    // Non-destructive fallback for the original PortalBox demo scenes.
    // Keep false for VIEWS previews; set true to compare against the imported demo worlds.
    private let showImportedPortalBoxDemoObjects = false
    private let portalHalfExtent: Float = 0.55
    private let portalBoundsMargin: Float = 0.12
    private let minimumCrossingDistance: Float = 0.01

    var body: some View {
        RealityView { content, attachments in
            if let scene = try? await Entity(named: "PortalBoxScene", in: realityKitContentBundle) {
                content.add(scene)

                guard let box = scene.findEntity(named: "Box") else {
                    fatalError()
                }

                self.box = box
                box.position = [0, 1, -4]
                box.scale *= [1, 2, 1]
                portalEntities = [:]
                previousDevicePosition = nil

                let worlds = await createWorlds()
                content.add(worlds)

                let portals = createPortals { attachmentID in
                    attachments.entity(for: attachmentID)
                }
                content.add(portals)

                if showImportedPortalBoxDemoObjects {
                    await addContentToWorlds()
                }
            }
        } attachments: {
            ForEach(portalThemeMappings) { mapping in
                Attachment(id: mapping.labelAttachmentID) {
                    VStack(spacing: 2) {
                        Text(mapping.themeName)
                            .font(.headline)
                            .fontWeight(.bold)
                        Text("Portal \(mapping.portalNumber)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.black.opacity(0.58), in: Capsule())
                }
            }
        }
        .task {
            await runPortalWalkThroughDetection()
        }
        .onDisappear {
            previousDevicePosition = nil
            isTransitioning = false
            if appModel.portalBoxIsOpen {
                appModel.portalBoxIsOpen = false
            }
        }
    }

    func createWorlds() async -> Entity {
        let worlds = Entity()

        let sportMapping = portalThemeMappings[0]
        world1 = await createWorld(for: sportMapping)
        worlds.addChild(world1)

        let natureMapping = portalThemeMappings[1]
        world2 = await createWorld(for: natureMapping)
        worlds.addChild(world2)

        let technologyMapping = portalThemeMappings[2]
        world3 = await createWorld(for: technologyMapping)
        worlds.addChild(world3)

        let politicsMapping = portalThemeMappings[3]
        world4 = await createWorld(for: politicsMapping)
        worlds.addChild(world4)

        return worlds
    }

    private func createWorld(for mapping: PortalThemeMapping) async -> Entity {
        let world = Entity()
        world.name = "\(mapping.themeName)PreviewWorld"
        world.components.set(WorldComponent())

        let skybox = await createSkyboxEntity(
            texture: mapping.skyboxTextureName,
            fallbackTexture: mapping.fallbackSkyboxTextureName
        )
        world.addChild(skybox)

        return world
    }

    func createPortals(labelEntity: (String) -> Entity?) -> Entity {
        let portals = Entity()

        let sportMapping = portalThemeMappings[0]
        attachPortal(
            createPortal(target: world1),
            mapping: sportMapping,
            to: portals,
            rotation: simd_quatf(angle: .pi / 2, axis: [1, 0, 0]),
            labelEntity: labelEntity
        )

        let natureMapping = portalThemeMappings[1]
        attachPortal(
            createPortal(target: world2),
            mapping: natureMapping,
            to: portals,
            rotation: simd_quatf(angle: -.pi / 2, axis: [1, 0, 0]),
            labelEntity: labelEntity
        )

        let technologyMapping = portalThemeMappings[2]

        let portal3RotX = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
        let portal3RotY = simd_quatf(angle: -.pi / 2, axis: [0, 1, 0])
        attachPortal(
            createPortal(target: world3),
            mapping: technologyMapping,
            to: portals,
            rotation: portal3RotY * portal3RotX,
            labelEntity: labelEntity
        )

        let politicsMapping = portalThemeMappings[3]

        let portal4RotX = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
        let portal4RotY = simd_quatf(angle: .pi / 2, axis: [0, 1, 0])
        attachPortal(
            createPortal(target: world4),
            mapping: politicsMapping,
            to: portals,
            rotation: portal4RotY * portal4RotX,
            labelEntity: labelEntity
        )

        return portals
    }

    private func attachPortal(
        _ portal: Entity,
        mapping: PortalThemeMapping,
        to portals: Entity,
        rotation: simd_quatf,
        labelEntity: (String) -> Entity?
    ) {
        portals.addChild(portal)

        guard let anchorPortal = box.findEntity(named: mapping.anchorName) else {
            fatalError("Cannot find portal anchor")
        }

        anchorPortal.addChild(portal)
        portal.transform.rotation = rotation
        portal.name = "\(mapping.themeName)PortalTrigger"
        portalEntities[mapping.portalNumber] = portal

        if let label = labelEntity(mapping.labelAttachmentID) {
            configurePortalLabel(label, mapping: mapping, rotation: rotation)
            anchorPortal.addChild(label)
        }
    }

    private func configurePortalLabel(_ label: Entity, mapping: PortalThemeMapping, rotation: simd_quatf) {
        label.name = "\(mapping.themeName)PortalLabel"
        label.position = [0, 0.72, 0]
        label.scale = [0.45, 0.45, 0.45]
        label.transform.rotation = rotation
    }

    func addContentToWorlds() async {
        if let world1Scene = try? await Entity(named: "World1Scene", in: realityKitContentBundle) {
            world1Scene.position = [0, 3, 0]
            world1.addChild(world1Scene)
        }

        if let world2Scene = try? await Entity(named: "World2Scene", in: realityKitContentBundle) {
            world2Scene.position = [0, 3, 0]
            world2.addChild(world2Scene)
        }

        if let world3Scene = try? await Entity(named: "World3Scene", in: realityKitContentBundle) {
            world3Scene.position = [0, 10, 0]
            world3.addChild(world3Scene)
        }

        if let world4Scene = try? await Entity(named: "World4Scene", in: realityKitContentBundle) {
            world4Scene.position = [0, 10, 0]
            world4.addChild(world4Scene)
        }
    }

    func createSkyboxEntity(texture: String, fallbackTexture: String) async -> Entity {
        var resource = try? await TextureResource(named: texture)
        if resource == nil {
            resource = try? await TextureResource(named: fallbackTexture)
        }

        guard let resource else {
            fatalError("Unable to load the skybox")
        }

        var material = UnlitMaterial()
        material.color = .init(texture: .init(resource))

        let entity = Entity()
        entity.components.set(ModelComponent(mesh: .generateSphere(radius: 1000), materials: [material]))
        entity.scale *= .init(x: -1, y: 1, z: 1)
        return entity
    }

    func createPortal(target: Entity) -> Entity {
        let portalMesh = MeshResource.generatePlane(width: 1, depth: 1)
        let portal = ModelEntity(mesh: portalMesh, materials: [PortalMaterial()])
        portal.components.set(PortalComponent(target: target))
        return portal
    }

    private func runPortalWalkThroughDetection() async {
        guard WorldTrackingProvider.isSupported else {
            print("PortalBox walkthrough detection unavailable: WorldTrackingProvider is not supported.")
            return
        }

        do {
            try await arKitSession.run([worldTracking])
        } catch {
            print("PortalBox walkthrough detection could not start ARKitSession: \(error.localizedDescription)")
            return
        }

        while !Task.isCancelled {
            await detectPortalCrossingIfNeeded()
            try? await Task.sleep(nanoseconds: 33_000_000)
        }
    }

    private func detectPortalCrossingIfNeeded() async {
        guard !isTransitioning,
              !portalEntities.isEmpty,
              let currentPosition = currentDevicePosition()
        else {
            return
        }

        defer {
            previousDevicePosition = currentPosition
        }

        guard let previousPosition = previousDevicePosition else {
            return
        }

        guard let mapping = crossedPortalMapping(from: previousPosition, to: currentPosition) else {
            return
        }

        print("PortalBox walkthrough detected: Portal \(mapping.portalNumber) -> \(mapping.themeName)")
        isTransitioning = true
        Task { @MainActor in
            await openThemeRoom(for: mapping)
        }
    }

    private func currentDevicePosition() -> SIMD3<Float>? {
        guard let deviceAnchor = worldTracking.queryDeviceAnchor(atTimestamp: CACurrentMediaTime()) else {
            return nil
        }

        let transform = deviceAnchor.originFromAnchorTransform
        return SIMD3<Float>(
            transform.columns.3.x,
            transform.columns.3.y,
            transform.columns.3.z
        )
    }

    private func crossedPortalMapping(from previousWorldPosition: SIMD3<Float>, to currentWorldPosition: SIMD3<Float>) -> PortalThemeMapping? {
        for mapping in portalThemeMappings {
            guard let portal = portalEntities[mapping.portalNumber] else {
                continue
            }

            let previousLocal = portal.convert(position: previousWorldPosition, from: nil)
            let currentLocal = portal.convert(position: currentWorldPosition, from: nil)

            guard crossesPortalPlane(from: previousLocal, to: currentLocal),
                  isMovingIntoBox(from: previousWorldPosition, to: currentWorldPosition)
            else {
                continue
            }

            return mapping
        }

        return nil
    }

    private func crossesPortalPlane(from previousLocalPosition: SIMD3<Float>, to currentLocalPosition: SIMD3<Float>) -> Bool {
        let previousDistance = previousLocalPosition.y
        let currentDistance = currentLocalPosition.y
        let delta = abs(previousDistance - currentDistance)

        guard delta >= minimumCrossingDistance else {
            return false
        }

        let crossedPlane = (previousDistance > 0 && currentDistance <= 0)
            || (previousDistance < 0 && currentDistance >= 0)
        guard crossedPlane else {
            return false
        }

        let crossingProgress = previousDistance / (previousDistance - currentDistance)
        guard crossingProgress >= 0, crossingProgress <= 1 else {
            return false
        }

        let crossingPosition = previousLocalPosition
            + (currentLocalPosition - previousLocalPosition) * crossingProgress
        let allowedExtent = portalHalfExtent + portalBoundsMargin

        return abs(crossingPosition.x) <= allowedExtent
            && abs(crossingPosition.z) <= allowedExtent
    }

    private func isMovingIntoBox(from previousWorldPosition: SIMD3<Float>, to currentWorldPosition: SIMD3<Float>) -> Bool {
        let previousBoxPosition = box.convert(position: previousWorldPosition, from: nil)
        let currentBoxPosition = box.convert(position: currentWorldPosition, from: nil)
        let previousDistance = simd_length(SIMD2<Float>(previousBoxPosition.x, previousBoxPosition.z))
        let currentDistance = simd_length(SIMD2<Float>(currentBoxPosition.x, currentBoxPosition.z))

        return currentDistance < previousDistance
    }

    private func openThemeRoom(for mapping: PortalThemeMapping) async {
        defer {
            isTransitioning = false
        }

        do {
            let themen = try await themenService.getHauptkategorien()
            guard let thema = themen.first(where: { $0.name.localizedCaseInsensitiveCompare(mapping.themeName) == .orderedSame }) else {
                print("PortalBox walkthrough ignored: topic '\(mapping.themeName)' was not found.")
                return
            }

            await dismissImmersiveSpace()
            appModel.portalBoxIsOpen = false
            appModel.immersiveSpaceState = .closed
            appModel.ausgewaehltesThema = thema
            appModel.isImmersiveOpen = true
            appModel.immersiveSpaceState = .inTransition

            switch await openImmersiveSpace(id: appModel.immersiveSpaceID) {
            case .opened:
                print("PortalBox walkthrough opened room: \(mapping.themeName)")
            case .error, .userCancelled:
                resetStateAfterFailedRoomOpen()
            @unknown default:
                resetStateAfterFailedRoomOpen()
            }
        } catch {
            print("PortalBox walkthrough ignored: failed to load topics for '\(mapping.themeName)': \(error.localizedDescription)")
        }
    }

    private func resetStateAfterFailedRoomOpen() {
        print("PortalBox walkthrough failed: room could not be opened.")
        appModel.ausgewaehltesThema = nil
        appModel.portalBoxIsOpen = false
        appModel.immersiveSpaceState = .closed
        appModel.isImmersiveOpen = false
        openWindow(id: "main")
    }
}

#Preview(immersionStyle: .mixed) {
    PortalBoxImmersiveView()
        .environment(AppModel())
}
