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

        // Eigenes Fenster für die Artikel-Quelle (In-App-Browser). Öffnet sich
        // neben der Immersive Space, sodass der Raum erhalten bleibt.
        WindowGroup(id: "quelle", for: URL.self) { $url in
            if let url {
                QuelleWebView(url: url)
            }
        }
        .defaultSize(width: 900, height: 700)

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

        ImmersiveSpace(id: PortalBoxConfiguration.immersiveSpaceID) {
            PortalBoxImmersiveView()
                .environment(appModel)
        }
    }
}
