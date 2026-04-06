import Foundation

struct Household: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var createdBy: UUID?
    var createdAt: Date?
}

struct HouseholdMembership: Identifiable, Codable, Equatable {
    let id: UUID
    let householdID: UUID
    let householdName: String
    let userID: UUID
    let role: String
    let status: String
    let joinedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case householdID = "household_id"
        case householdName = "household_name"
        case userID = "user_id"
        case role
        case status
        case joinedAt = "joined_at"
    }
}

struct SupabaseAuthSession: Codable, Equatable {
    let accessToken: String
    let refreshToken: String
    let tokenType: String
    let expiresIn: Int
    let expiresAt: Int
    let user: SupabaseUser

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case expiresAt = "expires_at"
        case user
    }
}

struct SupabaseUser: Codable, Equatable {
    let id: UUID
    let email: String?
}
