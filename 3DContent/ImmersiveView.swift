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
                    GenericRoomView(skyboxTextureName: "sport_equirectangular")
                case "Natur":
                    GenericRoomView(skyboxTextureName: "natur_equirectangular")
                case "Technik":
                    GenericRoomView(skyboxTextureName: "technik_equirectangular")
                case "Politik":
                    GenericRoomView(skyboxTextureName: "politik_equirectangular")
                default:
                    FallbackRoomView()
                }
            } else {
                FallbackRoomView()
            }
        }
    }
}

struct FallbackRoomView: View {
    var body: some View {
        RealityView { content in }
    }
}
