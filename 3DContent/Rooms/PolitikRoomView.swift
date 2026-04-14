//
//  PolitikRoomView.swift
//  ImmersiveRoom
//
//  Created by Moritz Kosmann on 13.04.26.
//

import SwiftUI
import RealityKit

struct PolitikRoomView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismissImmersiveSpace) var dismissImmersiveSpace
    @Environment(\.openWindow) var openWindow
    
    var body: some View {
        RealityView { content, attachments in
            let skybox = ModelEntity(
                mesh: .generateSphere(radius: 50),
                materials: [UnlitMaterial(color: .systemRed)]
            )
            skybox.scale = SIMD3<Float>(x: -1, y: 1, z: 1)
            
            if let texture = try? TextureResource.load(named: "politik_equirectangular") {
                var material = UnlitMaterial()
                material.color = .init(texture: .init(texture))
                skybox.model?.materials = [material]
            }
            
            content.add(skybox)
            
            if let panel = attachments.entity(for: "zurueck") {
                panel.position = SIMD3<Float>(0, 1.2, -1.5)
                content.add(panel)
            }
        } attachments: {
            Attachment(id: "zurueck") {
                Button("Zurück zur Übersicht") {
                    openWindow(id: "main")
                    appModel.ausgewaehltesThema = nil
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
