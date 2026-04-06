import Foundation

struct KnownBarcodeScanState: Identifiable {
    let id = UUID()
    let barcode: String
    let productName: String
    var quantity: Double = 1
}

struct UnknownBarcodeScanState: Identifiable {
    let id = UUID()
    let barcode: String
    var productName: String = ""
    var quantity: Double = 1
    var shouldRememberMapping = true
}

@MainActor
final class InventoryViewModel: ObservableObject {
    @Published private(set) var items: [InventoryItem] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isBarcodeLookupLoading = false
    @Published var errorMessage: String?
    @Published var scanSuccessMessage: String?
    @Published var knownScanState: KnownBarcodeScanState?
    @Published var unknownScanState: UnknownBarcodeScanState?

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

    func handleScannedBarcode(_ barcode: String) async {
        isBarcodeLookupLoading = true
        defer { isBarcodeLookupLoading = false }

        do {
            let lookup = try await inventoryService.lookupBarcode(householdID: householdID, accessToken: accessToken, barcode: barcode)
            if lookup.found, let productName = lookup.productName {
                knownScanState = KnownBarcodeScanState(barcode: barcode, productName: productName)
            } else {
                unknownScanState = UnknownBarcodeScanState(barcode: barcode)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func confirmKnownBarcode(quantity: Double) async {
        guard let knownScanState else { return }

        do {
            let result = try await inventoryService.addFromBarcode(
                householdID: householdID,
                accessToken: accessToken,
                barcode: knownScanState.barcode,
                quantity: quantity,
                productName: nil,
                saveMapping: false
            )
            upsertItem(result.inventoryItem)
            scanSuccessMessage = "Added \(result.productName) to inventory"
            self.knownScanState = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func submitUnknownBarcode() async {
        guard let unknownScanState else { return }
        let trimmedName = unknownScanState.productName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty else {
            errorMessage = "Please enter a product name"
            return
        }

        do {
            let result = try await inventoryService.addFromBarcode(
                householdID: householdID,
                accessToken: accessToken,
                barcode: unknownScanState.barcode,
                quantity: unknownScanState.quantity,
                productName: trimmedName,
                saveMapping: unknownScanState.shouldRememberMapping
            )
            upsertItem(result.inventoryItem)
            scanSuccessMessage = unknownScanState.shouldRememberMapping
                ? "Saved barcode for \(result.productName)"
                : "Added \(result.productName) to inventory"
            self.unknownScanState = nil
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

    private func upsertItem(_ item: InventoryItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
        } else {
            items.insert(item, at: 0)
        }
    }
}
