import SwiftUI
import RealityKit
import RealityKitContent

struct ImmersiveView: View {
    var body: some View {
        RealityView { content in
            let skybox = ModelEntity(
                mesh: .generateSphere(radius: 50),
                materials: [UnlitMaterial(color: .systemTeal)]
            )
            skybox.scale = SIMD3<Float>(x: -1, y: 1, z: 1)
            skybox.position = SIMD3<Float>(0, 0, 0)
            content.add(skybox)
        }
    }
}
