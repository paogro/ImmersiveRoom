import Foundation
import Supabase
import PostgREST

class ThemenService {
    private let client = SupabaseManager.shared.client
    
    // Alle Hauptkategorien laden (Sport, Politik, Technik, Natur)
    func getHauptkategorien() async throws -> [Thema] {
        let response: [Thema] = try await client
            .from("topics")
            .select()
            .eq("level", value: 1)
            .execute()
            .value
        return response
    }
    
    // Unterthemen eines Themas laden
    func getUnterthemen(vonThemaId id: UUID) async throws -> [Thema] {
        let response: [Thema] = try await client
            .from("topics")
            .select()
            .eq("parent_id", value: id.uuidString)
            .execute()
            .value
        return response
    }
    
    // Einzelnes Thema laden
    func getThema(id: UUID) async throws -> Thema {
        let response: Thema = try await client
            .from("topics")
            .select()
            .eq("id", value: id.uuidString)
            .single()
            .execute()
            .value
        return response
    }
    
    // Neuesten freigegebenen News-Artikel zu einem (Leaf-)Topic laden.
    // Inhalte stehen nicht mehr in topics.description, sondern in der View
    // published_news_view, verknüpft über topic_id. Ein Topic kann mehrere
    // Artikel haben — wir nehmen den aktuellsten (published_at desc, limit 1).
    func getNeuesteNews(fuerTopicId id: UUID) async throws -> NewsArtikel? {
        let response: [NewsArtikel] = try await client
            .from("published_news_view")
            .select("id, topic_id, topic_name, topic_path, headline, description, summary_short, source_url, published_at, reviewed_at")
            .eq("topic_id", value: id.uuidString)
            .order("published_at", ascending: false)
            .limit(1)
            .execute()
            .value
        return response.first
    }

    // Kompletten Pfad laden (z.B. Sport > Sportarten > Welche gibt es?)
    func getPfad(fuerThemaId id: UUID) async throws -> [Thema] {
        var pfad: [Thema] = []
        var aktuelleId: UUID? = id
        
        while let currentId = aktuelleId {
            let thema = try await getThema(id: currentId)
            pfad.insert(thema, at: 0)
            aktuelleId = thema.parentId
        }
        return pfad
    }
}
