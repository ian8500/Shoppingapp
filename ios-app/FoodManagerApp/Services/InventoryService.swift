import Foundation

struct InventoryItemDraft {
    var rawName: String
    var quantity: Double
    var unit: InventoryUnit
    var location: InventoryLocation?
    var lowStockThreshold: Double?
    var notes: String?
}

final class InventoryService {
    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func listItems(householdID: UUID, accessToken: String) async throws -> [InventoryItem] {
        try await apiClient.listInventoryItems(householdID: householdID, accessToken: accessToken).items
    }

    func addItem(householdID: UUID, accessToken: String, draft: InventoryItemDraft) async throws -> InventoryItem {
        try await apiClient.createInventoryItem(householdID: householdID, accessToken: accessToken, draft: draft)
    }

    func updateItemMeta(
        householdID: UUID,
        accessToken: String,
        itemID: UUID,
        threshold: Double?,
        location: InventoryLocation?,
        notes: String?
    ) async throws -> InventoryItem {
        try await apiClient.patchInventoryItem(
            householdID: householdID,
            accessToken: accessToken,
            itemID: itemID,
            threshold: threshold,
            location: location,
            notes: notes
        )
    }

    func increment(householdID: UUID, accessToken: String, itemID: UUID, amount: Double) async throws -> InventoryItem {
        try await apiClient.incrementInventoryItem(householdID: householdID, accessToken: accessToken, itemID: itemID, amount: amount)
    }

    func decrement(householdID: UUID, accessToken: String, itemID: UUID, amount: Double) async throws -> InventoryItem {
        try await apiClient.decrementInventoryItem(householdID: householdID, accessToken: accessToken, itemID: itemID, amount: amount)
    }

    func markFinished(householdID: UUID, accessToken: String, itemID: UUID) async throws -> InventoryItem {
        try await apiClient.markInventoryItemFinished(householdID: householdID, accessToken: accessToken, itemID: itemID)
    }

    func listTransactions(householdID: UUID, accessToken: String) async throws -> [InventoryTransaction] {
        try await apiClient.listInventoryTransactions(householdID: householdID, accessToken: accessToken).transactions
    }
}
