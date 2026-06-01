import Foundation

/// Ein freigegebener News-Artikel aus der Supabase-View `published_news_view`.
/// Verknüpft über `topicId` mit einem Leaf-Topic aus `topics`.
struct NewsArtikel: Codable, Identifiable, Equatable {
    let id: UUID
    let topicId: UUID
    let topicName: String?
    let topicPath: [String]?
    let headline: String
    let description: String?
    let summaryShort: String?
    let sourceUrl: String?
    let publishedAt: String?
    let reviewedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case topicId = "topic_id"
        case topicName = "topic_name"
        case topicPath = "topic_path"
        case headline
        case description
        case summaryShort = "summary_short"
        case sourceUrl = "source_url"
        case publishedAt = "published_at"
        case reviewedAt = "reviewed_at"
    }

    /// Direktlink zum Originalartikel als `URL`, falls vorhanden und gültig.
    var quelleURL: URL? {
        guard let sourceUrl = sourceUrl?.trimmingCharacters(in: .whitespacesAndNewlines),
              !sourceUrl.isEmpty else { return nil }
        return URL(string: sourceUrl)
    }

    /// Die anzuzeigende Zusammenfassung für den Lesemodus.
    ///
    /// `description` enthält laut DB-Team den Quellenlink bereits als Text eingebettet
    /// ("… Näheres unter diesem Link lesen: https://…"). Da wir den Link separat als
    /// eigenen Button über `quelleURL` anbieten, schneiden wir diesen eingebetteten
    /// Block hier raus, damit er nicht doppelt erscheint. Fallback: `summaryShort`.
    var zusammenfassung: String {
        let roh = (description ?? summaryShort ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !roh.isEmpty else { return "" }

        // Eingebetteten "Näheres unter diesem Link …"-Block entfernen.
        var bereinigt = roh
        if let range = bereinigt.range(of: "Näheres unter diesem Link", options: .caseInsensitive) {
            bereinigt = String(bereinigt[..<range.lowerBound])
        }

        // Sicherheitshalber alle restlichen blanken http(s)-Links am Zeilenende kappen.
        let zeilen = bereinigt
            .components(separatedBy: .newlines)
            .filter { zeile in
                let t = zeile.trimmingCharacters(in: .whitespaces)
                return !(t.hasPrefix("http://") || t.hasPrefix("https://"))
            }

        return zeilen
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
