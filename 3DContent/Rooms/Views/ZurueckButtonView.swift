import SwiftUI

struct ZurueckButtonView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.openWindow) private var openWindow
    let panelsEingeblendet: Bool

    var body: some View {
        Button {
            appModel.ausgewaehltesThema = nil
            openWindow(id: "main")
        } label: {
            Image("Artboard 5@300x")
                .resizable()
                .scaledToFit()
                .frame(height: 78)
                .opacity(0.82)
                .padding(.horizontal, 44)
                .padding(.vertical, 10)
                .background {
                    ZStack {
                        RoundedRectangle(cornerRadius: 28).fill(.ultraThinMaterial)
                        RoundedRectangle(cornerRadius: 28).fill(.black.opacity(0.18))
                        RoundedRectangle(cornerRadius: 28).fill(LinearGradient(
                            stops: [
                                .init(color: .white.opacity(0.12), location: 0),
                                .init(color: .clear, location: 0.6)
                            ],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                        RoundedRectangle(cornerRadius: 28).stroke(
                            .white.opacity(0.3),
                            lineWidth: 1.2
                        )
                    }
                }
                .shadow(color: .black.opacity(0.35), radius: 14, y: 6)
        }
        .buttonStyle(.plain)
        .roundedGazeHover(cornerRadius: 28)
        .scaleEffect(panelsEingeblendet ? 1.0 : 0.85)
        .opacity(panelsEingeblendet ? 1.0 : 0.0)
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: panelsEingeblendet)
    }
}
