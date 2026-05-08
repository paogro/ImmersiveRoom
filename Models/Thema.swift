import Foundation

struct Thema: Codable, Identifiable, Equatable {
    let id: UUID
    let name: String
    let parentId: UUID?
    let level: Int
    let createdAt: String
    let description: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case parentId = "parent_id"
        case level
        case createdAt = "created_at"
        case description
    }
}
