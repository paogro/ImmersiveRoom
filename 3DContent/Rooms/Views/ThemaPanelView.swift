import SwiftUI

// Per-card view that owns the @State needed to track its own gaze hover. A
// @ViewBuilder helper method can't hold per-instance state, so the root-room
// carousel cards are rendered through this struct. Gaze highlight (bright-white
// fill + 1.15× scale) is scoped to root cards via `isGazedRoot`; driven by
// .onContinuousHover / .onHover with no system hoverEffect intercepting events.
struct ThemaPanelView: View {
    let thema: Thema
    let isFront: Bool
    let isActiveChild: Bool
    let isGehalten: Bool
    let childHidden: Bool
    let panelsEingeblendet: Bool
    let animationDelay: Double

    @State private var isGazed: Bool = false

    var body: some View {
        // Gaze highlight only for root carousel cards — children keep their own cyan look.
        let isGazedRoot = !isActiveChild && !isFront && isGazed

        Text(thema.name)
            .font(isActiveChild ? .system(size: 54, weight: .bold) : .extraLargeTitle)
            .fontWeight(isActiveChild ? .bold : (isFront ? .bold : .semibold))
            .foregroundStyle(isGazedRoot ? Color.black.opacity(0.85) : ((!isActiveChild && !isFront) ? .white.opacity(0.5) : .white))
            .shadow(color: isGazedRoot ? .black.opacity(0.15) : .black.opacity(0.9), radius: 4, x: 0, y: 1)
            .multilineTextAlignment(.center)
            .frame(minWidth: isActiveChild ? 300 : 260)
            .padding(.horizontal, isActiveChild ? 56 : 48)
            .padding(.vertical, isActiveChild ? 40 : 32)
            .background {
                // Gaze highlight: stark opaque white so the contrast against dim
                // non-gazed cards is impossible to miss.
                if isGazedRoot {
                    ZStack {
                        // Outer corona: blurred white halo that bleeds outside the card bounds
                        RoundedRectangle(cornerRadius: 28)
                            .fill(Color.blue.opacity(0.4))
                            .blur(radius: 28)
                            .padding(-20)
                        // Solid bright fill
                        RoundedRectangle(cornerRadius: 28)
                            .fill(Color.blue.opacity(0.85))
                        // Bright border ring
                        RoundedRectangle(cornerRadius: 28)
                            .stroke(Color.blue, lineWidth: 4.0)
                        if isGehalten {
                            RoundedRectangle(cornerRadius: 28)
                                .stroke(
                                    LinearGradient(
                                        colors: [.white, .yellow.opacity(0.8), .white],
                                        startPoint: .topLeading, endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 3.0
                                )
                                .blur(radius: 1.5)
                        }
                    }
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 28)
                            .fill(.ultraThinMaterial)
                        RoundedRectangle(cornerRadius: 28)
                            .fill(.black.opacity(isActiveChild ? 0.22 : (isFront ? 0.16 : 0.40)))

                        if isActiveChild {
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
                        } else if isFront {
                            RoundedRectangle(cornerRadius: 28)
                                .fill(LinearGradient(
                                    colors: [.white.opacity(0.15), .blue.opacity(0.05), .clear],
                                    startPoint: .top, endPoint: .bottom
                                ))
                            RoundedRectangle(cornerRadius: 28)
                                .stroke(LinearGradient(
                                    colors: [.white.opacity(0.7), .blue.opacity(0.3), .white.opacity(0.3)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                ), lineWidth: 2.0)
                        } else {
                            RoundedRectangle(cornerRadius: 28)
                                .fill(LinearGradient(
                                    stops: [.init(color: .white.opacity(0.08), location: 0), .init(color: .clear, location: 0.4)],
                                    startPoint: .top, endPoint: .bottom
                                ))
                            RoundedRectangle(cornerRadius: 28)
                                .stroke(.white.opacity(0.12), lineWidth: 1.0)
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
            }
            .shadow(
                color: isGehalten
                    ? .cyan.opacity(0.7)
                    : (isActiveChild
                        ? .cyan.opacity(0.55)
                        : (isFront
                            ? .blue.opacity(0.4)
                            : (isGazedRoot ? .white : .black.opacity(0.25)))),
                radius: isGehalten ? 40 : (isActiveChild ? 38 : (isFront ? 30 : (isGazedRoot ? 90 : 8))),
                y: (isActiveChild || isFront || isGazedRoot) ? 12 : 6
            )
            // Hit-Region für sowohl Hover-Effekt als auch Hover-Events
            // explizit setzen — ohne das fängt visionOS das Gaze-Event in
            // RealityKit-Attachments nicht zuverlässig ein.
            .contentShape(.hoverEffect, RoundedRectangle(cornerRadius: 28))
            .contentShape(.interaction, RoundedRectangle(cornerRadius: 28))
            // System hover effects only for child cards. On root carousel cards they
            // compete with .onContinuousHover in the compositor, preventing isGazed
            // from ever being set. Root cards drive all visual feedback from isGazed.
            .systemHoverIfActiveChild(isActiveChild)
            .scaleEffect((panelsEingeblendet ? 1.0 : 0.7) * (isGehalten ? 1.06 : 1.0) * (!isActiveChild && isGazed ? 1.25 : 1.0))
            .opacity(panelsEingeblendet && !childHidden ? 1.0 : 0.0)
            // visionOS feuert .onContinuousHover zuverlässig über den Eye-Tracker
            // — auch in RealityKit-Attachments, anders als .onHover, das hier
            // gelegentlich nicht propagiert wird. .onHover bleibt als doppelte
            // Absicherung drin, falls eine der beiden APIs ausfällt.
            .onContinuousHover { phase in
                switch phase {
                case .active:
                    if !isGazed { isGazed = true }
                case .ended:
                    if isGazed { isGazed = false }
                }
            }
            .onHover { hovering in
                if isGazed != hovering { isGazed = hovering }
            }
            .animation(.easeOut(duration: 0.15), value: isGazedRoot)
            .animation(.spring(response: 0.5, dampingFraction: 0.75).delay(animationDelay), value: panelsEingeblendet)
            .animation(.easeOut(duration: 0.175), value: childHidden)
            .animation(.easeOut(duration: 0.25), value: isGehalten)
    }
}
