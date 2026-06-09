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
                    GenericRoomView(skyboxTextureName: "sport_equirectangular", ambientSoundName: "fussball_sound")
                case "Natur":
                    GenericRoomView(skyboxTextureName: "nature_equirectangular", ambientSoundName: "natur_sound")
                case "Technik":
                    GenericRoomView(skyboxTextureName: "technik_equirectangular", ambientSoundName: "technik_sound", skyboxDrehungGrad: 60)
                case "Politik":
                    GenericRoomView(skyboxTextureName: "politik_equirectangular", ambientSoundName: "politik_sound")
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
