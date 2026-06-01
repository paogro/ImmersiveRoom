import SwiftUI
import RealityKit

extension GenericRoomView {

    // MARK: - Animation

    func animierePanels(skipBounce: Bool = false) {
        // Only remove entities that no longer belong in the new state. Persisting entities
        // stay parented so they don't re-mount and re-trigger their initial-offset move(to:),
        // which would double up on the move triggered by the state change itself.
        let validCrumb: Set<String>
        let validChild: Set<String>
        let validThema: Set<String>
        if let fokus = fokusThema {
            validCrumb = Set((pfad + [fokus]).map { "crumb_\($0.id.uuidString)" })
            validChild = Set(childrenThemen.map { "child_\($0.id.uuidString)" })
            validThema = []
        } else {
            validCrumb = []
            validChild = []
            validThema = Set(aktuelleThemen.map { "thema_\($0.id.uuidString)" })
        }

        let staleRoot = rootEntity.children.filter { entity in
            if entity.name.hasPrefix("crumb_") { return !validCrumb.contains(entity.name) }
            return false
        }
        staleRoot.forEach { $0.removeFromParent() }

        // Theme cards live under ringEntity (so they rotate together as one ring).
        let staleRing = ringEntity.children.filter { entity in
            if entity.name.hasPrefix("child_") { return !validChild.contains(entity.name) }
            if entity.name.hasPrefix("thema_") { return !validThema.contains(entity.name) }
            return false
        }
        staleRing.forEach { $0.removeFromParent() }

        if skipBounce {
            // Back-navigation: only the RealityView move(to:) translation should animate
            // (fokus drops into stack, children slide in from below). Skip the
            // panelsEingeblendet opacity+scale spring so it doesn't double up.
            panelsEingeblendet = true
        } else {
            panelsEingeblendet = false
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.1)) {
                panelsEingeblendet = true
            }
        }
    }

    // MARK: - Lesemodus

    /// Öffnet den Lesemodus für ein Leaf-Thema und lädt dazu den neuesten
    /// freigegebenen News-Artikel aus published_news_view nach. Das Panel
    /// erscheint sofort (mit Lade-Indikator); der Inhalt wird asynchron
    /// nachgereicht, sobald die DB-Antwort da ist.
    func oeffneLesemodus(fuer thema: Thema) async {
        leseThema = thema
        leseArtikel = nil
        leseLaedt = true
        leseModusAktiv = true
        status = "\(thema.name) – Lesemodus"
        do {
            leseArtikel = try await themenService.getNeuesteNews(fuerTopicId: thema.id)
        } catch {
            status = "Fehler News: \(error.localizedDescription)"
        }
        leseLaedt = false
    }

    /// Schließt den Lesemodus und räumt die verwaiste Lese-Entity aus der Szene.
    /// Wird vom ✕-Button bzw. vom Tap auf den Panel-Hintergrund (SwiftUI) aufgerufen.
    func schliesseLesemodus() {
        leseModusAktiv = false
        leseThema = nil
        leseArtikel = nil
        leseLaedt = false
        let staleLese = rootEntity.children.filter { $0.name.hasPrefix("lese_") }
        staleLese.forEach { $0.removeFromParent() }
    }

    // MARK: - Navigation

    func ladeErsteEbene() async {
        guard let thema = appModel.ausgewaehltesThema else {
            status = "Kein Thema ausgewählt"
            return
        }
        pfad = []
        fokusThema = nil
        childrenThemen = []
        leseModusAktiv = false
        leseThema = nil
        aktuellerIndex = 0
        stopMomentum()
        ringAngle = 0
        ringVelocity = 0
        await ladeChildren(vonThemaId: thema.id)
        animierePanels()
    }

    func ladeChildren(vonThemaId id: UUID) async {
        status = "Lade..."
        do {
            let children = try await themenService.getUnterthemen(vonThemaId: id)
            aktuelleThemen = children
            status = "\(children.count) Themen"
        } catch {
            status = "Fehler: \(error.localizedDescription)"
        }
    }

    func themaAusgewaehlt(thema: Thema) async {
        status = "Lade \(thema.name)..."
        do {
            let children = try await themenService.getUnterthemen(vonThemaId: thema.id)
            if children.isEmpty {
                await oeffneLesemodus(fuer: thema)
                return
            }
            navigiertTiefer = true
            fokusThema = thema
            childrenThemen = children
            breadcrumbExpanded = false
            aktuellerIndex = 0
            stopMomentum()
            ringAngle = 0
            ringVelocity = 0
            status = "\(children.count) Unterthemen"
            animierePanels()
        } catch {
            status = "Fehler: \(error.localizedDescription)"
        }
    }

    func childAusgewaehlt(thema: Thema) async {
        status = "Lade \(thema.name)..."
        do {
            let children = try await themenService.getUnterthemen(vonThemaId: thema.id)
            if children.isEmpty {
                await oeffneLesemodus(fuer: thema)
                return
            }
            if let fokus = fokusThema { pfad.append(fokus) }
            aktuelleThemen = childrenThemen
            navigiertTiefer = true
            fokusThema = thema
            childrenThemen = children
            breadcrumbExpanded = false
            aktuellerIndex = 0
            stopMomentum()
            ringAngle = 0
            ringVelocity = 0
            status = "\(children.count) Unterthemen"
            animierePanels()
        } catch {
            status = "Fehler: \(error.localizedDescription)"
        }
    }

    func zurueckEineEbene() async {
        navigiertTiefer = false
        breadcrumbExpanded = false
        stopMomentum()
        ringAngle = 0
        ringVelocity = 0
        if let letztesImPfad = pfad.last {
            pfad.removeLast()
            fokusThema = letztesImPfad
            childrenThemen = aktuelleThemen
            let parentId = letztesImPfad.parentId ?? appModel.ausgewaehltesThema?.id
            if let pid = parentId {
                do {
                    aktuelleThemen = try await themenService.getUnterthemen(vonThemaId: pid)
                } catch {
                    status = "Fehler: \(error.localizedDescription)"
                }
            }
        } else {
            fokusThema = nil
            childrenThemen = []
            aktuellerIndex = 0
            status = "\(aktuelleThemen.count) Themen"
        }
        animierePanels(skipBounce: true)
    }

    func zurueckZuAncestor(thema: Thema) async {
        guard let fokus = fokusThema else { return }
        let vollPfad = pfad + [fokus]
        guard let idx = vollPfad.firstIndex(where: { $0.id == thema.id }) else { return }

        pfad = Array(vollPfad[0..<idx])
        fokusThema = thema
        navigiertTiefer = false
        breadcrumbExpanded = false
        aktuellerIndex = 0
        stopMomentum()
        ringAngle = 0
        ringVelocity = 0

        do {
            childrenThemen = try await themenService.getUnterthemen(vonThemaId: thema.id)
            let parentId = pfad.last?.id ?? appModel.ausgewaehltesThema?.id
            if let pid = parentId {
                aktuelleThemen = try await themenService.getUnterthemen(vonThemaId: pid)
            }
            status = "\(childrenThemen.count) Unterthemen"
        } catch {
            status = "Fehler: \(error.localizedDescription)"
        }

        animierePanels(skipBounce: true)
    }
}
