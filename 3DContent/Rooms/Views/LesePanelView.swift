import SwiftUI

struct LesePanelView: View {
    let thema: Thema
    let leseModusAktiv: Bool

    var body: some View {
        let beschreibung = thema.description?.trimmingCharacters(in: .whitespacesAndNewlines)
        let hatBeschreibung = !(beschreibung?.isEmpty ?? true)

        VStack(spacing: 20) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Info")
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundColor(.blue.opacity(0.85))
                        .textCase(.uppercase)
                        .tracking(1.5)
                    Text(thema.name)
                        .font(.extraLargeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundColor(.white.opacity(0.5))
            }
            Divider().overlay(.white.opacity(0.3))
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if hatBeschreibung, let text = beschreibung {
                        Text(text)
                            .font(.title2)
                            .foregroundColor(.white.opacity(0.92))
                            .lineSpacing(8)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            Image(systemName: "text.alignleft")
                                .font(.system(size: 42))
                                .foregroundColor(.white.opacity(0.3))
                            Text("Für \"\(thema.name)\" ist noch keine Beschreibung hinterlegt.")
                                .font(.title2)
                                .foregroundColor(.white.opacity(0.6))
                                .lineSpacing(6)
                        }
                        .padding(.vertical, 20)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(width: 700, height: 500)
        .padding(40)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 32)
                    .fill(.black.opacity(0.4))

                RoundedRectangle(cornerRadius: 32)
                    .fill(.ultraThinMaterial)

                RoundedRectangle(cornerRadius: 32)
                    .fill(LinearGradient(
                        stops: [.init(color: .white.opacity(0.12), location: 0), .init(color: .clear, location: 0.3)],
                        startPoint: .top, endPoint: .bottom
                    ))

                RoundedRectangle(cornerRadius: 32)
                    .stroke(LinearGradient(
                        colors: [.white.opacity(0.5), .white.opacity(0.15), .white.opacity(0.3)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ), lineWidth: 1.5)
            }
        }
        .shadow(color: .black.opacity(0.3), radius: 30, y: 12)
        .scaleEffect(leseModusAktiv ? 1.0 : 0.5)
        .opacity(leseModusAktiv ? 1.0 : 0.0)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: leseModusAktiv)
    }
}
