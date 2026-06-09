import SwiftUI

// Rein visuelles Home-Button-Panel. Tap & Gaze-Spotlight laufen über die Entity
// (siehe GenericRoomView: InputTargetComponent + HoverEffectComponent(.spotlight),
// Tap-Handling für "zurueck_btn" in RoomGestures) — analog zu den Breadcrumb-Karten.
struct ZurueckButtonView: View {
    let panelsEingeblendet: Bool

    var body: some View {
        Image("Artboard 5@300x")
            .resizable()
            .scaledToFit()
            .frame(height: 78)
            .opacity(0.95)
            .padding(.horizontal, 44)
            .padding(.vertical, 10)
            .background {
                // Gleicher dunkler Frosted-Pillen-Stil wie die Breadcrumb-Karten,
                // damit der Home-Button klar erkennbar ist und nicht ausgewaschen wirkt.
                ZStack {
                    RoundedRectangle(cornerRadius: 28).fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: 28).fill(.black.opacity(0.55))
                    RoundedRectangle(cornerRadius: 28).fill(LinearGradient(
                        stops: [
                            .init(color: .white.opacity(0.14), location: 0),
                            .init(color: .clear, location: 0.6)
                        ],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    RoundedRectangle(cornerRadius: 28).stroke(
                        .white.opacity(0.45),
                        lineWidth: 1.4
                    )
                }
            }
            .shadow(color: .black.opacity(0.35), radius: 14, y: 6)
            .scaleEffect(panelsEingeblendet ? 1.0 : 0.85)
            .opacity(panelsEingeblendet ? 1.0 : 0.0)
            .animation(.spring(response: 0.45, dampingFraction: 0.8), value: panelsEingeblendet)
    }
}
