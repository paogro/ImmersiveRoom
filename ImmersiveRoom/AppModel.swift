import SwiftUI

@MainActor
@Observable
class AppModel {
    let immersiveSpaceID = "ImmersiveSpace"
    enum ImmersiveSpaceState {
        case closed
        case inTransition
        case open
    }
    var immersiveSpaceState = ImmersiveSpaceState.closed
    var isImmersiveOpen = false
    var portalBoxIsOpen = false
    var ausgewaehltesThema: Thema? = nil
    var ausgewaehlteThemenProEbene: [UUID] = []
    // Aktuell geöffnetes Quelle-Web-Fenster (URL), um es gezielt wieder schließen zu können.
    var offeneQuelleURL: URL? = nil
}
