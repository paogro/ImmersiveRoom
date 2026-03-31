//
//  ContentView.swift
//  ImmersiveRoom
//
//  Created by Paolo Grommes on 31.03.26.
//

import SwiftUI

struct ContentView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace

    var body: some View {
        Text("")
            .task {
                await openImmersiveSpace(id: appModel.immersiveSpaceID)
            }
    }
}
