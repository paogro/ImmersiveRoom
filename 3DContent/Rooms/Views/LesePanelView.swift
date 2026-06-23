import SwiftUI

// Detail-/Leseoverlay. Zeigt den neuesten freigegebenen News-Artikel zum Leaf-Topic
// (aus published_news_view), nicht mehr thema.description. Layout & Entrance-Animation
// sind unverändert; nur die Inhaltsquelle ist neu.
struct LesePanelView: View {
    let thema: Thema
    let artikel: NewsArtikel?
    let laedt: Bool
    let leseModusAktiv: Bool
    let onClose: () -> Void

    @Environment(AppModel.self) private var appModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        let zusammenfassung = artikel?.zusammenfassung.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let hatText = !zusammenfassung.isEmpty
        // Titel = die eigentliche Schlagzeile, sobald der Artikel geladen ist.
        // Fallback auf den Topic-Namen, solange noch nichts da ist.
        let titel = artikel?.headline ?? thema.name

        VStack(spacing: 20) {
            HStack(alignment: .top, spacing: 16) {
                // Nur die weiße Schlagzeile. Sie darf über mehrere Zeilen umbrechen und
                // schrumpft bei sehr langen Überschriften so weit, dass sie ganz lesbar bleibt.
                Text(titel)
                    .font(.extraLargeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                    .lineLimit(4)
                    .minimumScaleFactor(0.5)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer(minLength: 0)
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title)
                        .foregroundColor(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
            Divider().overlay(.white.opacity(0.3))

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if laedt {
                        // Artikel wird noch aus der DB geladen.
                        HStack(spacing: 14) {
                            ProgressView()
                            Text("Nachricht wird geladen …")
                                .font(.title2)
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .padding(.vertical, 20)
                    } else if hatText {
                        Text(zusammenfassung)
                            .font(.title2)
                            .foregroundColor(.white.opacity(0.92))
                            .lineSpacing(8)
                            .fixedSize(horizontal: false, vertical: true)

                        // "Mehr Infos" → Originalquelle öffnen.
                        if let url = artikel?.quelleURL {
                            Button {
                                appModel.offeneQuelleURL = url   // merken, um es gezielt schließen zu können
                                openWindow(id: "quelle", value: url)
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "arrow.up.right.square")
                                    Text("Mehr Infos – Quelle öffnen")
                                }
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 14)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.blue)
                            .padding(.top, 4)
                        }
                    } else {
                        // Kein freigegebener Artikel für dieses Thema vorhanden.
                        VStack(alignment: .leading, spacing: 12) {
                            Image(systemName: "newspaper")
                                .font(.system(size: 42))
                                .foregroundColor(.white.opacity(0.3))
                            Text("Für \"\(thema.name)\" liegt aktuell keine freigegebene Nachricht vor.")
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
        // Tap auf den Panel-Hintergrund schließt das Overlay. Die inneren Buttons
        // (✕ und "Mehr Infos") sind echte Buttons und fangen ihren Tap selbst ab,
        // bevor diese Hintergrund-Geste greift.
        .contentShape(Rectangle())
        .onTapGesture { onClose() }
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
