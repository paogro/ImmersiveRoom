import SwiftUI
import RealityKit
import ARKit
import QuartzCore

extension GenericRoomView {

    // MARK: - Ausrichtung

    /// Richtet die gesamte UI (rootEntity) einmalig zur aktuellen Kopf-/Blickrichtung
    /// des Nutzers aus. Wird bei jedem Neu-Laden aufgerufen, damit Ring, Breadcrumb und
    /// Home-Button vor dem Nutzer erscheinen, egal wohin er sich gedreht hat. Nur Yaw
    /// (horizontal), hart gesetzt — kein Live-Following. Tut nichts, wenn noch keine
    /// Kopfpose verfügbar ist (z. B. ganz am Anfang).
    func richteAufKopfrichtungAus() {
        guard worldTracking.state == .running,
              let anchor = worldTracking.queryDeviceAnchor(atTimestamp: CACurrentMediaTime())
        else { return }
        let m = anchor.originFromAnchorTransform
        let yaw = atan2(m.columns.2.x, m.columns.2.z)
        rootEntity.orientation = simd_quatf(angle: yaw, axis: [0, 1, 0])
    }

    // MARK: - Animation

    func animierePanels(skipBounce: Bool = false) {
        // Bei jedem (Neu-)Laden die UI zur aktuellen Kopfrichtung ausrichten.
        richteAufKopfrichtungAus()

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
            // Basis-Raum-Eintrag nur im Fokus-Modus behalten; im Karussell entfernen.
            if entity.name == "basis_crumb" { return fokusThema == nil }
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
        richteAufKopfrichtungAus()   // Lesepanel ebenfalls zur aktuellen Blickrichtung
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
        besuchtePosition = [:]   // Navigations-Verlauf beim (Neu-)Betreten des Raums vergessen
        await ladeChildren(vonThemaId: thema.id)
        zentriereRingAuf(themaId: nil, in: aktuelleThemen)   // mittlere Karte zentrieren (Fächer)
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
            // Gewählte Wurzel-Karte für das Wurzel-Karussell merken.
            if let rootId = appModel.ausgewaehltesThema?.id {
                besuchtePosition[rootId] = thema.id
            }
            navigiertTiefer = true
            fokusThema = thema
            childrenThemen = children
            breadcrumbExpanded = false
            stopMomentum()
            ringVelocity = 0
            // Neuen Ring auf die zuletzt dort besuchte Karte zentrieren (sonst Index 0).
            zentriereAufGemerkt(parentId: thema.id, in: children)
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
            // Gewählte Karte für den aktuellen (verlassenen) Ring merken.
            if let fokus = fokusThema {
                besuchtePosition[fokus.id] = thema.id
                pfad.append(fokus)
            }
            aktuelleThemen = childrenThemen
            navigiertTiefer = true
            fokusThema = thema
            childrenThemen = children
            breadcrumbExpanded = false
            stopMomentum()
            ringVelocity = 0
            // Neuen Ring auf die zuletzt dort besuchte Karte zentrieren (sonst Index 0).
            zentriereAufGemerkt(parentId: thema.id, in: children)
            status = "\(children.count) Unterthemen"
            animierePanels()
        } catch {
            status = "Fehler: \(error.localizedDescription)"
        }
    }

    // Dreht den Ring so, dass die zuvor besuchte Karte wieder vorne steht
    // (Navigations-Verlauf innerhalb der Session). Fällt auf Index 0 zurück,
    // wenn die ID nicht in der Liste vorkommt. Beim Neustart ist alles wieder
    // auf 0, da es reiner In-Memory-State ist.
    // Merkt sich die aktuell vorne stehende Karte für den aktuellen Ring.
    func merkeAktuelleKarte() {
        guard let parent = aktuellerRingParentId else { return }
        let liste = sichtbareThemen
        guard !liste.isEmpty, aktuellerIndex >= 0, aktuellerIndex < liste.count else { return }
        besuchtePosition[parent] = liste[aktuellerIndex].id
    }

    // Zentriert den Ring auf die für diesen Parent gemerkte Karte (falls vorhanden).
    func zentriereAufGemerkt(parentId: UUID?, in liste: [Thema]) {
        let merkId = parentId.flatMap { besuchtePosition[$0] }
        zentriereRingAuf(themaId: merkId, in: liste)
    }

    func zentriereRingAuf(themaId: UUID?, in liste: [Thema]) {
        let n = max(liste.count, 1)
        let step = min(2 * Float.pi / Float(n), ringMaxStep)
        if let themaId, !liste.isEmpty,
           let idx = liste.firstIndex(where: { $0.id == themaId }) {
            aktuellerIndex = idx
            ringAngle = Float(idx) * step
        } else {
            // Kein gemerkter Eintrag → mittlere Karte zentrieren, damit der Fächer
            // symmetrisch vor dem Nutzer liegt (links / mittig / rechts).
            aktuellerIndex = liste.isEmpty ? 0 : (n - 1) / 2
            ringAngle = Float(aktuellerIndex) * step
        }
    }

    func zurueckEineEbene() async {
        navigiertTiefer = false
        breadcrumbExpanded = false
        stopMomentum()
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
            // Ring der Zielebene auf die dort zuletzt besuchte Karte zentrieren.
            zentriereAufGemerkt(parentId: letztesImPfad.id, in: childrenThemen)
        } else {
            fokusThema = nil
            childrenThemen = []
            status = "\(aktuelleThemen.count) Themen"
            zentriereAufGemerkt(parentId: appModel.ausgewaehltesThema?.id, in: aktuelleThemen)
        }
        animierePanels(skipBounce: true)
    }

    // Direkt zurück ins Start-Karussell (Basis-Raum / Übersicht) der gewählten
    // Kategorie — egal wie tief man gerade steckt. Aufgerufen vom "Basis-Raum"-
    // Eintrag im aufgeklappten Breadcrumb.
    func zurueckZuBasis() async {
        navigiertTiefer = false
        breadcrumbExpanded = false
        stopMomentum()
        ringVelocity = 0
        pfad = []
        fokusThema = nil
        childrenThemen = []
        if let rootId = appModel.ausgewaehltesThema?.id {
            do {
                aktuelleThemen = try await themenService.getUnterthemen(vonThemaId: rootId)
            } catch {
                status = "Fehler: \(error.localizedDescription)"
            }
        }
        // Wurzel-Karussell auf die zuletzt besuchte Top-Kategorie zentrieren.
        zentriereAufGemerkt(parentId: appModel.ausgewaehltesThema?.id, in: aktuelleThemen)
        status = "\(aktuelleThemen.count) Themen"
        animierePanels(skipBounce: true)
    }

    func zurueckZuAncestor(thema: Thema) async {
        guard let fokus = fokusThema else { return }
        let vollPfad = pfad + [fokus]
        guard let idx = vollPfad.firstIndex(where: { $0.id == thema.id }) else { return }

        // Das Pfad-Element direkt unter dem Ziel-Vorfahren = die Karte, in der wir
        // zuletzt waren; auf die wird nach dem Zurückspringen zentriert.
        let zielKindId: UUID? = (idx + 1 < vollPfad.count) ? vollPfad[idx + 1].id : nil

        pfad = Array(vollPfad[0..<idx])
        fokusThema = thema
        navigiertTiefer = false
        breadcrumbExpanded = false
        stopMomentum()
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

        // Bevorzugt die gemerkte Position dieses Rings; sonst das Pfad-Kind als Fallback.
        let merkId = besuchtePosition[thema.id] ?? zielKindId
        zentriereRingAuf(themaId: merkId, in: childrenThemen)
        animierePanels(skipBounce: true)
    }
}
