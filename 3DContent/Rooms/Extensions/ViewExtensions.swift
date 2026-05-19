import SwiftUI
import RealityKit

// Tracks the last applied "front" highlight state for a ring panel so the update
// closure only schedules a move(to:) when the visual target actually changed —
// without this guard, every unrelated @State change would restart the panels'
// scale animation, causing flicker.
struct RingPanelMarker: Component {
    var isFront: Bool
}

extension View {
    /// Native visionOS gaze feedback for an interactive card/button: an instant, rounded
    /// brighten plus a subtle 1.05× scale-up when the user looks at it. The highlight is
    /// shaped to the card's corner radius so it never reads as a rectangle over a rounded card.
    func roundedGazeHover(cornerRadius: CGFloat) -> some View {
        self
            .contentShape(.hoverEffect, RoundedRectangle(cornerRadius: cornerRadius))
            .hoverEffect(.highlight)
            .hoverEffect { effect, isActive, _ in
                effect.scaleEffect(isActive ? 1.05 : 1.0)
            }
    }

    /// Applies system hover effects (highlight + scale) only when isActiveChild is true.
    /// Root carousel cards omit these so the compositor doesn't intercept hover events
    /// before .onContinuousHover can set isGazed — which drives the blue background.
    @ViewBuilder
    func systemHoverIfActiveChild(_ isActiveChild: Bool) -> some View {
        if isActiveChild {
            self
                .hoverEffect(.highlight)
                .hoverEffect { effect, isActive, _ in
                    effect.scaleEffect(isActive ? 1.05 : 1.0)
                }
        } else {
            self
        }
    }
}
