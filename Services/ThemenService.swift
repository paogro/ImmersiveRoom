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
