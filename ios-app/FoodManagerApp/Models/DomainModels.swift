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

struct ShoppingListItem: Identifiable, Codable, Equatable {
    let id: UUID
    let householdID: UUID
    var productID: UUID?
    var rawName: String
    var quantity: Double?
    var unit: String?
    var category: String?
    var notes: String?
    var status: ShoppingItemStatus
    let addedBy: UUID?
    var boughtBy: UUID?
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case householdID = "household_id"
        case productID = "product_id"
        case rawName = "raw_name"
        case quantity
        case unit
        case category
        case notes
        case status
        case addedBy = "added_by"
        case boughtBy = "bought_by"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

enum ShoppingItemStatus: String, Codable, CaseIterable {
    case active
    case bought
    case archived
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


enum InventoryUnit: String, Codable, CaseIterable, Identifiable {
    case count
    case pack
    case g
    case kg
    case ml
    case l

    var id: String { rawValue }

    var supportsHalfUsage: Bool {
        self != .count
    }
}

enum InventoryLocation: String, Codable, CaseIterable, Identifiable {
    case fridge
    case freezer
    case cupboard
    case other

    var id: String { rawValue }
}

struct InventoryItem: Identifiable, Codable, Equatable {
    let id: UUID
    let householdID: UUID
    let productID: UUID
    var rawName: String
    var quantity: Double
    var unit: InventoryUnit
    var location: InventoryLocation?
    var lowStockThreshold: Double?
    var notes: String?
    var isLowStock: Bool
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case householdID = "household_id"
        case productID = "product_id"
        case rawName = "raw_name"
        case quantity
        case unit
        case location
        case lowStockThreshold = "low_stock_threshold"
        case notes
        case isLowStock = "is_low_stock"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct InventoryTransaction: Identifiable, Codable, Equatable {
    let id: UUID
    let householdID: UUID
    let inventoryItemID: UUID?
    let productID: UUID
    let quantityDelta: Double
    let unit: InventoryUnit
    let reason: String
    let note: String?
    let actorUserID: UUID?
    let occurredAt: Date
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case householdID = "household_id"
        case inventoryItemID = "inventory_item_id"
        case productID = "product_id"
        case quantityDelta = "quantity_delta"
        case unit
        case reason
        case note
        case actorUserID = "actor_user_id"
        case occurredAt = "occurred_at"
        case createdAt = "created_at"
    }
}
