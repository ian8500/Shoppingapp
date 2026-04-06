import Foundation

struct ShoppingListItemDraft {
    var rawName: String
    var quantity: Double?
    var unit: String?
    var category: String?
    var notes: String?
}

final class ShoppingListService {
    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func listItems(householdID: UUID, accessToken: String) async throws -> [ShoppingListItem] {
        try await apiClient.listShoppingItems(householdID: householdID, accessToken: accessToken).items
    }

    func addItem(householdID: UUID, accessToken: String, draft: ShoppingListItemDraft) async throws -> ShoppingListItem {
        try await apiClient.createShoppingItem(householdID: householdID, accessToken: accessToken, draft: draft)
    }

    func updateItem(householdID: UUID, accessToken: String, itemID: UUID, draft: ShoppingListItemDraft) async throws -> ShoppingListItem {
        try await apiClient.updateShoppingItem(householdID: householdID, accessToken: accessToken, itemID: itemID, draft: draft)
    }

    func markBought(householdID: UUID, accessToken: String, itemID: UUID) async throws -> ShoppingListItem {
        try await apiClient.markShoppingItemBought(householdID: householdID, accessToken: accessToken, itemID: itemID)
    }

    func archiveItem(householdID: UUID, accessToken: String, itemID: UUID) async throws {
        try await apiClient.archiveShoppingItem(householdID: householdID, accessToken: accessToken, itemID: itemID)
    }
}
