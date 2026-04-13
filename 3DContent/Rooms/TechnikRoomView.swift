//
//  TechnikRoomView.swift
//  ImmersiveRoom
//
//  Created by Moritz Kosmann on 13.04.26.
//

import SwiftUI
import RealityKit

struct TechnikRoomView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismissImmersiveSpace) var dismissImmersiveSpace
    @Environment(\.openWindow) var openWindow
    
    var body: some View {
        RealityView { content, attachments in
            let skybox = ModelEntity(
                mesh: .generateSphere(radius: 50),
                materials: [UnlitMaterial(color: UIColor(red: 0.05, green: 0.05, blue: 0.15, alpha: 1.0))]
            )
            skybox.scale = SIMD3<Float>(x: -1, y: 1, z: 1)
            content.add(skybox)
            
            if let panel = attachments.entity(for: "zurueck") {
                panel.position = SIMD3<Float>(0, 1.2, -2)
                content.add(panel)
            }
        } attachments: {
            Attachment(id: "zurueck") {
                Button("Zurück zur Übersicht") {
                    appModel.ausgewaehltesThema = nil
                    openWindow(id: "main")
                }
                .font(.title2)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
                .cornerRadius(16)
            }
        }
    }
}
