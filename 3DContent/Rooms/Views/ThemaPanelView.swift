import SwiftUI

// Card view for root + child topic panels. The blue gaze highlight is rendered
// by the system via HoverEffectComponent on the RealityKit entity (see
// GenericRoomView). visionOS does not expose gaze position to apps, so this
// view stays purely declarative — no @State for hover. The .hoverEffect builder
// adds a scale bump when gazed; the system evaluates `isActive` in the
// compositor without leaking position to the app.
struct ThemaPanelView: View {
    let thema: Thema
    let isFront: Bool
    let isActiveChild: Bool
    let isGehalten: Bool
    let childHidden: Bool
    let panelsEingeblendet: Bool
    let animationDelay: Double

    private var textColor: Color {
        (!isActiveChild && !isFront) ? .white.opacity(0.9) : .white
    }

    private var shadowColor: Color {
        if isGehalten { return .cyan.opacity(0.7) }
        if isActiveChild { return .cyan.opacity(0.55) }
        return .black.opacity(0.25)
    }

    private var shadowRadius: CGFloat {
        if isGehalten { return 40 }
        if isActiveChild { return 38 }
        return 8
    }

    private var shadowOffsetY: CGFloat {
        isActiveChild ? 12 : 6
    }

    private var combinedScale: CGFloat {
        let appearScale: CGFloat = panelsEingeblendet ? 1.0 : 0.7
        let holdScale: CGFloat = isGehalten ? 1.06 : 1.0
        return appearScale * holdScale
    }

    var body: some View {
        panelText
            .background { panelBackground }
            .shadow(color: shadowColor, radius: shadowRadius, y: shadowOffsetY)
            // Hit-Region für sowohl Hover-Effekt als auch Hover-Events
            // explizit setzen — ohne das fängt visionOS das Gaze-Event in
            // RealityKit-Attachments nicht zuverlässig ein.
            .contentShape(.hoverEffect, RoundedRectangle(cornerRadius: 28))
            .contentShape(.interaction, RoundedRectangle(cornerRadius: 28))
            // Scale bump on gaze — system evaluates isActive without exposing
            // the gaze location to the app. Only applied to root cards; child
            // cards keep their own steady layout.
            .hoverEffect { effect, isActive, _ in
                effect.scaleEffect(!isActiveChild && isActive ? 1.15 : 1.0)
            }
            .scaleEffect(combinedScale)
            .opacity(panelsEingeblendet && !childHidden ? 1.0 : 0.0)
            .animation(.spring(response: 0.5, dampingFraction: 0.75).delay(animationDelay), value: panelsEingeblendet)
            .animation(.easeOut(duration: 0.175), value: childHidden)
            .animation(.easeOut(duration: 0.25), value: isGehalten)
    }

    private var panelText: some View {
        Text(thema.name)
            .font(isActiveChild ? .system(size: 54, weight: .bold) : .extraLargeTitle)
            .fontWeight(isActiveChild ? .bold : (isFront ? .bold : .semibold))
            .foregroundStyle(textColor)
            .shadow(color: .black.opacity(0.9), radius: 4, x: 0, y: 1)
            .multilineTextAlignment(.center)
            .frame(minWidth: isActiveChild ? 300 : 260)
            .padding(.horizontal, isActiveChild ? 56 : 48)
            .padding(.vertical, isActiveChild ? 40 : 32)
    }

    private var panelBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28)
                .fill(.ultraThinMaterial)
            RoundedRectangle(cornerRadius: 28)
                .fill(.black.opacity(isActiveChild ? 0.22 : 0.55))

            if isActiveChild {
                childOverlay
            } else {
                // Root cards (front & side) share the same neutral idle look.
                // The blue gaze layer covers them when the system reports the
                // attachment is being gazed at.
                rootIdleOverlay
                blueGazeLayer
            }

            if isGehalten {
                RoundedRectangle(cornerRadius: 28)
                    .stroke(
                        LinearGradient(
                            colors: [.blue, .cyan, .blue],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        lineWidth: 3.0
                    )
                    .blur(radius: 1.5)
            }
        }
    }

    // Strong blue card overlay, always rendered into the layer tree (so the
    // compositor can track it) but invisible until the system reports the
    // attachment as gazed-at. `.hoverEffect`'s closure runs in the compositor
    // with `isActive` — gaze location itself is never exposed to the app.
    private var blueGazeLayer: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28)
                .fill(Color.blue.opacity(0.92))
            RoundedRectangle(cornerRadius: 28)
                .stroke(Color.white, lineWidth: 5.0)
        }
        .hoverEffect { effect, isActive, _ in
            effect.opacity(isActive ? 1.0 : 0.0)
        }
    }

    private var childOverlay: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28)
                .fill(LinearGradient(
                    colors: [.white.opacity(0.18), .cyan.opacity(0.10), .clear],
                    startPoint: .top, endPoint: .bottom
                ))
            RoundedRectangle(cornerRadius: 28)
                .stroke(LinearGradient(
                    colors: [.white.opacity(0.95), .cyan.opacity(0.65), .white.opacity(0.55)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ), lineWidth: 2.5)
        }
    }

    private var rootIdleOverlay: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28)
                .fill(LinearGradient(
                    stops: [.init(color: .white.opacity(0.08), location: 0), .init(color: .clear, location: 0.4)],
                    startPoint: .top, endPoint: .bottom
                ))
            RoundedRectangle(cornerRadius: 28)
                .stroke(.white.opacity(0.5), lineWidth: 1.5)
        }
    }
}
