import SwiftUI

struct ContentView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.openImmersiveSpace) var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) var dismissImmersiveSpace
    @Environment(\.dismissWindow) var dismissWindow
    
    @State private var themen: [Thema] = []
    @State private var status = ""
    
    private let themenService = ThemenService()
    
    var body: some View {
        VStack(spacing: 30) {
            Text("Wissensraum")
                .font(.largeTitle)
            
            if !appModel.isImmersiveOpen {
                Button("Start Experience") {
                    Task {
                        await openImmersiveSpace(id: "ImmersiveSpace")
                        appModel.isImmersiveOpen = true
                        await ladeHauptkategorien()
                    }
                }
                .font(.title2)
            } else {
                Text(status)
                    .foregroundColor(.gray)
                
                ForEach(themen) { thema in
                    Button(thema.name) {
                        appModel.ausgewaehltesThema = thema
                        dismissWindow()
                    }
                    .font(.title2)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 8)
                }
                
                Button("Experience beenden") {
                    Task {
                        await dismissImmersiveSpace()
                        appModel.isImmersiveOpen = false
                        themen = []
                        appModel.ausgewaehltesThema = nil
                    }
                }
                .foregroundColor(.red)
                .padding(.top, 20)
            }
        }
        .padding(40)
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
