import Foundation

@MainActor
final class ShoppingListViewModel: ObservableObject {
    @Published private(set) var items: [ShoppingListItem] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isRealtimeConnected = false
    @Published var errorMessage: String?

    private let shoppingService: ShoppingListService
    private let householdID: UUID
    private let accessToken: String

    init(shoppingService: ShoppingListService, householdID: UUID, accessToken: String) {
        self.shoppingService = shoppingService
        self.householdID = householdID
        self.accessToken = accessToken
    }

    var activeItems: [ShoppingListItem] {
        items.filter { $0.status == .active }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var boughtItems: [ShoppingListItem] {
        items.filter { $0.status == .bought }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    func loadItems() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            items = try await shoppingService.listItems(householdID: householdID, accessToken: accessToken)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addItem(draft: ShoppingListItemDraft) async {
        let normalizedDraft = Self.normalizedDraft(draft)
        let tempItem = ShoppingListItem(
            id: UUID(),
            householdID: householdID,
            productID: nil,
            rawName: normalizedDraft.rawName,
            quantity: normalizedDraft.quantity,
            unit: normalizedDraft.unit,
            category: normalizedDraft.category,
            notes: normalizedDraft.notes,
            status: .active,
            addedBy: nil,
            boughtBy: nil,
            createdAt: Date(),
            updatedAt: Date()
        )

        items.insert(tempItem, at: 0)

        do {
            let created = try await shoppingService.addItem(householdID: householdID, accessToken: accessToken, draft: normalizedDraft)
            replaceItem(id: tempItem.id, with: created)
        } catch {
            removeItem(id: tempItem.id)
            errorMessage = error.localizedDescription
        }
    }

    func updateItem(itemID: UUID, draft: ShoppingListItemDraft) async {
        guard let previous = items.first(where: { $0.id == itemID }) else { return }

        let normalizedDraft = Self.normalizedDraft(draft)
        var optimistic = previous
        optimistic.rawName = normalizedDraft.rawName
        optimistic.quantity = normalizedDraft.quantity
        optimistic.unit = normalizedDraft.unit
        optimistic.category = normalizedDraft.category
        optimistic.notes = normalizedDraft.notes
        optimistic.updatedAt = Date()
        replaceItem(id: itemID, with: optimistic)

        do {
            let updated = try await shoppingService.updateItem(
                householdID: householdID,
                accessToken: accessToken,
                itemID: itemID,
                draft: normalizedDraft
            )
            replaceItem(id: itemID, with: updated)
        } catch {
            replaceItem(id: itemID, with: previous)
            errorMessage = error.localizedDescription
        }
    }

    func markBought(itemID: UUID) async {
        guard let previous = items.first(where: { $0.id == itemID }) else { return }
        var optimistic = previous
        optimistic.status = .bought
        optimistic.updatedAt = Date()
        replaceItem(id: itemID, with: optimistic)

        do {
            let updated = try await shoppingService.markBought(householdID: householdID, accessToken: accessToken, itemID: itemID)
            replaceItem(id: itemID, with: updated)
        } catch {
            replaceItem(id: itemID, with: previous)
            errorMessage = error.localizedDescription
        }
    }

    func archiveItem(itemID: UUID) async {
        guard let previous = items.first(where: { $0.id == itemID }) else { return }
        removeItem(id: itemID)

        do {
            try await shoppingService.archiveItem(householdID: householdID, accessToken: accessToken, itemID: itemID)
        } catch {
            items.insert(previous, at: 0)
            errorMessage = error.localizedDescription
        }
    }

    func connectRealtimeIfPossible() {
        // TODO: Hook Supabase Realtime channel here after shared socket setup is introduced.
        isRealtimeConnected = false
    }

    private func replaceItem(id: UUID, with item: ShoppingListItem) {
        guard let index = items.firstIndex(where: { $0.id == id }) else {
            items.insert(item, at: 0)
            return
        }
        items[index] = item
    }

    private func removeItem(id: UUID) {
        items.removeAll { $0.id == id }
    }

    private static func normalizedDraft(_ draft: ShoppingListItemDraft) -> ShoppingListItemDraft {
        ShoppingListItemDraft(
            rawName: draft.rawName.trimmingCharacters(in: .whitespacesAndNewlines),
            quantity: draft.quantity,
            unit: draft.unit?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            category: draft.category?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            notes: draft.notes?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        )
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
