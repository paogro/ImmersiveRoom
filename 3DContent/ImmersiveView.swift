//
//  ImmersiveView.swift
//  ImmersiveRoom
//
//  Created by Paolo Grommes on 31.03.26.
//

import SwiftUI
import RealityKit
import RealityKitContent

struct ImmersiveView: View {
    @Environment(AppModel.self) private var appModel
    @State private var themen: [Thema] = []
    @State private var status = ""
    
    private let themenService = ThemenService()
    
    var body: some View {
        RealityView { content, attachments in
            // Skybox
            let skybox = ModelEntity(
                mesh: .generateSphere(radius: 50),
                materials: [UnlitMaterial(color: .systemTeal)]
            )
            skybox.scale = SIMD3<Float>(x: -1, y: 1, z: 1)
            skybox.position = SIMD3<Float>(0, 0, 0)
            content.add(skybox)
            
            // UI-Panel vor dem Nutzer platzieren
            if let panel = attachments.entity(for: "mainPanel") {
                panel.position = SIMD3<Float>(0, 1.5, -2)
                content.add(panel)
            }
        } attachments: {
            Attachment(id: "mainPanel") {
                VStack(spacing: 20) {
                    if appModel.showThemen {
                        Text("Wissensraum")
                            .font(.extraLargeTitle)
                            .foregroundColor(.white)
                        
                        Text(status)
                            .foregroundColor(.gray)
                        
                        ForEach(themen) { thema in
                            Text("📦 \(thema.name) (Level \(thema.level))")
                                .font(.title)
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(.ultraThinMaterial)
                                .cornerRadius(16)
                        }
                        
                        Button("Zurück") {
                            withAnimation {
                                appModel.showThemen = false
                            }
                        }
                        .padding(.top, 20)
                    } else {
                        Button("Start Experience") {
                            withAnimation {
                                appModel.showThemen = true
                            }
                        }
                        .font(.title)
                        .padding()
                    }
                }
                .padding(40)
            }
        }
        .task {
            await ladeHauptkategorien()
        }
    }
    
    func ladeHauptkategorien() async {
        do {
            themen = try await themenService.getHauptkategorien()
            status = "\(themen.count) Kategorien geladen ✓"
        } catch {
            status = "Fehler: \(error.localizedDescription)"
        }
    }
}

#Preview(immersionStyle: .full) {
    ImmersiveView()
        .environment(AppModel())
}
