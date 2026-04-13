import SwiftUI
import RealityKit
import RealityKitContent

struct ImmersiveView: View {
    @Environment(AppModel.self) private var appModel
    
    var body: some View {
        Group {
            if let thema = appModel.ausgewaehltesThema {
                switch thema.name {
                case "Sport":
                    SportRoomView()
                case "Natur":
                    NatureRoomView()
                case "Technik":
                    TechnikRoomView()
                case "Politik":
                    PolitikRoomView()
                default:
                    FallbackRoomView()
                }
            } else {
                FallbackRoomView()
            }
        }
    }
}

// Fallback bis die anderen Räume gebaut sind
struct FallbackRoomView: View {
    var body: some View {
        RealityView { content in
            let skybox = ModelEntity(
                mesh: .generateSphere(radius: 50),
                materials: [UnlitMaterial(color: .systemTeal)]
            )
            skybox.scale = SIMD3<Float>(x: -1, y: 1, z: 1)
            content.add(skybox)
        }
    }
}
