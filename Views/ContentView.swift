import SwiftUI
import AVFoundation

struct ContentView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.openImmersiveSpace) var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) var dismissImmersiveSpace
    @Environment(\.dismissWindow) var dismissWindow

    @State private var themen: [Thema] = []
    @State private var status = ""
    @State private var immersiveTransitionInProgress = false
    @State private var startSoundPlayer: AVAudioPlayer?   // hält den Start-Klang am Leben

    private let themenService = ThemenService()
    // Stable fallback for the previous manual room picker flow.
    // Set to true to keep the four room buttons visible after starting PortalBox.
    private let manualRoomPickerFallbackEnabled = false

    var body: some View {
        VStack(spacing: 30) {
            if appModel.isImmersiveOpen && manualRoomPickerFallbackEnabled {
                manualRoomPickerFallbackView
            } else {
                startExperienceView
            }
        }
        .padding(40)
        .task {
            await bereinigeRueckkehrZurAuswahl()
            if manualRoomPickerFallbackEnabled && themen.isEmpty && appModel.isImmersiveOpen {
                await ladeHauptkategorien()
            }
        }
    }

    @ViewBuilder
    private var startExperienceView: some View {
        Image("VIEWS")
            .resizable()
            .scaledToFit()
            .frame(maxWidth: 320)

        Button {
            spieleStartSound()
            Task {
                await starteExperience()
            }
        } label: {
            Text("Start Experience")
        }
        .buttonStyle(GlassCardButtonStyle())
        .disabled(immersiveTransitionInProgress)

        if !status.isEmpty {
            Text(status)
                .foregroundColor(.gray)
        }
    }

    // Fallback: previous manual room selection screen with the four category buttons.
    // Keep this block intact so the stable manual flow can be restored quickly.
    @ViewBuilder
    private var manualRoomPickerFallbackView: some View {
        Image("Artboard 5@300x")
            .resizable()
            .scaledToFit()
            .frame(maxWidth: 320)

        Text(status)
            .foregroundColor(.gray)

        ForEach(themen) { thema in
            Button {
                Task {
                    await oeffneRaum(thema)
                }
            } label: {
                Text(thema.name)
            }
            .buttonStyle(GlassCardButtonStyle())
            .disabled(immersiveTransitionInProgress)
        }

        Button {
            Task {
                await beendeExperience()
            }
        } label: {
            Text("Experience beenden")
        }
        .buttonStyle(GlassCardButtonStyle(tint: .red))
        .padding(.top, 20)
        .disabled(immersiveTransitionInProgress)
    }

    // Spielt denselben Klick wie der Breadcrumb (Bleep Bloop) beim Start-Button.
    // Im 2D-Fenster ohne RealityKit-Szene → über AVAudioPlayer.
    private func spieleStartSound() {
        guard let url = Bundle.main.url(forResource: "click_bleep", withExtension: "m4a") else { return }
        do {
            startSoundPlayer = try AVAudioPlayer(contentsOf: url)
            startSoundPlayer?.play()
        } catch {
            print("Start-Sound konnte nicht abgespielt werden: \(error.localizedDescription)")
        }
    }

    func starteExperience() async {
        guard !immersiveTransitionInProgress else { return }
        immersiveTransitionInProgress = true
        defer { immersiveTransitionInProgress = false }

        if appModel.portalBoxIsOpen || appModel.immersiveSpaceState != .closed {
            await dismissImmersiveSpace()
            appModel.portalBoxIsOpen = false
            appModel.immersiveSpaceState = .closed
        }

        appModel.ausgewaehltesThema = nil
        status = ""

        switch await openImmersiveSpace(id: PortalBoxConfiguration.immersiveSpaceID) {
        case .opened:
            appModel.portalBoxIsOpen = true
            appModel.isImmersiveOpen = true

            if manualRoomPickerFallbackEnabled {
                if themen.isEmpty {
                    await ladeHauptkategorien()
                }
            } else {
                dismissWindow(id: "main")
            }
        case .error, .userCancelled:
            appModel.portalBoxIsOpen = false
            appModel.isImmersiveOpen = manualRoomPickerFallbackEnabled
            status = "PortalBox konnte nicht geöffnet werden."

            if manualRoomPickerFallbackEnabled && themen.isEmpty {
                await ladeHauptkategorien()
            }
        @unknown default:
            appModel.portalBoxIsOpen = false
            appModel.isImmersiveOpen = manualRoomPickerFallbackEnabled
            status = "PortalBox konnte nicht geöffnet werden."

            if manualRoomPickerFallbackEnabled && themen.isEmpty {
                await ladeHauptkategorien()
            }
        }
    }

    func oeffneRaum(_ thema: Thema) async {
        guard !immersiveTransitionInProgress else { return }
        immersiveTransitionInProgress = true
        defer { immersiveTransitionInProgress = false }

        if appModel.portalBoxIsOpen {
            await dismissImmersiveSpace()
            appModel.portalBoxIsOpen = false
            appModel.immersiveSpaceState = .closed
        }

        appModel.ausgewaehltesThema = thema

        switch appModel.immersiveSpaceState {
        case .open:
            dismissWindow(id: "main")
        case .closed:
            appModel.immersiveSpaceState = .inTransition
            switch await openImmersiveSpace(id: appModel.immersiveSpaceID) {
            case .opened:
                dismissWindow(id: "main")
            case .error, .userCancelled:
                appModel.ausgewaehltesThema = nil
                appModel.immersiveSpaceState = .closed
            @unknown default:
                appModel.ausgewaehltesThema = nil
                appModel.immersiveSpaceState = .closed
            }
        case .inTransition:
            appModel.ausgewaehltesThema = nil
        }
    }

    func beendeExperience() async {
        guard !immersiveTransitionInProgress else { return }
        immersiveTransitionInProgress = true
        defer { immersiveTransitionInProgress = false }

        if appModel.portalBoxIsOpen || appModel.immersiveSpaceState != .closed {
            await dismissImmersiveSpace()
        }

        appModel.portalBoxIsOpen = false
        appModel.immersiveSpaceState = .closed
        appModel.isImmersiveOpen = false
        appModel.ausgewaehltesThema = nil
        themen = []
        status = ""
    }

    func bereinigeRueckkehrZurAuswahl() async {
        guard appModel.isImmersiveOpen,
              appModel.ausgewaehltesThema == nil,
              !appModel.portalBoxIsOpen,
              appModel.immersiveSpaceState == .open,
              !immersiveTransitionInProgress
        else {
            return
        }

        immersiveTransitionInProgress = true
        await dismissImmersiveSpace()
        appModel.immersiveSpaceState = .closed
        immersiveTransitionInProgress = false
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
