import Foundation

struct Household: Identifiable, Codable {
    let id: UUID
    var name: String
}

struct InventoryItem: Identifiable, Codable {
    let id: UUID
    let householdID: UUID
    var name: String
    var quantity: Double
    var barcode: String?
}

struct ShoppingListItem: Identifiable, Codable {
    let id: UUID
    let householdID: UUID
    var label: String
    var quantity: Double
    var isCompleted: Bool
}

struct Recipe: Identifiable, Codable {
    let id: UUID
    var title: String
    var ingredients: [RecipeIngredient]
}

struct RecipeIngredient: Identifiable, Codable {
    let id: UUID
    var name: String
    var quantity: Double
    var unit: String
}
