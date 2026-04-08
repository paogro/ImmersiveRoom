import SwiftUI
import RealityKit
import RealityKitContent

struct SportRoomView: View {
    @Environment(AppModel.self) private var appModel
    @State private var unterthemen: [Thema] = []
    @State private var status = "Lade..."
    
    private let themenService = ThemenService()
    
    var body: some View {
        RealityView { content, attachments in
            // Dunkle Skybox (Nachthimmel-Feeling)
            let skybox = ModelEntity(
                mesh: .generateSphere(radius: 50),
                materials: [UnlitMaterial(color: UIColor(red: 0.05, green: 0.05, blue: 0.15, alpha: 1.0))]
            )
            skybox.scale = SIMD3<Float>(x: -1, y: 1, z: 1)
            content.add(skybox)
            
            // Debug-Panel direkt vor dem User
            if let debug = attachments.entity(for: "debug") {
                debug.position = SIMD3<Float>(0, 1.5, -2)
                content.add(debug)
            }
            
        } update: { content, attachments in
            for (index, thema) in unterthemen.enumerated() {
                if let panel = attachments.entity(for: thema.id.uuidString) {
                    // Direkt vor dem User, nebeneinander
                    let x = Float(index - unterthemen.count / 2) * 1.5
                    panel.position = SIMD3<Float>(x, 1.5, -3)
                    content.add(panel)
                }
            }
        } attachments: {
            // Debug-Anzeige
            Attachment(id: "debug") {
                Text(status)
                    .font(.title)
                    .foregroundColor(.yellow)
                    .padding(20)
                    .background(.black.opacity(0.7))
                    .cornerRadius(16)
            }
            
            // Unterthemen
            ForEach(unterthemen) { thema in
                Attachment(id: thema.id.uuidString) {
                    Text(thema.name)
                        .font(.extraLargeTitle)
                        .foregroundColor(.white)
                        .padding(30)
                        .background(.ultraThinMaterial)
                        .cornerRadius(20)
                }
            }
        }
        .task {
            guard let sportThema = appModel.ausgewaehltesThema else {
                status = "Kein Thema ausgewählt"
                return
            }
            status = "Lade Unterthemen für \(sportThema.name)..."
            do {
                unterthemen = try await themenService.getUnterthemen(vonThemaId: sportThema.id)
                status = "\(unterthemen.count) Unterthemen geladen"
            } catch {
                status = "Fehler: \(error.localizedDescription)"
            }
        }
    }
}
