//
//  ImmersiveRoomApp.swift
//  ImmersiveRoom
//
//  Created by Paolo Grommes on 31.03.26.
//

import SwiftUI

@main
struct ImmersiveRoomApp: App {
    @State private var appModel = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appModel)
                .task {
                    // Immersive Space automatisch beim Start öffnen
                }
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
        }
        .immersionStyle(selection: .constant(.full), in: .full)
    }
}
