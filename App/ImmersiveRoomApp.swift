import SwiftUI

@main
struct ImmersiveRoomApp: App {
    @State private var appModel = AppModel()
    @State private var immersionStyle: ImmersionStyle = .mixed

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView()
                .environment(appModel)
        }

        ImmersiveSpace(id: appModel.immersiveSpaceID) {
            ImmersiveView()
                .environment(appModel)
                .onAppear {
                    appModel.immersiveSpaceState = .open
                }
                .onDisappear {
                    appModel.immersiveSpaceState = .closed
                }
                .onChange(of: appModel.ausgewaehltesThema) { _, newValue in
                    if newValue != nil {
                        immersionStyle = .full
                    } else {
                        immersionStyle = .mixed
                    }
                }
        }
        .immersionStyle(selection: $immersionStyle, in: .mixed, .full)
    }
}
