import SwiftUI

struct ContentView: View {
    @State private var themen: [Thema] = []
    @State private var status = "Lade Daten..."
    
    private let themenService = ThemenService()
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Wissensraum — DB Test")
                .font(.title)
            
            Text(status)
                .foregroundColor(.gray)
            
            ForEach(themen) { thema in
                Text("📦 \(thema.name) (Level \(thema.level))")
                    .font(.headline)
            }
        }
        .padding()
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
