import Foundation

@MainActor
final class InventoryViewModel: ObservableObject {
    @Published private(set) var items: [InventoryItem] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let inventoryService: InventoryService
    private let householdID: UUID
    private let accessToken: String

    init(inventoryService: InventoryService, householdID: UUID, accessToken: String) {
        self.inventoryService = inventoryService
        self.householdID = householdID
        self.accessToken = accessToken
    }

    func loadItems() async {
        isLoading = true
        defer { isLoading = false }

        do {
            items = try await inventoryService.listItems(householdID: householdID, accessToken: accessToken)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addItem(draft: InventoryItemDraft) async {
        do {
            let created = try await inventoryService.addItem(householdID: householdID, accessToken: accessToken, draft: draft)
            items.insert(created, at: 0)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func increment(item: InventoryItem, by amount: Double = 1) async { await apply(item: item) { try await inventoryService.increment(householdID: householdID, accessToken: accessToken, itemID: item.id, amount: amount) } }
    func decrement(item: InventoryItem, by amount: Double = 1) async { await apply(item: item) { try await inventoryService.decrement(householdID: householdID, accessToken: accessToken, itemID: item.id, amount: amount) } }
    func useHalf(item: InventoryItem) async { await decrement(item: item, by: 0.5) }
    func markFinished(item: InventoryItem) async { await apply(item: item) { try await inventoryService.markFinished(householdID: householdID, accessToken: accessToken, itemID: item.id) } }

    func updateThreshold(item: InventoryItem, threshold: Double?) async {
        await apply(item: item) {
            try await inventoryService.updateItemMeta(
                householdID: householdID,
                accessToken: accessToken,
                itemID: item.id,
                threshold: threshold,
                location: item.location,
                notes: item.notes
            )
        }
    }

    private func apply(item: InventoryItem, operation: () async throws -> InventoryItem) async {
        do {
            let updated = try await operation()
            if let index = items.firstIndex(where: { $0.id == item.id }) {
                items[index] = updated
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
