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
            if !appModel.isImmersiveOpen {
                Image("VIEWS")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 320)

                Button {
                    Task {
                        await openImmersiveSpace(id: "ImmersiveSpace")
                        appModel.isImmersiveOpen = true
                        await ladeHauptkategorien()
                    }
                } label: {
                    Text("Start Experience")
                }
                .buttonStyle(GlassCardButtonStyle())
            } else {
                Image("Artboard 5@300x")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 320)

                Text(status)
                    .foregroundColor(.gray)

                ForEach(themen) { thema in
                    Button {
                        appModel.ausgewaehltesThema = thema
                        dismissWindow(id: "main")
                    } label: {
                        Text(thema.name)
                    }
                    .buttonStyle(GlassCardButtonStyle())
                }

                Button {
                    Task {
                        await dismissImmersiveSpace()
                        appModel.isImmersiveOpen = false
                        themen = []
                        appModel.ausgewaehltesThema = nil
                    }
                } label: {
                    Text("Experience beenden")
                }
                .buttonStyle(GlassCardButtonStyle(tint: .red))
                .padding(.top, 20)
            }
        }
        .padding(40)
        .task {
            if themen.isEmpty && appModel.isImmersiveOpen {
                await ladeHauptkategorien()
            }
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

/// Native-feeling visionOS glass card button: frosted ultra-thin material, generously
/// rounded corners, soft drop shadow, clean white text, and instant gaze-hover feedback
/// (rounded brighten + subtle 1.05× scale) that matches the card's shape exactly.
private struct GlassCardButtonStyle: ButtonStyle {
    var tint: Color = .white

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title2)
            .fontWeight(.semibold)
            .foregroundStyle(tint == .red ? Color.red.opacity(0.92) : Color.white)
            .shadow(color: .black.opacity(0.35), radius: 3, x: 0, y: 1)
            .frame(minWidth: 240)
            .padding(.horizontal, 32)
            .padding(.vertical, 18)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: 26).fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: 26).fill(.white.opacity(0.04))
                    RoundedRectangle(cornerRadius: 26).fill(LinearGradient(
                        stops: [.init(color: .white.opacity(0.14), location: 0), .init(color: .clear, location: 0.55)],
                        startPoint: .top, endPoint: .bottom
                    ))
                    RoundedRectangle(cornerRadius: 26).stroke(.white.opacity(0.18), lineWidth: 1)
                }
            }
            .shadow(color: .black.opacity(0.28), radius: 16, y: 8)
            .contentShape(.hoverEffect, RoundedRectangle(cornerRadius: 26))
            .hoverEffect(.highlight)
            .hoverEffect { effect, isActive, _ in
                effect.scaleEffect(isActive ? 1.05 : 1.0)
            }
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
