import SwiftUI

struct CrumbPanelView: View {
    let thema: Thema
    let isFront: Bool
    let breadcrumbExpanded: Bool
    let panelsEingeblendet: Bool

    var body: some View {
        let textVisible = isFront || breadcrumbExpanded
        HStack(spacing: 14) {
            Text(thema.name)
                .font(.title).fontWeight(.semibold)
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.9), radius: 3, x: 0, y: 1)
                .opacity(textVisible ? 1 : 0)
        }
        .animation(.easeInOut(duration: 0.3), value: textVisible)
        .padding(.horizontal, 40)
        .padding(.vertical, 22)
        .background {
            ZStack {
                // Solid-ish frosted pill: dark enough to stay clearly readable against any
                // environment, but calmer than the active child cards (no bright cyan accents).
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
        .roundedGazeHover(cornerRadius: 28)
        .scaleEffect(panelsEingeblendet ? 1.0 : 0.85)
        .opacity(panelsEingeblendet ? 1.0 : 0.0)
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: panelsEingeblendet)
    }
}

/// Eigener Breadcrumb-Eintrag, der zurück ins Start-Karussell (Basis-Raum) springt.
/// Wird nur im aufgeklappten Zustand zwischen den Vorfahren-Karten und dem Home-Button
/// angezeigt. Gleicher Pillen-Stil wie `CrumbPanelView`, mit Übersichts-Icon zur Abgrenzung.
struct BasisRaumCrumbView: View {
    let breadcrumbExpanded: Bool
    let panelsEingeblendet: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "square.grid.2x2.fill")
                .font(.title2).fontWeight(.semibold)
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.9), radius: 3, x: 0, y: 1)
            Text("Basis-Raum")
                .font(.title).fontWeight(.semibold)
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.9), radius: 3, x: 0, y: 1)
        }
        .opacity(breadcrumbExpanded ? 1 : 0)
        .animation(.easeInOut(duration: 0.3), value: breadcrumbExpanded)
        .padding(.horizontal, 40)
        .padding(.vertical, 22)
        .background {
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
        .roundedGazeHover(cornerRadius: 28)
        .scaleEffect(panelsEingeblendet ? 1.0 : 0.85)
        .opacity(panelsEingeblendet ? 1.0 : 0.0)
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: panelsEingeblendet)
    }
}
